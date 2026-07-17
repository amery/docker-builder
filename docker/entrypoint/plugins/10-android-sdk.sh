# shellcheck shell=sh

cat <<EOT

export JAVA_HOME="$JAVA_HOME"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
path_prepend "\${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin"
EOT
