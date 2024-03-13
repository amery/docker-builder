#
# EDITOR
#

cat <<EOT

if [ -x "\$(which code)" ]; then
	export EDITOR=code
fi
EOT

#
# vscode extensions helper
#
code_install_extension() {
	local x= pat=
	for x; do
		pat="$(echo "$x" | sed -e 's|\.|\\.|g')"

	cat <<EOT

# $x
if ! code --list-extensions | grep -q -i -e "^$pat\$"; then
	code --install-extension $x
fi
EOT
	done
}
