#!/bin/sh

set -eu

RUN_VERSION="1.15.3"

#
#
die() {
	echo "$*" >&2
	exit 1
}

#
#
builder_brute_find() {
	local op="$1" cue="$2"

	while [ "$PWD" != / ]; do

		if [ $op "$PWD/$cue" ]; then
			echo "$PWD"
			break
		fi

		cd ..
	done
}

#
#
builder_find_workspace() {
	local ws= prev="$PWD" check="${1:-}"

	# any .repo workspace wins
	ws="$(builder_brute_find -d .repo)"
	if [ ! -d "$ws" ]; then
		while true; do
			# try .git repositories
			ws="$(git rev-parse --show-superproject-working-tree 2> /dev/null || true)"
			[ -d "$ws" ] || ws="$(git rev-parse --show-toplevel 2> /dev/null || true)"

			if [ ! -d "$ws" ]; then
				# no deeper git-root, accept what we had
				ws=
				break
			elif [ -z "$check" ]; then
				# remember this git-root, but try deeper
				prev="$ws"
				cd "$ws/.."
			elif $check "$ws"; then
				# remember this git-root, but try deeper
				prev="$ws"
				cd "$ws/.."
			elif [ "$ws" != / ]; then
				# remember this git-root, but try deeper
				prev="$ws"
				cd "$ws/.."
			else
				# can't go deeper, just take it
				break
			fi
		done
	fi

	echo "${ws:-$prev}"
}

#
#
builder_find_docker_dir() {
	local run_sh="$1" dir="$2"

	if [ -z "$dir" ]; then
		dir="$(dirname "$run_sh")"

		while [ ! -s "$dir/Dockerfile" ]; do
			if [ -L "$run_sh" ]; then
				# follow symlink
				run_sh="$(readlink "$run_sh")"

				case "$run_sh" in
				/*)	;;
				*)	run_sh="$(realpath "$dir/$run_sh")" ;;
				esac

				dir="$(dirname "$run_sh")"
			else
				die "$1: failed to detect Dockerfile"
			fi
		done

	elif [ ! -s "$dir/Dockerfile" ]; then
		die "$dir: invalid docker directory"
	fi

	echo "$dir"
}

#
builder__filter_volumes() {
	local list= match= m=
	local d= n= prev= new=

	while read d n; do
		new=true

		if match="$(echo "$list" | grep "^$d:")"; then
			for m in $match; do
				# known device, known base?

				prev="${match#*:}"
				if [ "$prev" = / ]; then
					new=false
				elif expr "$n" : "$prev/" > /dev/null; then
					new=false
				fi

				$new || break
			done
		fi

		if $new; then
			list="${list:+$list
}$d:$n"
			echo "$n"
		fi
	done
}

builder_gen_filter_volumes() {
	local k= v=

	for k; do

		case "$k" in
		!*) v="${k#!}" ;;
		*)  eval "v=\"\${$k:-}\"" ;;
		esac

		if [ -z "$v" ]; then
			continue
		elif [ -L "$v" ]; then
			readlink -f "$v"
			dirname "$v"
		else
			echo "$v"
		fi

	done | sort -uV | grep -v "^$HOME\$" | xargs -r stat -c '%d %n' | builder__filter_volumes
	echo "$HOME"
}

#
builder_gen_volumes() {
	builder_gen_filter_volumes "$@" | sort -V | while read x; do
		# create missing directories
		[ -d "$x/" ] || mkdir -p "$x"

		# prevent root-owned directories at $home_dir
		case "$x" in
		"$HOME"/*|"$HOME")
			x0="${x#$HOME}"
			mkdir -p "$home_dir$x0"
			;;
		esac

		# render -v pairs
		case "$x" in
		"$HOME")
			echo "-v \"$home_dir:$x\""
			;;
		*)
			echo "-v \"$x:$x\""
			;;
		esac
	done | tr '\n' ' '
}

#
builder_gen_env() {
	local x= v=
	for x; do
		eval "v=\"\${$x:-}\""
		if [ -n "$v" ]; then
			echo "-e \"$x=$v\""
		fi
	done | tr '\n' ' '
}

#
#
builder_run_exec() {
	local home_dir=
	local WS="$1"
	shift 1

	# preserve user identity
	local USER_NAME="$(id -urn)"
	local USER_UID="$(id -ur)"
	local USER_GID="$(id -gr)"

	if [ -z "${HOME:-}" ]; then
		HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
	fi

	# hook to extend run.sh before mounting volumes or exporting variables
	#
	if [ -d "${DOCKER_DIR:-}" -a -s "${DOCKER_DIR:-}/run-hook.sh" ]; then
		. "$DOCKER_DIR/run-hook.sh"
	fi

	# persistent volumes
	#
	if [ -z "${DOCKER_RUN_CACHEDIR:-}" ]; then
		DOCKER_RUN_CACHEDIR="$WS/.docker-run-cache"
	fi

	home_dir="$DOCKER_RUN_CACHEDIR$HOME"

	# add more options
	#
	# volumes -> -v
	# gen_env -> -e
	#
	eval "set -- \
		$(builder_gen_volumes ${DOCKER_RUN_VOLUMES:-} HOME PWD WS) \
		$(builder_gen_env ${DOCKER_RUN_ENV:-}) \
		${DOCKER_EXTRA_OPTS:-} \
		\"\$@\""

	# PTRACE
	set -- \
		--cap-add SYS_PTRACE \
		--security-opt apparmor:unconfined \
		--security-opt seccomp:unconfined \
		"$@"

	# isatty()
	if [ -t 0 ]; then
		set -- -ti "$@"
	else
		set -- -i "$@"
	fi

	# and finally run within the container
	set -x
	exec docker run --rm \
		-e USER_HOME="$HOME" \
		-e USER_NAME="$USER_NAME" \
		-e USER_UID="$USER_UID" \
		-e USER_GID="$USER_GID" \
		-e CURDIR="$PWD" \
		-e WS="$WS" \
		"$@"
}

# labels
#
docker__labels() {
	docker inspect --format "{{range \$Key, \$Value := .Config.Labels}}{{\$Key}}={{\$Value}}:{{end}}" "$1" | tr ':' '\n'
	echo "docker-builder.version.run=$RUN_VERSION"
}

docker_labels() {
	docker__labels "$1" | sed '/^[ \t]*$/d;' | sort -uV
}

docker_env_labels() {
	docker__labels "$1" | grep '^docker-builder\.run-env\.' | cut -d= -f2- | tr ' ' '\n' | sort -u
}

docker_bind_labels() {
	docker__labels "$1" | grep '^docker-builder\.run-bind\.' | cut -d= -f2- | tr ' ' '\n' | sort -u
}

docker_version_labels() {
	docker__labels "$1" | grep '^docker-builder\.version\.' | cut -d. -f3- | sort -V
}

# special options
#
USER_IS_SUDO=
while [ $# -gt 0 ]; do
	case "$1" in
	-V)	cat <<-EOT >&2
		docker-builder-run $RUN_VERSION
		https://github.com/amery/docker-builder
		EOT
		exit 1 ;;
	-l)	docker_labels "$DOCKER_ID"
		;;

	--pull) DOCKER_BUILD_FORCE=true ;;
	-r)	USER_IS_SUDO=true ;;
	-p)	DOCKER_EXPOSE="${DOCKER_EXPOSE:+$DOCKER_EXPOSE }$2"
		shift ;;
	-x)	set -x ;;
	--)	shift; break ;;
	*)	break ;;
	esac
	shift
done

# DOCKER_ID
if [ -z "${DOCKER_ID:-}" ]; then
	DOCKER_DIR="$(builder_find_docker_dir "$0" "${DOCKER_DIR:-}")"

	if [ -d "$DOCKER_DIR" ]; then
		docker build ${DOCKER_BUILD_FORCE:+--pull --no-cache }${DOCKER_BUILD_OPT:---rm} "$DOCKER_DIR"
		DOCKER_ID="$(docker build -q --rm "$DOCKER_DIR")"
	fi
elif [ -n "${DOCKER_BUILD_FORCE:-}" ]; then
	docker pull "$DOCKER_ID"
fi

DOCKER_ENV_LABELS="$(docker_env_labels "$DOCKER_ID")"
DOCKER_VERSION_LABELS="$(docker_version_labels "$DOCKER_ID")"

# pass-through environment
#
for x in $DOCKER_ENV_LABELS USER_IS_SUDO; do
	DOCKER_RUN_ENV="${DOCKER_RUN_ENV:+$DOCKER_RUN_ENV }$x"
done

# -v requested by the image itself
#
for x in $(docker_bind_labels "$DOCKER_ID"); do
	case "$x" in
	/tmp/.X11-unix)
		if [ -d "$x" ]; then
			DOCKER_RUN_VOLUMES="${DOCKER_RUN_VOLUMES:+$DOCKER_RUN_VOLUMES }!$x"
		else
			die "docker-builder.run-bind: '$x' directory not found"
		fi
		;;
	*)
		die "docker-builder.run-bind: '$x' not supported"
		;;
	esac
done

# detect run mode
#
DOCKER_RUN_MODE=
for x in $DOCKER_ENV_LABELS; do

	case "$x" in
	GOPATH)
		x=golang ;;
	NPM_CONFIG_PREFIX)
		x=nodejs ;;
	DISPLAY)
		x=x11 ;;
	*)
		continue ;;
	esac

	if ! echo "$DOCKER_RUN_MODE" | grep -q "^$x\$"; then
		DOCKER_RUN_MODE="${DOCKER_RUN_MODE:+$DOCKER_RUN_MODE
}$x"
	fi
done

# find root of the "workspace"
#
if [ ! -d "${DOCKER_RUN_WS:-}" ]; then
	CHECKER=

	for x in $DOCKER_RUN_MODE; do
		case "$x" in
		golang)
			f="test -d %/pkg"
			CHECKER="${CHECKER:+$CHECKER && }$f"
			;;
		nodejs)
			f="test -d %/node_modules -o -d %/lib/node_modules"
			CHECKER="${CHECKER:+$CHECKER && }$f"
			;;
		esac
	done

	if [ -n "$CHECKER" ]; then
		eval "check_ws() { $(echo "$CHECKER" | sed -e 's|%|"$1"|g'); }"
		CHECKER=check_ws
	fi

	DOCKER_RUN_WS=$(builder_find_workspace $CHECKER)
fi

# initialise workspace based on run mode
for x in $DOCKER_RUN_MODE; do
	case "$x" in
	golang)
		[ -d "${GOPATH:-}" ] || GOPATH="$DOCKER_RUN_WS"
		mkdir -p "$GOPATH/bin" "$GOPATH/src" "$GOPATH/pkg"

		DOCKER_RUN_VOLUMES="${DOCKER_RUN_VOLUMES:+$DOCKER_RUN_VOLUMES } GOPATH"
		;;
	nodejs)
		[ -n "${NPM_CONFIG_PREFIX:-}" ] || export NPM_CONFIG_PREFIX="$DOCKER_RUN_WS"

		DOCKER_RUN_VOLUMES="${DOCKER_RUN_VOLUMES:+$DOCKER_RUN_VOLUMES } NPM_CONFIG_PREFIX"
		;;
	x11)
		[ -n "${DISPLAY:-}" -a -d /tmp/.X11-unix -a -d /dev/snd ] || die "x11: mode not available"

		DOCKER_RUN_VOLUMES="${DOCKER_RUN_VOLUMES:+$DOCKER_RUN_VOLUMES }!/tmp/.X11-unix"
		DOCKER_EXTRA_OPTS="${DOCKER_EXTRA_OPTS:+$DOCKER_EXTRA_OPTS }--device /dev/snd"

		if [ -d /dev/dri ]; then
			DOCKER_RUN_VOLUMES="${DOCKER_RUN_VOLUMES:+$DOCKER_RUN_VOLUMES }!/dev/dri"
		fi
	esac
done

# port expose
#
for x in ${DOCKER_EXPOSE:-}; do

	case "$x" in
	*:*/*)  ;;
	*/*)    x="${x%/*}:$x" ;;
	*)      x="$x:$x/tcp" ;;
	esac

	export DOCKER_EXTRA_OPTS="${DOCKER_EXTRA_OPTS:+$DOCKER_EXTRA_OPTS }-p $x"
done

# run
#
builder_run_exec "$DOCKER_RUN_WS" ${USER_IS_SUDO:+--cap-add=SYS_ADMIN} "$DOCKER_ID" "$@"
