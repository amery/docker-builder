cat <<EOT
# vim support for vscode
if ! code --list-extensions | grep -q -e '^vscodevim\.vim$'; then
	code --install-extension vscodevim.vim
fi
EOT
