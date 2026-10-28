#!/bin/sh
# LihFolk Roblox/Luau checker - POSIX entry point (macOS, Linux, Windows Git Bash).
# Needs only sh + awk + find, which every supported Claude Code platform with a POSIX shell has.
#
#   Hook mode (default): reads the PostToolUse JSON on stdin, checks the edited .lua/.luau file
#                        and prints hook JSON so Claude sees the findings. Always exits 0.
#   Scan mode:           lihfolk-check.sh --scan [path ...]   (files or folders, default ".")
#                        prints "path:line: severity id: message | fix | note"; exit 1 if any error.
#
# Environment: LIHFOLK_HOOK=off disables the hook; LIHFOLK_HOOK_SCOPE=file reports the whole file
# on Edit/MultiEdit instead of only the edited lines; LIHFOLK_HOOK_MAX caps findings shown (15).

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RULES="$DIR/rules.tsv"
ENGINE="$DIR/lihfolk-check.awk"

if [ "$1" = "--scan" ]; then
	shift
	[ $# -eq 0 ] && set -- .
	for p in "$@"; do
		if [ -d "$p" ]; then
			find "$p" \( -name .git -o -name node_modules -o -name Packages -o -name DevPackages -o -name ServerPackages -o -name _Index \) -prune -o \
				-type f \( -name '*.lua' -o -name '*.luau' \) -print
		elif [ -f "$p" ]; then
			printf '%s\n' "$p"
		else
			echo "lihfolk-check: no such file or folder: $p" >&2
		fi
	done | LC_ALL=C awk -v mode=scan -v rules="$RULES" -f "$ENGINE"
	exit $?
fi

# Hook mode: never break the user's session because of the checker itself.
[ "${LIHFOLK_HOOK:-on}" = "off" ] && { cat >/dev/null; exit 0; }
command -v awk >/dev/null 2>&1 || { cat >/dev/null; exit 0; }
LC_ALL=C awk -v mode=hook -v rules="$RULES" -v scope="${LIHFOLK_HOOK_SCOPE:-edit}" -v maxshow="${LIHFOLK_HOOK_MAX:-15}" -f "$ENGINE"
exit 0
