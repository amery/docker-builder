# shellcheck shell=sh

# Carry the image's locale into the login profile.
#
# `su -` clears the environment, so the ENV LANG a Dockerfile sets never
# reaches a login shell on its own. Every login that goes through su
# gets it back from PAM, which reads /etc/default/locale through pam_env
# (see /etc/pam.d/su) — but an interactive login on these releases does
# not: shadow's su predates --pty, so the entrypoint drops privileges
# with chroot instead, behind an env -i besides. No PAM session, nothing
# to restore the locale, and the shell comes up with an empty LANG and
# an ASCII filesystem encoding — which BitBake, among others, refuses to
# run under.
#
# So carry it here, into the profile every login sources whichever way
# it arrived. Only the releases with that fallback take this plugin;
# 20.04 and later have a util-linux su, whose every login is a real PAM
# session.
#
# This file only, never pam_env's other source /etc/environment: that
# one carries PATH, which gen_profile owns. The locale is fixed at image
# build time, so the values are baked rather than deferred, and `:=`
# leaves alone a value forwarded from the host — and with it the su
# paths, where PAM has already set these.
if [ -r /etc/default/locale ]; then
	while IFS= read -r locale_line; do
		# the NAME=value lines update-locale writes, and nothing
		# else — its header comment among the rest
		case "$locale_line" in
		[A-Z]*=*) ;;
		*) continue ;;
		esac

		locale_name="${locale_line%%=*}"
		locale_value="${locale_line#*=}"
		locale_value="${locale_value#\"}"
		locale_value="${locale_value%\"}"
		locale_value="${locale_value#\'}"
		locale_value="${locale_value%\'}"

		# A locale name is drawn from a narrow alphabet, so one
		# that stays inside it needs no quoting in the profile —
		# and one that strays is not a locale name, and is dropped
		# rather than quoted around.
		case "$locale_value" in
		'' | *[!A-Za-z0-9_.@-]*) continue ;;
		esac

		# shellcheck disable=SC2016 # a printf format, literal by design
		printf ': "${%s:=%s}"\nexport %s\n' \
			"$locale_name" "$locale_value" "$locale_name"
	done < /etc/default/locale

	unset locale_line locale_name locale_value
fi
