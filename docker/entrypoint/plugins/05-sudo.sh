# shellcheck shell=sh

# Grant the workspace user passwordless sudo. These images are ephemeral
# developer environments — run with --rm, one workspace user, no service
# accounts — so the grant is unconditional rather than gated behind a
# knob: there is no privilege boundary here for a password to defend, and
# a build script that wants `sudo apt-get install` should simply get it.
#
# The rule names the user directly rather than adding them to %sudo: the
# entrypoint creates the user with a primary group only, so there is no
# group membership to lean on, and a drop-in leaves /etc/sudoers and the
# group database untouched.
#
# 0440 is sudo's requirement, not house style — it refuses to read a
# sudoers file that is group- or world-writable. atomic_install writes
# through a "$dest.$$" temporary, and sudo ignores any /etc/sudoers.d
# name containing a dot, so the transient file is inert: a login racing
# this sees either no rule or the finished one, never a partial.
#
# Like the no-autostart write in 05-gnupg.sh this is a pure root
# side-effect at profile-generation time — echo's stdout lands in the
# file, so the plugin contributes nothing to the login profile.
atomic_install "/etc/sudoers.d/$USER_NAME" 0440 \
	echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL"
