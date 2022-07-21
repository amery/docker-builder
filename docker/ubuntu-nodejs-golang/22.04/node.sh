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
	export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$WS}"
fi
EOT

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
