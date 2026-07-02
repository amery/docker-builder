gen_npm_prefix() {
	# Bake the entrypoint-time workspace: the login `su -` strips WS,
	# so only the value captured here survives into the login shell.
	# When it is unset — the devcontainer build, where WS arrives only
	# in the login environment — defer resolution to login time
	# instead, matching gen_profile's baked+deferred workspace pair.
	# literal on purpose: emitted into the profile, expanded at login
	# shellcheck disable=SC2016
	local ws='${WS:-}'

	[ -z "${WS:-}" ] || ws="$WS"

	if [ -n "${NPM_CONFIG_PREFIX:-}" ]; then
		cat <<EOF
	export NPM_CONFIG_PREFIX="$NPM_CONFIG_PREFIX"
EOF
	else
		cat <<EOF
	if [ -n "$ws" -a -d "$ws/node_modules" ]; then
		export NPM_CONFIG_PREFIX="$ws"
	else
		export NPM_CONFIG_PREFIX="\$HOME/.local/share/npm"
	fi
EOF
	fi
}

cat <<EOT

if [ -s "\$HOME/.nvm/nvm.sh" ]; then
	unset NPM_CONFIG_PREFIX
	export -n NPM_CONFIG_PREFIX || true

	export NVM_DIR="\$HOME/.nvm"
	. "\$NVM_DIR/nvm.sh"

	if [ -s "\$NVM_DIR/bash_completion" ]; then
		. "\$NVM_DIR/bash_completion"
	fi
else
	mkdir -p "\$HOME/.local/share/npm/bin"
	path_prepend "\$HOME/.local/share/npm/bin"

$(gen_npm_prefix)
fi
EOT
unset gen_npm_prefix

npm_needs() {
	if [ $# -gt 0 ]; then
		cat <<EOT

if ! type -p $1 2> /dev/null >&2; then
	echo "+ npm i -g $*" >&2
	npm i -g $*
fi
EOT
	fi
}
