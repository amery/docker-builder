#!/bin/sh

TAB=$(printf "\t")
DOLLAR="\$\$"

cat <<EOT
export DOCKER
SCRIPTS = $(dirname "$0")

EOT

if [ $# -eq 0 ]; then
	# no variable replacements
	#
	cat <<EOT
%: %.in \$(RULES_MK) \$(CONFIG_MK)
	cat \$< > \$@

\$(CONFIG_MK): \$(RULES_MK)
	touch \$@
EOT
	exit
fi

cat <<EOT
%: %.in \$(RULES_MK) \$(CONFIG_MK)
	sed \\
EOT
for x; do
	echo "$TAB$TAB-e 's|@@$x@@|\$($x)|g' \\"
	done

	cat <<EOT
		\$< > \$@~
	mv \$@~ \$@
EOT

X="${DOLLAR}x"
cat <<EOT

\$(CONFIG_MK): \$(RULES_MK)
	for x in $*; do \\
		if ! grep -q "^$X " \$@ 2> /dev/null; then \\
			echo "$X ?=" >> \$@; \\
		fi; \\
	done
	touch \$@
EOT
