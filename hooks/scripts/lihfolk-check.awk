# lihfolk-check.awk - LihFolk Roblox/Luau checker, POSIX awk engine.
# Used on macOS, Linux and Windows Git Bash. lihfolk-check.ps1 is the Windows PowerShell twin;
# keep both in step (tools/hooks-test/run-tests.sh compares them).
#
# Variables (-v): mode=hook|scan  rules=<rules.tsv>  scope=edit|file  maxshow=<n>  robloxproj=0|1
#   robloxproj=1 when the project root holds *.project.json, wally.toml, *.rbxl or *.rbxlx (set by the sh
#   wrapper). .luau files are always checked; .lua files only when robloxproj=1 or the file itself uses
#   game:GetService or script.Parent, so plain Lua projects (LOVE, Neovim, ...) are left alone.
#   hook: stdin is the PostToolUse JSON from Claude Code; prints hook JSON (or nothing).
#   scan: stdin is a list of .lua/.luau paths, one per line; prints a text report.
# Portable awk only: no gawk extensions, no regex intervals, no character classes.

BEGIN {
	if (maxshow == "") maxshow = 15
	if (scope == "") scope = "edit"
	EXITCODE = 0
	loadRules(rules)
	split("function if while for do repeat end until break return", kw_, " ")
	for (k_ in kw_) KW[kw_[k_]] = 1
	# infinite-loop rule: words before "(" that are not calls, globals that never yield, and library
	# tables whose functions never yield. Any other call to a function not defined in this file (or any
	# method call) may yield, so the loop is not reported.
	split("and or not if elseif while until return in then do function local else repeat for end break", kw_, " ")
	for (k_ in kw_) LKW[kw_[k_]] = 1
	split("print warn error assert type typeof tostring tonumber pairs ipairs next select rawget rawset rawequal rawlen setmetatable getmetatable unpack pcall xpcall", kw_, " ")
	for (k_ in kw_) NOYIELD[kw_[k_]] = 1
	split("math string table bit32 utf8 buffer os debug vector task coroutine Vector3 Vector2 Vector3int16 Vector2int16 CFrame Color3 UDim UDim2 Instance BrickColor NumberRange NumberSequence NumberSequenceKeypoint ColorSequence ColorSequenceKeypoint TweenInfo Ray Region3 Rect Random DateTime", kw_, " ")
	for (k_ in kw_) STDLIB[kw_[k_]] = 1
	SEVRANK["error"] = 3; SEVRANK["warning"] = 2; SEVRANK["info"] = 1
	if (mode == "hook") hookMain(); else scanMain()
	exit EXITCODE
}

# ---------------------------------------------------------------- rules
function loadRules(path,    l, a) {
	while ((getline l < path) > 0) {
		sub(/\r$/, "", l)
		if (l == "" || l ~ /^#/) continue
		split(l, a, "\t")
		SEV[a[1]] = a[2]; MSG[a[1]] = a[3]; FIX[a[1]] = a[4]; REF[a[1]] = a[5]
	}
	close(path)
}

# ---------------------------------------------------------------- small helpers
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function lastIdent(s,    n, a) { gsub(/:/, ".", s); n = split(s, a, "."); return a[n] }
function joinBy(s, sep, repl,    n, a, i, out) {
	n = split(s, a, sep); out = a[1]
	for (i = 2; i <= n; i++) out = out repl a[i]
	return out
}
function jesc(s) {
	s = joinBy(s, "\\", "\\\\")
	s = joinBy(s, "\"", "\\\"")
	s = joinBy(s, "\t", "\\t")
	s = joinBy(s, "\r", "")
	s = joinBy(s, "\n", "\\n")
	return s
}
function trivialLine(t) {
	return (length(t) < 4 || t ~ /^(end|else|then|do|repeat)[),;]*$/ || t ~ /^[})\]]+[),;]*$/)
}
function isVendored(p) { return (p ~ /(^|\/)(Packages|DevPackages|ServerPackages|_Index|node_modules|\.git)\//) }
function isClientPath(p,    q) {
	q = tolower(p)
	return (q ~ /\.client\.luau?$/ || q ~ /(^|\/)(starterplayerscripts|startercharacterscripts|startergui|starterpack|replicatedfirst)\// || q ~ /localscript/)
}

# ---------------------------------------------------------------- lexer: strip comments, blank strings
# State (LXM, LXL) carries long comments / long strings across lines.
function rep(ch, n,    s) { s = ""; while (n-- > 0) s = s ch; return s }
function lex(s,    out, i, n, c, c2, j, close_, p) {
	if (LXM == "" && s !~ /[-"'`\[]/) return s
	out = ""; i = 1; n = length(s)
	while (i <= n) {
		if (LXM != "") {
			close_ = "]" rep("=", LXL) "]"
			p = index(substr(s, i), close_)
			if (p == 0) return out
			if (LXM == "s") out = out "\""
			i = i + p - 1 + length(close_); LXM = ""
			continue
		}
		c = substr(s, i, 1)
		if (c == "-" && substr(s, i + 1, 1) == "-") {
			if (match(substr(s, i + 2), /^\[=*\[/)) { LXM = "c"; LXL = RLENGTH - 2; i = i + 2 + RLENGTH; continue }
			return out
		}
		if (c == "\"" || c == "'" || c == "`") {
			j = i + 1
			while (j <= n) {
				c2 = substr(s, j, 1)
				if (c2 == "\\") { j += 2; continue }
				if (c2 == c) break
				j++
			}
			out = out "\"\""; i = j + 1
			continue
		}
		if (c == "[" && match(substr(s, i), /^\[=*\[/)) { LXM = "s"; LXL = RLENGTH - 2; out = out "\""; i += RLENGTH; continue }
		out = out c; i++
	}
	return out
}

# ---------------------------------------------------------------- findings
function addF(id, ln, lo, hi, detail, evid,    key) {
	key = id SUBSEP ln
	if (key in FSEEN) return
	FSEEN[key] = 1
	FC++
	F_id[FC] = id; F_ln[FC] = ln; F_lo[FC] = lo; F_hi[FC] = hi; F_det[FC] = detail; F_ev[FC] = evid
}
function ignored(id, ln) {
	return (("all" in IGNF) || (id in IGNF) || ((ln SUBSEP id) in IGN) || ((ln SUBSEP "all") in IGN))
}
function touchedF(k,    i, n, a) {
	if (ALLTOUCH) return 1
	if (F_ev[k] != "") {
		n = split(F_ev[k], a, " ")
		for (i = 1; i <= n; i++) if (a[i] in TOUCH) return 1
		return 0
	}
	for (i = F_lo[k]; i <= F_hi[k]; i++) if (i in TOUCH) return 1
	return 0
}

# ---------------------------------------------------------------- block stack
function push(kind, id) { SD++; SK[SD] = kind; SI[SD] = id }
function enclosingFns(    d, s) { s = ""; for (d = SD; d >= 1; d--) if (SK[d] == "fn") s = s " " SI[d]; return s }
function inLoopCtx(    d) {
	for (d = SD; d >= 1; d--) {
		if (SK[d] == "while" || SK[d] == "repeat") return 1
		if (SK[d] == "fn" && FN_kind[SI[d]] == "frame") return 1
	}
	return 0
}
function markYield(    d) {
	for (d = SD; d >= 1; d--) {
		if (SK[d] == "fn") { FN_y[SI[d]] = 1; return }
		if (SK[d] == "while" || SK[d] == "repeat") L_ok[SI[d]] = 1
	}
}
function markBreak(    d) {
	for (d = SD; d >= 1; d--) {
		if (SK[d] == "fn") return
		if (SK[d] == "while" || SK[d] == "repeat" || SK[d] == "for") { if (SK[d] != "for") L_ok[SI[d]] = 1; return }
	}
}
function markReturn(    d) {
	for (d = SD; d >= 1; d--) {
		if (SK[d] == "fn") return
		if (SK[d] == "while" || SK[d] == "repeat") L_ok[SI[d]] = 1
	}
}
function popBlock(ln, untilRest,    kind, id) {
	if (SD < 1) return
	kind = SK[SD]; id = SI[SD]; SD--
	if (kind == "fn") FN_end[id] = ln
	if (kind == "while" || kind == "repeat") {
		L_end[id] = ln
		if (kind == "repeat" && untilRest ~ /^[ \t]*\(?[ \t]*false[ \t]*\)?([^A-Za-z0-9_]|$)/) L_inf[id] = 1
	}
}

# ---------------------------------------------------------------- keyword handling
function exprIf(prefix, ln,    p, j) {
	p = prefix
	if (p ~ /^[ \t]*$/) {
		for (j = ln - 1; j >= 1; j--) if (CODE[j] !~ /^[ \t]*$/) { p = CODE[j]; break }
	}
	return (p ~ /(=|\(|,|\{|\[|\+|-|\*|\/|%|\^|<|>|\.\.|(^|[^A-Za-z0-9_])(return|and|or|not|in))[ \t]*$/)
}
function onKeyword(w, ln, c, st, en,    prefix, after, k, nm) {
	prefix = substr(c, 1, st - 1); after = substr(c, en)
	if (w == "function") {
		FNC++; k = FNC
		FN_start[k] = ln; FN_end[k] = NL; FN_y[k] = 0; FN_kind[k] = ""; FN_wrap[k] = 0
		nm = ""
		if (match(after, /^[ \t]+[A-Za-z_][A-Za-z0-9_.:]*/)) nm = lastIdent(trim(substr(after, RSTART, RLENGTH)))
		else if (match(prefix, /[A-Za-z_][A-Za-z0-9_.:]*[ \t]*=[ \t]*$/)) { nm = substr(prefix, RSTART, RLENGTH); sub(/[ \t]*=[ \t]*$/, "", nm); nm = lastIdent(nm) }
		FN_name[k] = nm
		if (match(after, /\([^)]*\)/)) { FN_params[k] = substr(after, RSTART + 1, RLENGTH - 2); FN_after[k] = substr(after, RSTART + RLENGTH) }
		else if (match(after, /\(.*/)) { FN_params[k] = substr(after, RSTART + 1); FN_after[k] = "" }
		else { FN_params[k] = ""; FN_after[k] = after }
		if (prefix ~ /OnServerEvent[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*$/ || prefix ~ /OnServerInvoke[ \t]*=[ \t]*$/) FN_kind[k] = "remote"
		else if (prefix ~ /ProcessReceipt[ \t]*=[ \t]*$/) FN_kind[k] = "receipt"
		else if (prefix ~ /PlayerRemoving[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*$/) FN_kind[k] = "leave"
		else if (prefix ~ /(Heartbeat|RenderStepped|Stepped|PreSimulation|PostSimulation|PreRender|PreAnimation)[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*$/ || prefix ~ /BindToRenderStep[ \t]*\(.*,[ \t]*$/) FN_kind[k] = "frame"
		if (prefix ~ /(pcall|xpcall|Promise\.[A-Za-z]+|[A-Za-z_]*[Rr]etry[A-Za-z_]*)[ \t]*\([^()]*$/) FN_wrap[k] = 1
		push("fn", k)
	} else if (w == "if") {
		if (!exprIf(prefix, ln)) push("if", 0)
	} else if (w == "while") {
		PW = 1; PI = (after ~ /^[ \t]*\(?[ \t]*(true|1)[ \t]*\)?[ \t]+do([^A-Za-z0-9_]|$)/) ? 1 : 0
	} else if (w == "for") {
		PF = 1
	} else if (w == "do") {
		if (PW) { LC++; L_start[LC] = ln; L_end[LC] = NL; L_inf[LC] = PI; L_ok[LC] = 0; push("while", LC) }
		else if (PF) push("for", 0)
		else push("do", 0)
		PW = 0; PF = 0; PI = 0
	} else if (w == "repeat") {
		LC++; L_start[LC] = ln; L_end[LC] = NL; L_inf[LC] = 0; L_ok[LC] = 0; push("repeat", LC)
	} else if (w == "end") {
		popBlock(ln, "")
	} else if (w == "until") {
		popBlock(ln, after)
	} else if (w == "break") {
		markBreak()
	} else if (w == "return") {
		markReturn()
	}
}

# ---------------------------------------------------------------- per-segment checks (need block context)
function segCheck(seg, ln, before,    pre, m, fns, rcv) {
	if (seg ~ /task\.wait|task\.desynchronize|task\.synchronize|(^|[^A-Za-z0-9_.:])[Ww]ait[ \t]*\(|:Wait[A-Za-z]*[ \t]*\(|coroutine\.yield|Async[ \t]*\(|:WaitForChild|:Invoke[A-Za-z]*[ \t]*\(|:[Yy]ield[ \t]*\(|:await[ \t]*\(|:expect[ \t]*\(/) markYield()
	if (match(seg, /:(GetAsync|SetAsync|UpdateAsync|IncrementAsync|RemoveAsync)[ \t]*\(/)) {
		m = substr(seg, RSTART + 1, RLENGTH - 1); sub(/[ \t]*\($/, "", m)
		pre = before substr(seg, 1, RSTART - 1)
		# HttpService:GetAsync and friends are web calls, not DataStore calls: out of scope for this rule
		rcv = ""; if (match(pre, /[A-Za-z_][A-Za-z0-9_.]*[ \t]*$/)) rcv = lastIdent(trim(substr(pre, RSTART, RLENGTH)))
		if (pre !~ /pcall|xpcall|Promise\.|[Rr]etry/ && rcv !~ /[Hh]ttp|^HS$/) {
			fns = enclosingFns()
			DSC++; DSC_ln[DSC] = ln; DSC_fns[DSC] = fns; DSC_m[DSC] = m
		}
	}
	if (match(seg, /:Connect(Parallel)?[ \t]*\(/) && inLoopCtx()) {
		pre = before substr(seg, 1, RSTART - 1)
		if (pre ~ /(^|[^=~<>])=[^=]*$/ || pre ~ /insert[ \t]*\(|:Add[ \t]*\(|:GiveTask[ \t]*\(|[Jj]anitor|[Mm]aid|[Tt]rove/) {
			if (!HASDISC) addF("connect-in-loop", ln, ln, ln, "stored but never disconnected in this file")
		} else addF("connect-in-loop", ln, ln, ln, "")
	}
}

# ---------------------------------------------------------------- per-line checks (no block context)
function lineChecks(i,    c, r, lr) {
	c = CODE[i]; r = RAW[i]
	if (c ~ /^[ \t]*$/) return
	if (!DEFWAIT && c ~ /(^|[^A-Za-z0-9_.:])[Ww]ait[ \t]*\(/ && c !~ /function[ \t]+[Ww]ait[ \t]*\(/) addF("deprecated-wait", i, i, i, "")
	if (!DEFSPAWN && c ~ /(^|[^A-Za-z0-9_.:])[Ss]pawn[ \t]*\(/ && c !~ /function[ \t]+[Ss]pawn[ \t]*\(/) addF("deprecated-spawn", i, i, i, "")
	if (!DEFDELAY && c ~ /(^|[^A-Za-z0-9_.:])[Dd]elay[ \t]*\(/ && c !~ /function[ \t]+[Dd]elay[ \t]*\(/) addF("deprecated-delay", i, i, i, "")
	if (c ~ /Instance\.new[ \t]*\([^,()]*,[ \t]*[^ \t)]/) addF("instance-new-parent", i, i, i, "")
	if (c ~ /:InvokeClient[ \t]*\(/) addF("remote-invokeclient", i, i, i, "")
	if (c ~ /:SetAsync[ \t]*\(/ && !HASORDERED && (r ~ /UserId|[Pp]layer|[Pp]lr/ || HASUSERID)) addF("datastore-setasync-player", i, i, i, "")
	if (ISCLIENT) {
		lr = tolower(r)
		# the currency word must name the object whose .Value is assigned, or be the whole attribute name
		if (tolower(c) ~ /(leaderstats|coins|cash|money|gems|gold|currency|points|diamonds|bucks|tokens|credits|robux|balance)[a-z0-9_]*(\.[a-z0-9_]+|\[[a-z0-9_"]*\])*\.value[ \t]*([-+*\/]|\.\.)?=[^=]/ || (tolower(c) ~ /\[""\](\.[a-z0-9_]+|\[[a-z0-9_"]*\])*\.value[ \t]*([-+*\/]|\.\.)?=[^=]/ && lr ~ /\[[ \t]*["'](leaderstats|coins|cash|money|gems|gold|currency|points|diamonds|bucks|tokens|credits|robux|balance)["'][ \t]*\]/) || (c ~ /:SetAttribute[ \t]*\(/ && lr ~ /setattribute[ \t]*\([ \t]*["'](coins|cash|money|gems|gold|currency|points|diamonds|bucks|tokens|credits|robux|balance)["']/)) addF("client-sets-currency", i, i, i, "")
	}
	if (c ~ /:FindFirst[A-Za-z]*[ \t]*\([^()]*\)[ \t]*(\.[A-Za-z_]|:|\[)/) addF("findfirstchild-chain", i, i, i, "")
}

# ---------------------------------------------------------------- remote handler analysis
function usesName(body, nm) { return (body ~ ("(^|[^A-Za-z0-9_.:])" nm "([^A-Za-z0-9_]|$)")) }
# A value only forwarded into plain or dotted function calls is the callee's job to check. Anything
# indexed, computed with, compared, assigned, iterated or passed to a :Method() counts as direct use.
function directUse(body, N,    B, E) {
	B = "(^|[^A-Za-z0-9_.:])"; E = "([^A-Za-z0-9_]|$)"
	if (body ~ (B N "[ \t]*(\\.[A-Za-z_]|\\[|:)")) return 1
	if (body ~ (B N "[ \t]*([-+*/%^<>]|==|~=|\\.\\.)")) return 1
	if (body ~ ("([-+*/%^<>=~]|\\.\\.)[ \t]*" N E)) return 1
	if (body ~ (":[A-Za-z_][A-Za-z0-9_]*[ \t]*\\([^\n]*" B N E)) return 1
	if (body ~ ("(pairs|ipairs|next)[ \t]*\\([ \t]*" N E) || body ~ ("#[ \t]*" N E) || body ~ ("[ \t]in[ \t]+" N E)) return 1
	return 0
}
function validated(body, nm,    N) {
	N = nm
	if (body ~ ("typeof[ \t]*\\([ \t]*" N "([^A-Za-z0-9_]|$)")) return 1
	if (body ~ ("(^|[^A-Za-z0-9_.:])type[ \t]*\\([ \t]*" N "([^A-Za-z0-9_]|$)")) return 1
	if (body ~ ("tonumber[ \t]*\\([ \t]*" N "([^A-Za-z0-9_]|$)")) return 1
	if (body ~ ("(^|[^A-Za-z0-9_.:])" N "[ \t]*:[ \t]*IsA[ \t]*\\(")) return 1
	if (body ~ ("\\[[ \t]*" N "[ \t]*\\]")) return 1
	if (body ~ ("table\\.find[ \t]*\\([^\n]*(^|[^A-Za-z0-9_.:])" N "([^A-Za-z0-9_]|$)")) return 1
	if (body ~ ("assert[ \t]*\\([^\n]*(^|[^A-Za-z0-9_.:])" N "([^A-Za-z0-9_]|$)")) return 1
	if (body ~ ("[A-Za-z_]*([Vv]alid|[Cc]heck|[Ss]anitiz|[Gg]uard|[Vv]erify|[Ee]xpect)[A-Za-z0-9_]*[ \t]*\\([^\n]*(^|[^A-Za-z0-9_.:])" N "([^A-Za-z0-9_]|$)")) return 1
	if (body ~ ("(^|[^A-Za-z0-9_])t\\.[A-Za-z]+[ \t]*\\([^\n]*(^|[^A-Za-z0-9_.:])" N "([^A-Za-z0-9_]|$)")) return 1
	if (body ~ ("(^|[^A-Za-z0-9_.:])[Ii]s[A-Z][A-Za-z0-9_]*[ \t]*\\([^\n]*(^|[^A-Za-z0-9_.:])" N "([^A-Za-z0-9_]|$)")) return 1
	return 0
}
function analyzeRemote(k,    s, e, np, P, j, nm, body, ln, bad) {
	s = FN_start[k]; e = FN_end[k]
	body = FN_after[k]
	for (ln = s + 1; ln <= e; ln++) body = body "\n" CODE[ln]
	np = split(FN_params[k], P, ",")
	bad = ""
	for (j = 2; j <= np; j++) {
		nm = P[j]; sub(/:.*/, "", nm); nm = trim(nm)
		if (nm == "" || nm ~ /^_/) continue
		if (nm == "...") {
			if (body ~ /=[ \t]*\.\.\.|\{[ \t]*\.\.\.|table\.pack[ \t]*\([ \t]*\.\.\./ && body !~ /typeof[ \t]*\(|select[ \t]*\(|[Vv]alidat|[Cc]heck|(^|[^A-Za-z0-9_])t\.[A-Za-z]+[ \t]*\(/) bad = bad (bad == "" ? "" : ", ") "..."
			continue
		}
		if (nm !~ /^[A-Za-z_][A-Za-z0-9_]*$/) continue
		if (!usesName(body, nm) || !directUse(body, nm)) continue
		if (!validated(body, nm)) bad = bad (bad == "" ? "" : ", ") nm
	}
	if (bad != "") addF("remote-unvalidated-args", s, s, e, "unchecked: " bad)
}

# ---------------------------------------------------------------- ProcessReceipt analysis
function analyzeReceipt(k,    s, e, body, ln, hasG, hasN, firstM, firstS, delegated, j, INNER) {
	s = FN_start[k]; e = FN_end[k]
	# the handler's own lines: returns inside nested callbacks (UpdateAsync transforms) do not count
	split("", INNER)
	for (j = 1; j <= FNC; j++) if (j != k && FN_start[j] > s && FN_start[j] <= e) for (ln = FN_start[j] + 1; ln <= FN_end[j]; ln++) INNER[ln] = 1
	body = FN_after[k]
	for (ln = s + 1; ln <= e; ln++) if (!(ln in INNER)) body = body "\n" CODE[ln]
	hasG = (body ~ /PurchaseGranted/); hasN = (body ~ /NotProcessedYet/)
	delegated = 0
	if (body ~ /return[ \t]+(true|false|nil)([^A-Za-z0-9_]|$)/) addF("receipt-bad-return", s, s, e, "returns true/false/nil instead of a decision")
	else if (hasG && !hasN) addF("receipt-bad-return", s, s, e, "no NotProcessedYet path for failures")
	else if (!hasG && !hasN) {
		if (body ~ /return[ \t]+[A-Za-z_]/) delegated = 1
		else addF("receipt-bad-return", s, s, e, "never returns a decision")
	}
	if (delegated) return
	if (!HASPURCHASEID) addF("receipt-no-idempotency", s, s, e, "")
	if (body ~ /[Pp]rofile|[Rr]eplica|[Dd]ata[Mm]anager|[Dd]ata[Ss]ervice/) return
	firstM = 0; firstS = 0
	for (ln = s; ln <= e; ln++) {
		if (!firstS && CODE[ln] ~ /:(UpdateAsync|SetAsync|IncrementAsync)[ \t]*\(|[Ss]ave[A-Za-z]*[ \t]*\(/) firstS = ln
		if (!firstM && CODE[ln] ~ /\.Value[ \t]*([-+*\/]|\.\.)?=[^=]|[A-Za-z0-9_\])][ \t]*[-+*\/]=[^=]|:SetAttribute[ \t]*\(/) firstM = ln
	}
	if (firstM && (!firstS || firstM < firstS)) addF("receipt-grant-before-save", firstM, s, e, firstS ? "" : "no save call in the handler")
}

# does CODE[lo..hi] write to a DataStore (calls=0), or also call a same-file saving function (calls=1)?
function rangeHas(lo, hi, calls,    i, rest, nm) {
	for (i = lo; i <= hi; i++) {
		if (CODE[i] ~ /:(SetAsync|UpdateAsync|IncrementAsync)[ \t]*\(/) return 1
		if (!calls) continue
		rest = CODE[i]
		while (match(rest, /[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) {
			nm = substr(rest, RSTART, RLENGTH); sub(/[ \t]*\($/, "", nm)
			if (nm in WN) return 1
			rest = substr(rest, RSTART + RLENGTH)
		}
	}
	return 0
}

# does CODE line c call something that yields (a same-file yielding function) or may yield (a function
# not defined in this file, or a method call)? Used by while-true-no-yield.
function mayYieldCall(c,    rest, off, st, nm, prev, pre, q) {
	rest = c; off = 0
	while (match(rest, /[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) {
		st = off + RSTART
		nm = substr(rest, RSTART, RLENGTH); sub(/[ \t]*\($/, "", nm)
		off = st + RLENGTH - 1; rest = substr(c, off + 1)
		prev = (st > 1) ? substr(c, st - 1, 1) : ""
		if (nm in YN) return 1
		if ((nm in LKW) || (nm in FNDEF)) continue
		if (prev == ":") return 1
		if (prev == ".") {
			pre = substr(c, 1, st - 2); q = ""
			if (match(pre, /[A-Za-z_][A-Za-z0-9_]*$/)) q = substr(pre, RSTART, RLENGTH)
			if (q in STDLIB) continue
			return 1
		}
		if (nm in NOYIELD) continue
		return 1
	}
	return 0
}
# is this file in scope? .luau always; .lua only in a Roblox project or when it uses Roblox globals
function inScope(path,    i) {
	if (tolower(path) !~ /\.lua$/ || robloxproj == 1) return 1
	for (i = 1; i <= NL; i++) if (RAW[i] ~ /game[ \t]*:[ \t]*GetService|script[ \t]*\.[ \t]*Parent/) return 1
	return 0
}

# ---------------------------------------------------------------- analyse one file
function resetFile() {
	split("", RAW); split("", CODE); split("", IGN); split("", IGNF); split("", TOUCH)
	split("", FN_start); split("", FN_end); split("", FN_y); split("", FN_kind); split("", FN_wrap); split("", FN_name); split("", FN_params); split("", FN_after)
	split("", L_start); split("", L_end); split("", L_inf); split("", L_ok)
	split("", SK); split("", SI); split("", DSC_ln); split("", DSC_fns); split("", DSC_m)
	split("", F_id); split("", F_ln); split("", F_lo); split("", F_hi); split("", F_det); split("", F_ev); split("", FSEEN)
	split("", PREF); split("", REMNAME); split("", RCPNAME); split("", YN); split("", LEAVENAME); split("", WN); split("", WN2); split("", FNDEF)
	FC = 0; FNC = 0; LC = 0; SD = 0; DSC = 0; NL = 0; LXM = ""; LXL = 0; PW = 0; PF = 0; PI = 0
}
function addIds(ids, target, isFile,    n, a, j) {
	n = split(ids, a, /[ ,]+/)
	for (j = 1; j <= n; j++) if (a[j] != "") { if (isFile) IGNF[a[j]] = 1; else IGN[target SUBSEP a[j]] = 1 }
}
function analyze(path,    l, i, c, rest, off, st, en, w, prevch, pos, t, s, mkt, rnd, pol, pr, wr, btc, k, j, n, a, nm, fns, prot) {
	resetFile()
	while ((getline l < path) > 0) { NL++; sub(/\r$/, "", l); RAW[NL] = l }
	close(path)
	if (NL == 0) return 0
	if (!inScope(path)) return 0
	ISCLIENT = isClientPath(path)
	for (i = 1; i <= NL; i++) CODE[i] = lex(RAW[i])

	# touched lines (hook edit scope)
	if (!ALLTOUCH) for (i = 1; i <= NL; i++) { t = trim(RAW[i]); if (!trivialLine(t) && (t in NEWSET)) TOUCH[i] = 1 }

	# ignore directives and file-level facts
	HASDISC = 0; DEFWAIT = 0; DEFSPAWN = 0; DEFDELAY = 0; HASORDERED = 0; HASUSERID = 0; HASPURCHASEID = 0
	mkt = ""; rnd = ""; pol = 0; pr = ""; wr = ""; btc = 0
	for (i = 1; i <= NL; i++) {
		if (RAW[i] ~ /lihfolk-ignore/) {
			s = RAW[i]
			if (match(s, /lihfolk-ignore-file:[ \t]*[A-Za-z0-9_, -]+/)) { s = substr(s, RSTART, RLENGTH); sub(/^lihfolk-ignore-file:[ \t]*/, "", s); addIds(s, 0, 1) }
			else if (match(s, /lihfolk-ignore:[ \t]*[A-Za-z0-9_, -]+/)) { s = substr(s, RSTART, RLENGTH); sub(/^lihfolk-ignore:[ \t]*/, "", s); addIds(s, (CODE[i] ~ /^[ \t]*$/) ? i + 1 : i, 0) }
		}
		c = CODE[i]
		if (c ~ /^[ \t]*$/) continue
		if (c ~ /:Disconnect[ \t]*\(|[Jj]anitor|[Mm]aid|[Tt]rove/) HASDISC = 1
		if (c ~ /function[ \t]+[Ww]ait[ \t]*\(|local[ \t]+[Ww]ait[ \t]*=/) DEFWAIT = 1
		if (c ~ /function[ \t]+[Ss]pawn[ \t]*\(|local[ \t]+[Ss]pawn[ \t]*=/) DEFSPAWN = 1
		if (c ~ /function[ \t]+[Dd]elay[ \t]*\(|local[ \t]+[Dd]elay[ \t]*=/) DEFDELAY = 1
		if (c ~ /GetOrderedDataStore/) HASORDERED = 1
		if (c ~ /UserId/) HASUSERID = 1
		if (c ~ /PurchaseId/) HASPURCHASEID = 1
		if (c ~ /MarketplaceService/) mkt = mkt " " i
		if (c ~ /math\.random|Random\.new|:NextInteger|:NextNumber/) rnd = rnd " " i
		if (c ~ /PolicyService|ArePaidRandomItemsRestricted|GetPolicyInfoForPlayerAsync/) pol = 1
		if (c ~ /PlayerRemoving/) pr = pr " " i
		if (match(c, /PlayerRemoving[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*[A-Za-z_][A-Za-z0-9_.:]*[ \t]*\)/)) {
			nm = substr(c, RSTART, RLENGTH); sub(/^[^(]*\([ \t]*/, "", nm); sub(/[ \t]*\)$/, "", nm); nm = lastIdent(nm)
			if (nm != "function") LEAVENAME[nm] = i
		}
		if (c ~ /:(SetAsync|UpdateAsync|IncrementAsync)[ \t]*\(/) wr = wr " " i
		if (c ~ /BindToClose/) btc = 1
		rest = c
		while (match(rest, /(pcall|xpcall|[A-Za-z_]*[Rr]etry[A-Za-z_]*|Promise\.[A-Za-z]+)[ \t]*\([ \t]*[A-Za-z_][A-Za-z0-9_.:]*/)) {
			nm = substr(rest, RSTART, RLENGTH); sub(/^[^(]*\([ \t]*/, "", nm); PREF[lastIdent(nm)] = 1
			rest = substr(rest, RSTART + RLENGTH)
		}
		if (match(c, /OnServerEvent[ \t]*:[ \t]*Connect[A-Za-z]*[ \t]*\([ \t]*[A-Za-z_][A-Za-z0-9_.:]*[ \t]*\)/)) {
			nm = substr(c, RSTART, RLENGTH); sub(/^[^(]*\([ \t]*/, "", nm); sub(/[ \t]*\)$/, "", nm); nm = lastIdent(nm)
			if (nm != "function") REMNAME[nm] = i
		}
		if (match(c, /OnServerInvoke[ \t]*=[ \t]*[A-Za-z_][A-Za-z0-9_.:]*/)) {
			nm = substr(c, RSTART, RLENGTH); sub(/^[^=]*=[ \t]*/, "", nm); nm = lastIdent(nm)
			if (nm != "function") REMNAME[nm] = i
		}
		if (match(c, /ProcessReceipt[ \t]*=[ \t]*[A-Za-z_][A-Za-z0-9_.:]*/)) {
			nm = substr(c, RSTART, RLENGTH); sub(/^[^=]*=[ \t]*/, "", nm); nm = lastIdent(nm)
			if (nm != "function") RCPNAME[nm] = i
		}
	}

	# structural pass
	for (i = 1; i <= NL; i++) {
		c = CODE[i]; pos = 1; rest = c; off = 0
		while (match(rest, /[A-Za-z_][A-Za-z0-9_]*/)) {
			st = off + RSTART; w = substr(rest, RSTART, RLENGTH); en = st + RLENGTH
			prevch = (st > 1) ? substr(c, st - 1, 1) : ""
			if ((w in KW) && prevch != "." && prevch != ":") {
				segCheck(substr(c, pos, st - pos), i, substr(c, 1, pos - 1))
				onKeyword(w, i, c, st, en)
				pos = en
			}
			off = en - 1
			rest = substr(c, off + 1)
		}
		segCheck(substr(c, pos), i, substr(c, 1, pos - 1))
		lineChecks(i)
	}

	# DataStore calls outside pcall
	for (j = 1; j <= DSC; j++) {
		prot = 0
		n = split(DSC_fns[j], a, " ")
		for (k = 1; k <= n; k++) if (FN_wrap[a[k]] || (FN_name[a[k]] != "" && (FN_name[a[k]] in PREF))) prot = 1
		if (!prot) addF("datastore-no-pcall", DSC_ln[j], DSC_ln[j], DSC_ln[j], DSC_m[j])
	}
	# infinite loops: a call to a same-file function that yields, to a function defined elsewhere, or a
	# method call counts as a (possible) yield; only loops whose calls are all known not to yield are reported
	for (k = 1; k <= FNC; k++) if (FN_name[k] != "") { FNDEF[FN_name[k]] = 1; if (FN_y[k]) YN[FN_name[k]] = 1 }
	for (j = 1; j <= LC; j++) {
		if (!L_inf[j] || L_ok[j]) continue
		prot = 0
		for (i = L_start[j]; i <= L_end[j] && !prot; i++) if (mayYieldCall(CODE[i])) prot = 1
		if (!prot) addF("while-true-no-yield", L_start[j], L_start[j], L_end[j], "")
	}
	# remote handlers and ProcessReceipt (inline or named in this file)
	for (k = 1; k <= FNC; k++) {
		if (FN_kind[k] == "remote" || (FN_name[k] != "" && (FN_name[k] in REMNAME))) analyzeRemote(k)
		if (FN_kind[k] == "receipt" || (FN_name[k] != "" && (FN_name[k] in RCPNAME))) analyzeReceipt(k)
	}
	# file-level heuristics
	if (mkt != "" && rnd != "" && !pol) { split(trim(rnd), a, " "); addF("paid-random-no-policy", a[1], a[1], a[1], "", trim(mkt rnd)) }
	# BindToClose: only when a PlayerRemoving handler saves, directly or through same-file functions (two levels)
	if (pr != "" && wr != "" && !btc) {
		for (k = 1; k <= FNC; k++) if (FN_name[k] != "" && rangeHas(FN_start[k], FN_end[k], 0)) WN[FN_name[k]] = 1
		for (k = 1; k <= FNC; k++) if (FN_name[k] != "" && !(FN_name[k] in WN) && rangeHas(FN_start[k], FN_end[k], 1)) WN2[FN_name[k]] = 1
		for (nm in WN2) WN[nm] = 1
		prot = 0
		for (k = 1; k <= FNC; k++) if ((FN_kind[k] == "leave" || (FN_name[k] != "" && (FN_name[k] in LEAVENAME))) && rangeHas(FN_start[k], FN_end[k], 1)) prot = 1
		if (prot) { split(trim(wr), a, " "); addF("datastore-no-bindtoclose", a[1], a[1], a[1], "", trim(pr wr)) }
	}
	return 1
}

# ---------------------------------------------------------------- reporting
function countVisible(    k, n) {
	n = 0; NE = 0; NW = 0; NI = 0
	for (k = 1; k <= FC; k++) {
		VIS[k] = (!ignored(F_id[k], F_ln[k]) && touchedF(k)) ? 1 : 0
		if (!VIS[k]) continue
		n++
		if (SEV[F_id[k]] == "error") NE++; else if (SEV[F_id[k]] == "warning") NW++; else NI++
	}
	return n
}
# order: severity desc, then line asc (simple selection; files are small)
function orderFindings(    k, j, cnt, best) {
	split("", ORD); split("", USED); cnt = 0
	for (j = 1; j <= FC; j++) {
		best = 0
		for (k = 1; k <= FC; k++) {
			if (!VIS[k] || (k in USED)) continue
			if (!best || SEVRANK[SEV[F_id[k]]] > SEVRANK[SEV[F_id[best]]] || (SEVRANK[SEV[F_id[k]]] == SEVRANK[SEV[F_id[best]]] && F_ln[k] < F_ln[best])) best = k
		}
		if (!best) break
		USED[best] = 1; ORD[++cnt] = best
	}
	return cnt
}
function detailOf(k) { return (F_det[k] != "") ? " (" F_det[k] ")" : "" }

function scanMain(    p, files, nf, tot, te, tw, ti, cnt, j, k) {
	ALLTOUCH = 1; nf = 0; te = 0; tw = 0; ti = 0
	while ((getline p) > 0) {
		sub(/\r$/, "", p)
		if (p == "" || p !~ /\.[Ll][Uu][Aa][Uu]?$/) continue
		if (isVendored(p)) continue
		if (!analyze(p)) continue
		nf++
		if (!countVisible()) continue
		te += NE; tw += NW; ti += NI
		cnt = orderFindings()
		for (j = 1; j <= cnt; j++) {
			k = ORD[j]
			printf "%s:%d: %s %s: %s%s | fix: %s | note: LihFolk Vault V2/%s\n", p, F_ln[k], SEV[F_id[k]], F_id[k], MSG[F_id[k]], detailOf(k), FIX[F_id[k]], REF[F_id[k]]
		}
	}
	printf "LihFolk check: %d file(s) scanned, %d error(s), %d warning(s), %d info.\n", nf, te, tw, ti
	if (te > 0) EXITCODE = 1
}

# ---------------------------------------------------------------- hook mode
# Minimal JSON reader: collects string values of the keys we need (first file_path / tool_name, every new_string).
function jUnescape(s,    out, p, ch, n) {
	if (index(s, "\\") == 0) return s
	out = ""
	while ((p = index(s, "\\")) > 0) {
		out = out substr(s, 1, p - 1); ch = substr(s, p + 1, 1); n = 2
		if (ch == "n") out = out "\n"
		else if (ch == "t") out = out "\t"
		else if (ch == "r") out = out ""
		else if (ch == "b" || ch == "f") out = out ""
		else if (ch == "u") { out = out "?"; n = 6 }
		else out = out ch
		s = substr(s, p + n)
	}
	return out s
}
function trailingBackslashes(s,    n) { n = 0; while (n < length(s) && substr(s, length(s) - n, 1) == "\\") n++; return n }
function parseHook(J,    n, P, k, str, nextOut, pending, rem) {
	n = split(J, P, "\"")
	pending = ""
	k = 2
	while (k <= n) {
		str = P[k]
		while (trailingBackslashes(P[k]) % 2 == 1 && k < n) { k++; str = str "\"" P[k] }
		nextOut = (k + 1 <= n) ? P[k + 1] : ""
		if (nextOut ~ /^[ \t\r\n]*:/) {
			rem = nextOut; sub(/^[ \t\r\n]*:/, "", rem)
			pending = (rem ~ /^[ \t\r\n]*$/) ? str : ""
		} else {
			if (pending == "file_path" && !("file_path" in JV)) JV["file_path"] = jUnescape(str)
			else if (pending == "tool_name" && !("tool_name" in JV)) JV["tool_name"] = str
			else if (pending == "new_string") JNEW = JNEW "\n" jUnescape(str)
			pending = ""
		}
		k += 2
	}
}
function hookMain(    J, l, path, tool, n, a, i, t, cnt, j, k, text, root, shown) {
	J = ""
	while ((getline l) > 0) J = J l "\n"
	JNEW = ""
	parseHook(J)
	path = JV["file_path"]; tool = JV["tool_name"]
	if (path == "") return
	if (path ~ /^[A-Za-z]:/) path = joinBy(path, "\\", "/")
	if (path !~ /\.[Ll][Uu][Aa][Uu]?$/ || isVendored(path)) return
	ALLTOUCH = (scope == "file" || tool == "Write" || (tool != "Edit" && tool != "MultiEdit")) ? 1 : 0
	split("", NEWSET)
	if (!ALLTOUCH) {
		n = split(JNEW, a, "\n")
		for (i = 1; i <= n; i++) { sub(/\r$/, "", a[i]); t = trim(a[i]); if (t != "") NEWSET[t] = 1 }
	}
	if (!analyze(path)) return
	if (!countVisible()) return
	cnt = orderFindings()
	text = "LihFolk Roblox check: " (NE + NW + NI) " issue(s) in " path " (" NE " error, " NW " warning, " NI " info). Fix them now. Only if you have verified a finding is a false positive, add `-- lihfolk-ignore: <id>` on that line or the line above, with a short reason."
	shown = 0
	for (j = 1; j <= cnt; j++) {
		if (shown >= maxshow) { text = text "\n- ... " (cnt - shown) " more; run /lihfolk:audit for the full list."; break }
		k = ORD[j]; shown++
		text = text "\n- line " F_ln[k] " [" SEV[F_id[k]] "] " F_id[k] detailOf(k) ": " MSG[F_id[k]] "\n  Fix: " FIX[F_id[k]] "\n  Note: LihFolk Vault V2/" REF[F_id[k]]
	}
	root = ENVIRON["CLAUDE_PLUGIN_ROOT"]
	if (root != "") text = text "\nLihFolk notes live under " root "/LihFolk Vault V2/ ."
	if (NE > 0) printf "{\"decision\":\"block\",\"reason\":\"%s\"}\n", jesc(text)
	else printf "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"%s\"}}\n", jesc(text)
}
