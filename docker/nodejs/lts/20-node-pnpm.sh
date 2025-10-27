#!/bin/sh

PNPM_HOME="\$HOME/.local/share/pnpm/"
cat <<EOT
if [ -d "$PNPM_HOME" ]; then
	export PNPM_HOME="$PNPM_HOME"
	export PATH="$PNPM_HOME:\$PATH"
fi
EOT
