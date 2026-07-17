# shellcheck shell=sh

cat <<EOT
mkdir -p "\$HOME/.local/share/pnpm"
export PNPM_HOME="\$HOME/.local/share/pnpm"
path_prepend "\$PNPM_HOME"
EOT
