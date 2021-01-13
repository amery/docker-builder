#!/bin/sh

set -eu

# find root of the "workspace"
find_repo_workspace_root() {
	if [ -d "$1/.repo" ]; then
		echo "$1"
	elif [ "${1:-/}" != / ]; then
		find_repo_workspace_root "${1%/*}"
	fi
}

WS="$(find_repo_workspace_root "$PWD")"
if [ -z "$WS" ]; then
	WS="$(cd "$(dirname "$0")" && pwd)"
fi
O="$WS/out"

err() {
	if [ $# -gt 0 ]; then
		echo "$*"
	else
		cat
	fi | sed ${O:+-e "s|$O/|\$O/|g"} ${WS+-e "s|$WS/|\$WS/|g"} -e "s|$HOME/|\$HOME/|g" >&2
}

putenv() {
	local k="$1" v=
	shift

	if [ $# -gt 0 ]; then
		v="$*"
	else
		v="$(eval echo "\$$k")"
	fi

	err "+ export $k=\"$v\""
	export "$k=$v"
}

# do we really need this? shouldn't rpath include the right locations already? -amery
for d in /usr/local/lib /usr/local/lib/$(uname -m)-*; do
	[ -d "$d" ] || continue
	LD_LIBRARY_PATH="$d${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
done

err <<EOT
+ HOME=$HOME
+ WS=$WS
EOT

if [ -d "$O/" ]; then
	err "+ O=$O"

	putenv PATH "$O/bin:$PATH"
	LD_LIBRARY_PATH="$O/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
else
	O=
fi

FILTER=
QUIET=
SED=

if [ -n "$(sed 2>&1 | grep -- -u,)" ]; then
	SED="sed -u"
else
	SED="stdbuf -i0 -i0 sed"
fi

NORMAL="$(printf '\x1b[39;49m')"
COLOUR="$NORMAL"

RED="$(printf '\x1b[31m')"
GREEN="$(printf '\x1b[32m')"
YELLOW="$(printf '\x1b[33m')"
BLUE="$(printf '\x1b[34m')"
MAGENTA="$(printf '\x1b[35m')"
CYAN="$(printf '\x1b[36m')"

UxFFFD="$(printf '\xef\xbf\xbd')"

while [ $# -gt 0 ]; do
	case "${1:-}" in
	-s)	WRAPPER=strace ;;
	-g)	WRAPPER=gdb ;;
	-l)	WRAPPER=ltrace ;;
	-m)     WRAPPER=valgrind ;;

	-q)	QUIET=true ;;
	-v)	QUIET= ;;

	-e)
		if [ "$COLOUR" = "$RED" ]; then
			COLOUR="$GREEN"
		elif [ "$COLOUR" = "$GREEN" ]; then
			COLOUR="$MAGENTA"
		elif [ "$COLOUR" = "$MAGENTA" ]; then
			COLOUR="$YELLOW"
		elif [ "$COLOUR" = "$YELLOW" ]; then
			COLOUR="$CYAN"
		elif [ "$COLOUR" = "$CYAN" ]; then
			COLOUR="$BLUE"
		else
			COLOUR="$RED"
		fi


		case "$2" in
		"^"*"$") PATTERN="$2" ;;
		"^"*)    PATTERN="$2.*" ;;
		*"$")    PATTERN=".*$2" ;;
		*)       PATTERN=".*$2.*"
		esac

		FILTER="${FILTER:+$FILTER }-e 's!$PATTERN!$COLOUR\0$NORMAL!g'"
		shift
		;;

	*)
		break
		;;
	esac
	shift
done

SOURCES_BASE=
if [ -x "${1:-}" ]; then
	# autotools **/.libs/elf
	#
	x=$(readlink -f "$1")
	x=${x%/*}
	if [ "${x##*/}" = ".libs" ]; then
		LD_LIBRARY_PATH="$x${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
		SOURCES_BASE="${x%/*}"
	fi
fi

[ -z "${LD_LIBRARY_PATH:-}" ] || putenv LD_LIBRARY_PATH

if [ $# -gt 0 ]; then
	case "${WRAPPER:-}" in
	strace)
		set -- strace -vvq -TttfF -s4096 ${QUIET:+-o strace.out} "$@"
		;;
	ltrace)
		set -- ltrace -CS -n2 -Tttf -s4096 ${QUIET:+-o ltrace.out} "$@"
		if [ -z "$QUIET" ]; then
			# new lines that don't come from ltrace get replaced with a dot
			FILTER="'N;s/\\n\\([^\[]\\)/${UxFFFD}\1/;P;D' ${FILTER:+| $SED $FILTER}"
		fi
		;;
	valgrind)
		set -- valgrind -v \
			--leak-check=full --show-leak-kinds=all \
			--track-origins=yes \
			"$@"
		;;
	gdb)
		FILTER=
		GDB_OPT=

		set -- -ex run --args "$@"

		if [ -f .gdbinit ]; then
			GDB_OPT='-n'
			set -- -x "$PWD/.gdbinit" "$@"
		else
			set -- -ex 'break main' "$@"
		fi

		set -- gdb $GDB_OPT \
			${SOURCES_BASE:+-ex "dir $SOURCES_BASE"} \
			-ex 'set breakpoint pending on' \
			"$@"
		;;
	esac
else
	case "${WRAPPER:-}" in
	strace|ltrace|gdb)
		echo "$0: nothing to run" >&2
		exit 1;
		;;
	*)
		set -- /bin/bash
		;;
	esac
fi

ulimit -c unlimited
if [ -n "$FILTER" ]; then
	( set -x; exec "$@" ) 2>&1 | eval "$SED $FILTER"
else
	set -x
	exec "$@"
fi
