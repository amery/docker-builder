cat <<EOT
mkdir -p "\$HOME/.local/share/pnpm"
export PNPM_HOME="\$HOME/.local/share/pnpm"
export PATH="\$PNPM_HOME:\$PATH"
EOT
