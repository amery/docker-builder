PYTHON_VENV="\$HOME/.local/share/python/main"
PYTHON_VERSION=$(python3 -c 'import sys; print("{}.{}".format(*sys.version_info[:2]))')

cat <<EOT
if [ ! -d "$PYTHON_VENV/lib/python$PYTHON_VERSION/site-packages" ]; then
	python3 -m venv "$PYTHON_VENV"
fi
export PYTHON_VENV="$PYTHON_VENV"
export PATH="\$PYTHON_VENV/bin:\$PATH"
EOT
