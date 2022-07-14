cat <<EOT

export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$WS}"
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
