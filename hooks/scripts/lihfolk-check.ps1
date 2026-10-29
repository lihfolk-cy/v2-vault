# lihfolk-check.ps1 - LihFolk Roblox/Luau checker, Windows PowerShell engine (5.1 and 7+).
# Used when Claude Code runs hooks through PowerShell (Windows without Git Bash). It is the twin of
# lihfolk-check.awk: same rules (rules.tsv), same findings, same output. Keep both in step;
# tools/hooks-test/run-tests.sh diffs their reports.
#
#   Hook mode (default): reads the PostToolUse JSON on stdin and prints hook JSON (or nothing). Exit 0.
#   Scan mode:  powershell -NoProfile -ExecutionPolicy Bypass -File lihfolk-check.ps1 -Scan [path ...]  (default ".")
#               prints "path:line: severity id: message | fix | note"; exit 1 if any error.
# Environment: LIHFOLK_HOOK=off, LIHFOLK_HOOK_SCOPE=edit|file, LIHFOLK_HOOK_MAX=15.
# This file is ASCII only on purpose (Windows PowerShell 5.1 reads BOM-less scripts as ANSI).
[CmdletBinding()]
param([switch]$Scan, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Paths)

$ErrorActionPreference = 'Stop'
[regex]::CacheSize = 256
$Utf8 = New-Object System.Text.UTF8Encoding($false)
try { [Console]::OutputEncoding = $Utf8 } catch { }
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Ord = [System.StringComparer]::Ordinal

function New-Set { return ,(New-Object 'System.Collections.Generic.HashSet[string]' ($Ord)) }
function New-Map { return ,(New-Object 'System.Collections.Generic.Dictionary[string,object]' ($Ord)) }
function M([string]$s, [string]$p) { return [regex]::IsMatch($s, $p) }
function Trim2([string]$s) { return $s.Trim([char[]]@(' ', "`t")) }
function LastIdent([string]$s) { $a = $s.Replace(':', '.').Split('.'); return $a[$a.Length - 1] }

# ---------------------------------------------------------------- rules
$SEV = New-Map; $MSG = New-Map; $FIX = New-Map; $REF = New-Map
foreach ($l in [IO.File]::ReadAllLines((Join-Path $Here 'rules.tsv'), $Utf8)) {
	$l = $l.TrimEnd("`r")
	if ($l -eq '' -or $l.StartsWith('#')) { continue }
	$a = $l.Split("`t")
	$SEV[$a[0]] = $a[1]; $MSG[$a[0]] = $a[2]; $FIX[$a[0]] = $a[3]; $REF[$a[0]] = $a[4]
}
$SEVRANK = @{ 'error' = 3; 'warning' = 2; 'info' = 1 }
$KW = New-Set
foreach ($k in 'function', 'if', 'while', 'for', 'do', 'repeat', 'end', 'until', 'break', 'return') { [void]$KW.Add($k) }

# ---------------------------------------------------------------- helpers
function TrivialLine([string]$t) {
	return ($t.Length -lt 4 -or (M $t '^(end|else|then|do|repeat)[),;]*$') -or (M $t '^[})\]]+[),;]*$'))
}
function IsVendored([string]$p) { return (M $p '(^|/)(Packages|DevPackages|ServerPackages|_Index|node_modules|\.git)/') }
function IsClientPath([string]$p) {
	$q = $p.ToLowerInvariant()
	return ((M $q '\.client\.luau?$') -or (M $q '(^|/)(starterplayerscripts|startercharacterscripts|startergui|starterpack|replicatedfirst)/') -or (M $q 'localscript'))
}
function JEsc([string]$s) {
	return $s.Replace('\', '\\').Replace('"', '\"').Replace("`t", '\t').Replace("`r", '').Replace("`n", '\n')
}

# ---------------------------------------------------------------- lexer (whole file; keeps line count)
$LexRe = New-Object regex ('--\[(?<lc>=*)\[[\s\S]*?\]\k<lc>\]|--\[=*\[[\s\S]*$|--[^\n]*|\[(?<ls>=*)\[[\s\S]*?\]\k<ls>\]|(?<lv>\[=*\[)[\s\S]*$|"(?:\\.|[^"\\\n])*"?|''(?:\\.|[^''\\\n])*''?|`(?:\\.|[^`\\\n])*`?')
$LexEval = [System.Text.RegularExpressions.MatchEvaluator] {
	param($m)
	$v = $m.Value
	$nl = $v.Length - $v.Replace("`n", '').Length
	if ($v.StartsWith('--')) { return ("`n" * $nl) }
	if ($v.StartsWith('[')) {
		if ($m.Groups['lv'].Success) { return '"' + ("`n" * $nl) }
		if ($nl -eq 0) { return '""' }
		return '"' + ("`n" * $nl) + '"'
	}
	return '""'
}

# ---------------------------------------------------------------- findings
function AddF($id, [int]$ln, [int]$lo, [int]$hi, [string]$det, [string]$ev) {
	$key = "$id|$ln"
	if (-not $script:FSEEN.Add($key)) { return }
	$script:F.Add([pscustomobject]@{ id = $id; ln = $ln; lo = $lo; hi = $hi; det = $det; ev = $ev; idx = $script:F.Count })
}
function Ignored($id, [int]$ln) {
	return ($script:IGNF.Contains('all') -or $script:IGNF.Contains($id) -or $script:IGN.Contains("$ln|$id") -or $script:IGN.Contains("$ln|all"))
}
function TouchedF($f) {
	if ($script:ALLTOUCH) { return $true }
	if ($f.ev -ne '') {
		foreach ($x in $f.ev.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) { if ($script:TOUCH.Contains([int]$x)) { return $true } }
		return $false
	}
	for ($i = $f.lo; $i -le $f.hi; $i++) { if ($script:TOUCH.Contains($i)) { return $true } }
	return $false
}

# ---------------------------------------------------------------- block stack
function Push([string]$kind, [int]$id) { $script:SK.Add($kind); $script:SI.Add($id) }
function EnclosingFns {
	$r = @()
	for ($d = $script:SK.Count - 1; $d -ge 0; $d--) { if ($script:SK[$d] -eq 'fn') { $r += $script:SI[$d] } }
	return ,$r
}
function InLoopCtx {
	for ($d = $script:SK.Count - 1; $d -ge 0; $d--) {
		if ($script:SK[$d] -eq 'while' -or $script:SK[$d] -eq 'repeat') { return $true }
		if ($script:SK[$d] -eq 'fn' -and $script:FN[$script:SI[$d]].kind -eq 'frame') { return $true }
	}
	return $false
}
function MarkYield {
	for ($d = $script:SK.Count - 1; $d -ge 0; $d--) {
		if ($script:SK[$d] -eq 'fn') { $script:FN[$script:SI[$d]].y = $true; return }
		if ($script:SK[$d] -eq 'while' -or $script:SK[$d] -eq 'repeat') { $script:LP[$script:SI[$d]].ok = $true }
	}
}
function MarkBreak {
	for ($d = $script:SK.Count - 1; $d -ge 0; $d--) {
		$k = $script:SK[$d]
		if ($k -eq 'fn') { return }
		if ($k -eq 'while' -or $k -eq 'repeat' -or $k -eq 'for') { if ($k -ne 'for') { $script:LP[$script:SI[$d]].ok = $true }; return }
	}
}
function MarkReturn {
	for ($d = $script:SK.Count - 1; $d -ge 0; $d--) {
		if ($script:SK[$d] -eq 'fn') { return }
		if ($script:SK[$d] -eq 'while' -or $script:SK[$d] -eq 'repeat') { $script:LP[$script:SI[$d]].ok = $true }
	}
}
function PopBlock([int]$ln, [string]$untilRest) {
	$n = $script:SK.Count
	if ($n -lt 1) { return }
	$kind = $script:SK[$n - 1]; $id = $script:SI[$n - 1]
	$script:SK.RemoveAt($n - 1); $script:SI.RemoveAt($n - 1)
	if ($kind -eq 'fn') { $script:FN[$id].end = $ln }
	if ($kind -eq 'while' -or $kind -eq 'repeat') {
		$script:LP[$id].end = $ln
		if ($kind -eq 'repeat' -and (M $untilRest '^[ \t]*\(?[ \t]*false[ \t]*\)?([^A-Za-z0-9_]|$)')) { $script:LP[$id].inf = $true }
	}
}

# ---------------------------------------------------------------- keyword handling
function ExprIf([string]$prefix, [int]$ln) {
	$p = $prefix
	if (M $p '^[ \t]*$') {
		for ($j = $ln - 1; $j -ge 1; $j--) { if (-not (M $script:CODE[$j] '^[ \t]*$')) { $p = $script:CODE[$j]; break } }
	}
	return (M $p '(=|\(|,|\{|\[|\+|-|\*|/|%|\^|<|>|\.\.|(^|[^A-Za-z0-9_])(return|and|or|not|in))[ \t]*$')
}
function OnKeyword([string]$w, [int]$ln, [string]$c, [int]$st, [int]$en) {
	# st/en are 0-based: token is c[st..en-1]
	$prefix = $c.Substring(0, $st); $after = $c.Substring($en)
	switch ($w) {
		'function' {
			$f = [pscustomobject]@{ start = $ln; end = $script:NL; y = $false; kind = ''; wrap = $false; name = ''; params = ''; after = '' }
			$m = [regex]::Match($after, '^[ \t]+[A-Za-z_][A-Za-z0-9_.:]*')
			if ($m.Success) { $f.name = LastIdent (Trim2 $m.Value) }
			else {
				$m = [regex]::Match($prefix, '[A-Za-z_][A-Za-z0-9_.:]*[ \t]*=[ \t]*$')
				if ($m.Success) { $f.name = LastIdent ([regex]::Replace($m.Value, '[ \t]*=[ \t]*$', '')) }
			}
			$m = [regex]::Match($after, '\([^)]*\)')
			if ($m.Success) { $f.params = $m.Value.Substring(1, $m.Length - 2); $f.after = $after.Substring($m.Index + $m.Length) }
			else {
				$m = [regex]::Match($after, '\(.*')
				if ($m.Success) { $f.params = $m.Value.Substring(1); $f.after = '' } else { $f.params = ''; $f.after = $after }
			}
			if ((M $prefix 'OnServerEvent[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*$') -or (M $prefix 'OnServerInvoke[ \t]*=[ \t]*$')) { $f.kind = 'remote' }
			elseif (M $prefix 'ProcessReceipt[ \t]*=[ \t]*$') { $f.kind = 'receipt' }
			elseif (M $prefix 'PlayerRemoving[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*$') { $f.kind = 'leave' }
			elseif ((M $prefix '(Heartbeat|RenderStepped|Stepped|PreSimulation|PostSimulation|PreRender|PreAnimation)[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*$') -or (M $prefix 'BindToRenderStep[ \t]*\(.*,[ \t]*$')) { $f.kind = 'frame' }
			if (M $prefix '(pcall|xpcall|Promise\.[A-Za-z]+|[A-Za-z_]*[Rr]etry[A-Za-z_]*)[ \t]*\([^()]*$') { $f.wrap = $true }
			$script:FN.Add($f)
			Push 'fn' ($script:FN.Count - 1)
		}
		'if' { if (-not (ExprIf $prefix $ln)) { Push 'if' 0 } }
		'while' { $script:PW = $true; $script:PI = (M $after '^[ \t]*\(?[ \t]*(true|1)[ \t]*\)?[ \t]+do([^A-Za-z0-9_]|$)') }
		'for' { $script:PF = $true }
		'do' {
			if ($script:PW) { $script:LP.Add([pscustomobject]@{ start = $ln; end = $script:NL; inf = $script:PI; ok = $false }); Push 'while' ($script:LP.Count - 1) }
			elseif ($script:PF) { Push 'for' 0 }
			else { Push 'do' 0 }
			$script:PW = $false; $script:PF = $false; $script:PI = $false
		}
		'repeat' { $script:LP.Add([pscustomobject]@{ start = $ln; end = $script:NL; inf = $false; ok = $false }); Push 'repeat' ($script:LP.Count - 1) }
		'end' { PopBlock $ln '' }
		'until' { PopBlock $ln $after }
		'break' { MarkBreak }
		'return' { MarkReturn }
	}
}

# ---------------------------------------------------------------- per-segment checks
$YieldRe = 'task\.wait|task\.desynchronize|task\.synchronize|(^|[^A-Za-z0-9_.:])[Ww]ait[ \t]*\(|:Wait[A-Za-z]*[ \t]*\(|coroutine\.yield|Async[ \t]*\(|:WaitForChild|:Invoke[A-Za-z]*[ \t]*\(|:[Yy]ield[ \t]*\(|:await[ \t]*\(|:expect[ \t]*\('
function SegCheck([string]$seg, [int]$ln, [string]$before) {
	if (M $seg $YieldRe) { MarkYield }
	$m = [regex]::Match($seg, ':(GetAsync|SetAsync|UpdateAsync|IncrementAsync|RemoveAsync)[ \t]*\(')
	if ($m.Success) {
		$meth = $m.Groups[1].Value
		$pre = $before + $seg.Substring(0, $m.Index)
		# HttpService:GetAsync and friends are web calls, not DataStore calls: out of scope for this rule
		$rcv = ''; $rm = [regex]::Match($pre, '[A-Za-z_][A-Za-z0-9_.]*[ \t]*$'); if ($rm.Success) { $rcv = LastIdent (Trim2 $rm.Value) }
		if (-not (M $pre 'pcall|xpcall|Promise\.|[Rr]etry') -and -not (M $rcv '[Hh]ttp|^HS$')) {
			$script:DSC.Add([pscustomobject]@{ ln = $ln; fns = (EnclosingFns); m = $meth })
		}
	}
	$m = [regex]::Match($seg, ':Connect(Parallel)?[ \t]*\(')
	if ($m.Success -and (InLoopCtx)) {
		$pre = $before + $seg.Substring(0, $m.Index)
		if ((M $pre '(^|[^=~<>])=[^=]*$') -or (M $pre 'insert[ \t]*\(|:Add[ \t]*\(|:GiveTask[ \t]*\(|[Jj]anitor|[Mm]aid|[Tt]rove')) {
			if (-not $script:HASDISC) { AddF 'connect-in-loop' $ln $ln $ln 'stored but never disconnected in this file' '' }
		} else { AddF 'connect-in-loop' $ln $ln $ln '' '' }
	}
}

# ---------------------------------------------------------------- per-line checks
$CurrencyRe = 'leaderstats|coins|cash|money|gems|gold|currency|points|diamonds|bucks|tokens|credits|robux|balance'
function LineChecks([int]$i) {
	$c = $script:CODE[$i]; $r = $script:RAW[$i]
	if (M $c '^[ \t]*$') { return }
	if (-not $script:DEFWAIT -and (M $c '(^|[^A-Za-z0-9_.:])[Ww]ait[ \t]*\(') -and -not (M $c 'function[ \t]+[Ww]ait[ \t]*\(')) { AddF 'deprecated-wait' $i $i $i '' '' }
	if (-not $script:DEFSPAWN -and (M $c '(^|[^A-Za-z0-9_.:])[Ss]pawn[ \t]*\(') -and -not (M $c 'function[ \t]+[Ss]pawn[ \t]*\(')) { AddF 'deprecated-spawn' $i $i $i '' '' }
	if (-not $script:DEFDELAY -and (M $c '(^|[^A-Za-z0-9_.:])[Dd]elay[ \t]*\(') -and -not (M $c 'function[ \t]+[Dd]elay[ \t]*\(')) { AddF 'deprecated-delay' $i $i $i '' '' }
	if (M $c 'Instance\.new[ \t]*\([^,()]*,[ \t]*[^ \t)]') { AddF 'instance-new-parent' $i $i $i '' '' }
	if (M $c ':InvokeClient[ \t]*\(') { AddF 'remote-invokeclient' $i $i $i '' '' }
	if ((M $c ':SetAsync[ \t]*\(') -and -not $script:HASORDERED -and ((M $r 'UserId|[Pp]layer|[Pp]lr') -or $script:HASUSERID)) { AddF 'datastore-setasync-player' $i $i $i '' '' }
	if ($script:ISCLIENT) {
		$lr = $r.ToLowerInvariant()
		# the currency word must name the object whose .Value is assigned, or be the whole attribute name
		if ((M $c.ToLowerInvariant() ('(' + $CurrencyRe + ')[a-z0-9_]*(\.[a-z0-9_]+|\[[a-z0-9_"]*\])*\.value[ \t]*([-+*/]|\.\.)?=[^=]')) -or ((M $c.ToLowerInvariant() '\[""\](\.[a-z0-9_]+|\[[a-z0-9_"]*\])*\.value[ \t]*([-+*/]|\.\.)?=[^=]') -and (M $lr ('\[[ \t]*["''](' + $CurrencyRe + ')["''][ \t]*\]'))) -or ((M $c ':SetAttribute[ \t]*\(') -and (M $lr ('setattribute[ \t]*\([ \t]*["''](' + $CurrencyRe.Replace('leaderstats|', '') + ')["'']')))) { AddF 'client-sets-currency' $i $i $i '' '' }
	}
	if (M $c ':FindFirst[A-Za-z]*[ \t]*\([^()]*\)[ \t]*(\.[A-Za-z_]|:|\[)') { AddF 'findfirstchild-chain' $i $i $i '' '' }
}

# ---------------------------------------------------------------- remote handler analysis
function UsesName([string]$body, [string]$nm) { return (M $body ('(^|[^A-Za-z0-9_.:])' + $nm + '([^A-Za-z0-9_]|$)')) }
# A value only forwarded into plain or dotted function calls is the callee's job to check. Anything
# indexed, computed with, compared, assigned, iterated or passed to a :Method() counts as direct use.
function DirectUse([string]$body, [string]$N) {
	$B = '(^|[^A-Za-z0-9_.:])'; $E = '([^A-Za-z0-9_]|$)'
	if (M $body ($B + $N + '[ \t]*(\.[A-Za-z_]|\[|:)')) { return $true }
	if (M $body ($B + $N + '[ \t]*([-+*/%^<>]|==|~=|\.\.)')) { return $true }
	if (M $body ('([-+*/%^<>=~]|\.\.)[ \t]*' + $N + $E)) { return $true }
	if (M $body (':[A-Za-z_][A-Za-z0-9_]*[ \t]*\([^\n]*' + $B + $N + $E)) { return $true }
	if ((M $body ('(pairs|ipairs|next)[ \t]*\([ \t]*' + $N + $E)) -or (M $body ('#[ \t]*' + $N + $E)) -or (M $body ('[ \t]in[ \t]+' + $N + $E))) { return $true }
	return $false
}
function Validated([string]$body, [string]$N) {
	$E = '([^A-Za-z0-9_]|$)'; $B = '(^|[^A-Za-z0-9_.:])'
	if (M $body ('typeof[ \t]*\([ \t]*' + $N + $E)) { return $true }
	if (M $body ($B + 'type[ \t]*\([ \t]*' + $N + $E)) { return $true }
	if (M $body ('tonumber[ \t]*\([ \t]*' + $N + $E)) { return $true }
	if (M $body ($B + $N + '[ \t]*:[ \t]*IsA[ \t]*\(')) { return $true }
	if (M $body ('\[[ \t]*' + $N + '[ \t]*\]')) { return $true }
	if (M $body ('table\.find[ \t]*\([^\n]*' + $B + $N + $E)) { return $true }
	if (M $body ('assert[ \t]*\([^\n]*' + $B + $N + $E)) { return $true }
	if (M $body ('[A-Za-z_]*([Vv]alid|[Cc]heck|[Ss]anitiz|[Gg]uard|[Vv]erify|[Ee]xpect)[A-Za-z0-9_]*[ \t]*\([^\n]*' + $B + $N + $E)) { return $true }
	if (M $body ('(^|[^A-Za-z0-9_])t\.[A-Za-z]+[ \t]*\([^\n]*' + $B + $N + $E)) { return $true }
	if (M $body ($B + '[Ii]s[A-Z][A-Za-z0-9_]*[ \t]*\([^\n]*' + $B + $N + $E)) { return $true }
	return $false
}
function AnalyzeRemote([int]$k) {
	$f = $script:FN[$k]; $s = $f.start; $e = $f.end
	$sb = New-Object System.Text.StringBuilder ($f.after)
	for ($ln = $s + 1; $ln -le $e; $ln++) { [void]$sb.Append("`n").Append($script:CODE[$ln]) }
	$body = $sb.ToString()
	$P = $f.params.Split(',')
	$bad = @()
	for ($j = 1; $j -lt $P.Length; $j++) {
		$nm = Trim2 ([regex]::Replace($P[$j], ':[\s\S]*', ''))
		if ($nm -eq '' -or $nm.StartsWith('_')) { continue }
		if ($nm -eq '...') {
			if ((M $body '=[ \t]*\.\.\.|\{[ \t]*\.\.\.|table\.pack[ \t]*\([ \t]*\.\.\.') -and -not (M $body 'typeof[ \t]*\(|select[ \t]*\(|[Vv]alidat|[Cc]heck|(^|[^A-Za-z0-9_])t\.[A-Za-z]+[ \t]*\(')) { $bad += '...' }
			continue
		}
		if (-not (M $nm '^[A-Za-z_][A-Za-z0-9_]*$')) { continue }
		if (-not (UsesName $body $nm) -or -not (DirectUse $body $nm)) { continue }
		if (-not (Validated $body $nm)) { $bad += $nm }
	}
	if ($bad.Count -gt 0) { AddF 'remote-unvalidated-args' $s $s $e ('unchecked: ' + ($bad -join ', ')) '' }
}

# ---------------------------------------------------------------- ProcessReceipt analysis
function AnalyzeReceipt([int]$k) {
	$f = $script:FN[$k]; $s = $f.start; $e = $f.end
	$inner = New-Object 'System.Collections.Generic.HashSet[int]'
	for ($j = 0; $j -lt $script:FN.Count; $j++) {
		$g = $script:FN[$j]
		if ($j -ne $k -and $g.start -gt $s -and $g.start -le $e) { for ($ln = $g.start + 1; $ln -le $g.end; $ln++) { [void]$inner.Add($ln) } }
	}
	$sb = New-Object System.Text.StringBuilder ($f.after)
	for ($ln = $s + 1; $ln -le $e; $ln++) { if (-not $inner.Contains($ln)) { [void]$sb.Append("`n").Append($script:CODE[$ln]) } }
	$body = $sb.ToString()
	$hasG = M $body 'PurchaseGranted'; $hasN = M $body 'NotProcessedYet'
	$delegated = $false
	if (M $body 'return[ \t]+(true|false|nil)([^A-Za-z0-9_]|$)') { AddF 'receipt-bad-return' $s $s $e 'returns true/false/nil instead of a decision' '' }
	elseif ($hasG -and -not $hasN) { AddF 'receipt-bad-return' $s $s $e 'no NotProcessedYet path for failures' '' }
	elseif (-not $hasG -and -not $hasN) {
		if (M $body 'return[ \t]+[A-Za-z_]') { $delegated = $true }
		else { AddF 'receipt-bad-return' $s $s $e 'never returns a decision' '' }
	}
	if ($delegated) { return }
	if (-not $script:HASPURCHASEID) { AddF 'receipt-no-idempotency' $s $s $e '' '' }
	if (M $body '[Pp]rofile|[Rr]eplica|[Dd]ata[Mm]anager|[Dd]ata[Ss]ervice') { return }
	$firstM = 0; $firstS = 0
	for ($ln = $s; $ln -le $e; $ln++) {
		$c = $script:CODE[$ln]
		if (-not $firstS -and (M $c ':(UpdateAsync|SetAsync|IncrementAsync)[ \t]*\(|[Ss]ave[A-Za-z]*[ \t]*\(')) { $firstS = $ln }
		if (-not $firstM -and (M $c '\.Value[ \t]*([-+*/]|\.\.)?=[^=]|[A-Za-z0-9_\])][ \t]*[-+*/]=[^=]|:SetAttribute[ \t]*\(')) { $firstM = $ln }
	}
	if ($firstM -and (-not $firstS -or $firstM -lt $firstS)) {
		$d = ''; if (-not $firstS) { $d = 'no save call in the handler' }
		AddF 'receipt-grant-before-save' $firstM $s $e $d ''
	}
}

# does CODE[lo..hi] write to a DataStore ($calls false), or also call a same-file saving function?
function RangeHas([int]$lo, [int]$hi, [bool]$calls) {
	for ($i = $lo; $i -le $hi; $i++) {
		$c = $script:CODE[$i]
		if (M $c ':(SetAsync|UpdateAsync|IncrementAsync)[ \t]*\(') { return $true }
		if (-not $calls) { continue }
		foreach ($m in [regex]::Matches($c, '([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(')) { if ($script:WN.Contains($m.Groups[1].Value)) { return $true } }
	}
	return $false
}

# ---------------------------------------------------------------- analyse one file
function AddIds([string]$ids, [int]$target, [bool]$isFile) {
	foreach ($x in [regex]::Split($ids, '[ ,]+')) {
		if ($x -eq '') { continue }
		if ($isFile) { [void]$script:IGNF.Add($x) } else { [void]$script:IGN.Add("$target|$x") }
	}
}
function Invoke-Analyze([string]$path) {
	try { $text = [IO.File]::ReadAllText($path, $Utf8) } catch { return $false }
	$text = $text.Replace("`r`n", "`n")
	if ($text.EndsWith("`n")) { $text = $text.Substring(0, $text.Length - 1) }
	if ($text.Length -eq 0) { return $false }
	$lines = $text.Split("`n")
	$script:NL = $lines.Length
	$script:RAW = @($null) + $lines
	for ($i = 1; $i -le $script:NL; $i++) { $script:RAW[$i] = $script:RAW[$i].TrimEnd("`r") }
	$code = $LexRe.Replace(($script:RAW[1..$script:NL] -join "`n"), $LexEval)
	$script:CODE = @($null) + $code.Split("`n")
	$script:ISCLIENT = IsClientPath $path
	$script:IGN = New-Set; $script:IGNF = New-Set
	$script:TOUCH = New-Object 'System.Collections.Generic.HashSet[int]'
	$script:F = New-Object 'System.Collections.Generic.List[object]'; $script:FSEEN = New-Set
	$script:FN = New-Object 'System.Collections.Generic.List[object]'
	$script:LP = New-Object 'System.Collections.Generic.List[object]'
	$script:SK = New-Object 'System.Collections.Generic.List[string]'; $script:SI = New-Object 'System.Collections.Generic.List[int]'
	$script:DSC = New-Object 'System.Collections.Generic.List[object]'
	$script:PREF = New-Set; $script:REMNAME = New-Set; $script:RCPNAME = New-Set; $script:YN = New-Set
	$script:LEAVENAME = New-Set; $script:WN = New-Set
	$script:PW = $false; $script:PF = $false; $script:PI = $false

	if (-not $script:ALLTOUCH) {
		for ($i = 1; $i -le $script:NL; $i++) { $t = Trim2 $script:RAW[$i]; if (-not (TrivialLine $t) -and $script:NEWSET.Contains($t)) { [void]$script:TOUCH.Add($i) } }
	}

	$script:HASDISC = $false; $script:DEFWAIT = $false; $script:DEFSPAWN = $false; $script:DEFDELAY = $false
	$script:HASORDERED = $false; $script:HASUSERID = $false; $script:HASPURCHASEID = $false
	$mkt = ''; $rnd = ''; $pol = $false; $pr = ''; $wr = ''; $btc = $false
	for ($i = 1; $i -le $script:NL; $i++) {
		$s = $script:RAW[$i]
		if ($s.Contains('lihfolk-ignore')) {
			$m = [regex]::Match($s, 'lihfolk-ignore-file:[ \t]*[A-Za-z0-9_, -]+')
			if ($m.Success) { AddIds ([regex]::Replace($m.Value, '^lihfolk-ignore-file:[ \t]*', '')) 0 $true }
			else {
				$m = [regex]::Match($s, 'lihfolk-ignore:[ \t]*[A-Za-z0-9_, -]+')
				if ($m.Success) {
					$tgt = $i; if (M $script:CODE[$i] '^[ \t]*$') { $tgt = $i + 1 }
					AddIds ([regex]::Replace($m.Value, '^lihfolk-ignore:[ \t]*', '')) $tgt $false
				}
			}
		}
		$c = $script:CODE[$i]
		if (M $c '^[ \t]*$') { continue }
		if (M $c ':Disconnect[ \t]*\(|[Jj]anitor|[Mm]aid|[Tt]rove') { $script:HASDISC = $true }
		if (M $c 'function[ \t]+[Ww]ait[ \t]*\(|local[ \t]+[Ww]ait[ \t]*=') { $script:DEFWAIT = $true }
		if (M $c 'function[ \t]+[Ss]pawn[ \t]*\(|local[ \t]+[Ss]pawn[ \t]*=') { $script:DEFSPAWN = $true }
		if (M $c 'function[ \t]+[Dd]elay[ \t]*\(|local[ \t]+[Dd]elay[ \t]*=') { $script:DEFDELAY = $true }
		if (M $c 'GetOrderedDataStore') { $script:HASORDERED = $true }
		if (M $c 'UserId') { $script:HASUSERID = $true }
		if (M $c 'PurchaseId') { $script:HASPURCHASEID = $true }
		if (M $c 'MarketplaceService') { $mkt += " $i" }
		if (M $c 'math\.random|Random\.new|:NextInteger|:NextNumber') { $rnd += " $i" }
		if (M $c 'PolicyService|ArePaidRandomItemsRestricted|GetPolicyInfoForPlayerAsync') { $pol = $true }
		if (M $c 'PlayerRemoving') { $pr += " $i" }
		$m = [regex]::Match($c, 'PlayerRemoving[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*([A-Za-z_][A-Za-z0-9_.:]*)[ \t]*\)')
		if ($m.Success) { $nm = LastIdent $m.Groups[1].Value; if ($nm -ne 'function') { [void]$script:LEAVENAME.Add($nm) } }
		if (M $c ':(SetAsync|UpdateAsync|IncrementAsync)[ \t]*\(') { $wr += " $i" }
		if (M $c 'BindToClose') { $btc = $true }
		foreach ($m in [regex]::Matches($c, '(pcall|xpcall|[A-Za-z_]*[Rr]etry[A-Za-z_]*|Promise\.[A-Za-z]+)[ \t]*\([ \t]*([A-Za-z_][A-Za-z0-9_.:]*)')) { [void]$script:PREF.Add((LastIdent $m.Groups[2].Value)) }
		$m = [regex]::Match($c, 'OnServerEvent[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*([A-Za-z_][A-Za-z0-9_.:]*)[ \t]*\)')
		if ($m.Success) { $nm = LastIdent $m.Groups[1].Value; if ($nm -ne 'function') { [void]$script:REMNAME.Add($nm) } }
		$m = [regex]::Match($c, 'OnServerInvoke[ \t]*=[ \t]*([A-Za-z_][A-Za-z0-9_.:]*)')
		if ($m.Success) { $nm = LastIdent $m.Groups[1].Value; if ($nm -ne 'function') { [void]$script:REMNAME.Add($nm) } }
		$m = [regex]::Match($c, 'ProcessReceipt[ \t]*=[ \t]*([A-Za-z_][A-Za-z0-9_.:]*)')
		if ($m.Success) { $nm = LastIdent $m.Groups[1].Value; if ($nm -ne 'function') { [void]$script:RCPNAME.Add($nm) } }
	}

	# structural pass
	for ($i = 1; $i -le $script:NL; $i++) {
		$c = $script:CODE[$i]; $pos = 0
		foreach ($m in [regex]::Matches($c, '[A-Za-z_][A-Za-z0-9_]*')) {
			$w = $m.Value; $st = $m.Index; $en = $st + $m.Length
			$prev = ''; if ($st -gt 0) { $prev = $c.Substring($st - 1, 1) }
			if ($KW.Contains($w) -and $prev -ne '.' -and $prev -ne ':') {
				SegCheck $c.Substring($pos, $st - $pos) $i $c.Substring(0, $pos)
				OnKeyword $w $i $c $st $en
				$pos = $en
			}
		}
		SegCheck $c.Substring($pos) $i $c.Substring(0, $pos)
		LineChecks $i
	}

	foreach ($d in $script:DSC) {
		$prot = $false
		foreach ($k in $d.fns) { $g = $script:FN[$k]; if ($g.wrap -or ($g.name -ne '' -and $script:PREF.Contains($g.name))) { $prot = $true } }
		if (-not $prot) { AddF 'datastore-no-pcall' $d.ln $d.ln $d.ln $d.m '' }
	}
	foreach ($g in $script:FN) { if ($g.y -and $g.name -ne '') { [void]$script:YN.Add($g.name) } }
	foreach ($L in $script:LP) {
		if (-not $L.inf -or $L.ok) { continue }
		$prot = $false
		for ($i = $L.start; $i -le $L.end -and -not $prot; $i++) {
			foreach ($m in [regex]::Matches($script:CODE[$i], '([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(')) { if ($script:YN.Contains($m.Groups[1].Value)) { $prot = $true; break } }
		}
		if (-not $prot) { AddF 'while-true-no-yield' $L.start $L.start $L.end '' '' }
	}
	for ($k = 0; $k -lt $script:FN.Count; $k++) {
		$g = $script:FN[$k]
		if ($g.kind -eq 'remote' -or ($g.name -ne '' -and $script:REMNAME.Contains($g.name))) { AnalyzeRemote $k }
		if ($g.kind -eq 'receipt' -or ($g.name -ne '' -and $script:RCPNAME.Contains($g.name))) { AnalyzeReceipt $k }
	}
	if ($mkt -ne '' -and $rnd -ne '' -and -not $pol) { $a = $rnd.Trim().Split(' '); AddF 'paid-random-no-policy' ([int]$a[0]) ([int]$a[0]) ([int]$a[0]) '' ($mkt + $rnd).Trim() }
	# BindToClose: only when a PlayerRemoving handler saves, directly or through same-file functions (two levels)
	if ($pr -ne '' -and $wr -ne '' -and -not $btc) {
		foreach ($g in $script:FN) { if ($g.name -ne '' -and (RangeHas $g.start $g.end $false)) { [void]$script:WN.Add($g.name) } }
		$wn2 = @(); foreach ($g in $script:FN) { if ($g.name -ne '' -and -not $script:WN.Contains($g.name) -and (RangeHas $g.start $g.end $true)) { $wn2 += $g.name } }
		foreach ($x in $wn2) { [void]$script:WN.Add($x) }
		$prot = $false
		foreach ($g in $script:FN) { if (($g.kind -eq 'leave' -or ($g.name -ne '' -and $script:LEAVENAME.Contains($g.name))) -and (RangeHas $g.start $g.end $true)) { $prot = $true } }
		if ($prot) { $a = $wr.Trim().Split(' '); AddF 'datastore-no-bindtoclose' ([int]$a[0]) ([int]$a[0]) ([int]$a[0]) '' ($pr + $wr).Trim() }
	}
	return $true
}

# ---------------------------------------------------------------- reporting
function Get-Visible {
	$v = @($script:F | Where-Object { -not (Ignored $_.id $_.ln) -and (TouchedF $_) })
	$script:NE = @($v | Where-Object { $SEV[$_.id] -eq 'error' }).Count
	$script:NW = @($v | Where-Object { $SEV[$_.id] -eq 'warning' }).Count
	$script:NI = $v.Count - $script:NE - $script:NW
	return ,@($v | Sort-Object -Property @{ Expression = { $SEVRANK[$SEV[$_.id]] }; Descending = $true }, @{ Expression = { $_.ln } }, @{ Expression = { $_.idx } })
}
function DetailOf($f) { if ($f.det -ne '') { return " ($($f.det))" } else { return '' } }

$Out = New-Object System.Text.StringBuilder
if ($Scan) {
	if (-not $Paths -or $Paths.Count -eq 0) { $Paths = @(".") }
	$script:ALLTOUCH = $true
	$files = New-Object 'System.Collections.Generic.List[string]'
	$prune = @('.git', 'node_modules', 'Packages', 'DevPackages', 'ServerPackages', '_Index')
	function Walk([string]$dir, [string]$disp) {
		$entries = @(); try { $entries = [IO.Directory]::GetFileSystemEntries($dir) } catch { return }
		foreach ($e in $entries) {
			$name = [IO.Path]::GetFileName($e)
			if ([IO.Directory]::Exists($e)) { if ($prune -notcontains $name) { Walk $e "$disp/$name" } }
			elseif ($name -match '\.luau?$') { $files.Add("$disp/$name") }
		}
	}
	foreach ($p in $Paths) {
		$disp = $p.Replace('\', '/').TrimEnd('/'); if ($disp -eq '') { $disp = '/' }
		if ([IO.Directory]::Exists($p)) { Walk (Resolve-Path -LiteralPath $p).ProviderPath $disp }
		elseif ([IO.File]::Exists($p)) { $files.Add($p.Replace('\', '/')) }
		else { [Console]::Error.WriteLine("lihfolk-check: no such file or folder: $p") }
	}
	$nf = 0; $te = 0; $tw = 0; $ti = 0
	foreach ($p in $files) {
		if (IsVendored $p) { continue }
		if (-not (Invoke-Analyze $p)) { continue }
		$nf++
		$vis = Get-Visible
		$te += $script:NE; $tw += $script:NW; $ti += $script:NI
		foreach ($f in $vis) {
			[void]$Out.Append("$($p):$($f.ln): $($SEV[$f.id]) $($f.id): $($MSG[$f.id])$(DetailOf $f) | fix: $($FIX[$f.id]) | note: LihFolk Vault V2/$($REF[$f.id])`n")
		}
	}
	[void]$Out.Append("LihFolk check: $nf file(s) scanned, $te error(s), $tw warning(s), $ti info.`n")
	[Console]::Out.Write($Out.ToString())
	if ($te -gt 0) { exit 1 }
	exit 0
}

# ---------------------------------------------------------------- hook mode (never fails the session)
try {
	if ($env:LIHFOLK_HOOK -eq 'off') { exit 0 }
	try { [Console]::InputEncoding = $Utf8 } catch { }
	$raw = [Console]::In.ReadToEnd()
	$j = $raw | ConvertFrom-Json
	$ti = $j.tool_input
	$path = [string]$ti.file_path; $tool = [string]$j.tool_name
	if ($path -eq '') { exit 0 }
	$path = $path.Replace('\', '/')
	if (-not (M $path '\.[Ll][Uu][Aa][Uu]?$') -or (IsVendored $path)) { exit 0 }
	$scope = $env:LIHFOLK_HOOK_SCOPE; if (-not $scope) { $scope = 'edit' }
	$maxshow = 15; if ($env:LIHFOLK_HOOK_MAX -match '^\d+$') { $maxshow = [int]$env:LIHFOLK_HOOK_MAX }
	$script:ALLTOUCH = ($scope -eq 'file' -or $tool -eq 'Write' -or ($tool -ne 'Edit' -and $tool -ne 'MultiEdit'))
	$script:NEWSET = New-Set
	if (-not $script:ALLTOUCH) {
		$news = @()
		if ($null -ne $ti.new_string) { $news += [string]$ti.new_string }
		if ($null -ne $ti.edits) { foreach ($e in $ti.edits) { if ($null -ne $e.new_string) { $news += [string]$e.new_string } } }
		foreach ($ns in $news) { foreach ($l in $ns.Split("`n")) { $t = Trim2 ($l.TrimEnd("`r")); if ($t -ne '') { [void]$script:NEWSET.Add($t) } } }
	}
	if (-not (Invoke-Analyze $path)) { exit 0 }
	$vis = Get-Visible
	if ($vis.Count -eq 0) { exit 0 }
	$text = "LihFolk Roblox check: $($vis.Count) issue(s) in $path ($($script:NE) error, $($script:NW) warning, $($script:NI) info). Fix them now. Only if you have verified a finding is a false positive, add ``-- lihfolk-ignore: <id>`` on that line or the line above, with a short reason."
	$shown = 0
	foreach ($f in $vis) {
		if ($shown -ge $maxshow) { $text += "`n- ... $($vis.Count - $shown) more; run /lihfolk:audit for the full list."; break }
		$shown++
		$text += "`n- line $($f.ln) [$($SEV[$f.id])] $($f.id)$(DetailOf $f): $($MSG[$f.id])`n  Fix: $($FIX[$f.id])`n  Note: LihFolk Vault V2/$($REF[$f.id])"
	}
	if ($env:CLAUDE_PLUGIN_ROOT) { $text += "`nLihFolk notes live under $($env:CLAUDE_PLUGIN_ROOT)/LihFolk Vault V2/ ." }
	if ($script:NE + $script:NW -gt 0) { [Console]::Out.Write('{"decision":"block","reason":"' + (JEsc $text) + '"}' + "`n") }
	else { [Console]::Out.Write('{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"' + (JEsc $text) + '"}}' + "`n") }
	exit 0
} catch {
	exit 0
}
