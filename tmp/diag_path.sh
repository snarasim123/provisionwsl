#!/bin/bash
echo "=== OSTYPE ==="
echo "$OSTYPE"
echo "=== STARTUP_FOLDER ==="
echo "$STARTUP_FOLDER"
echo "=== user_name ==="
echo "$user_name"
echo "=== PYENV_ROOT ==="
echo "$PYENV_ROOT"
echo "=== PATH (split) ==="
echo "$PATH" | tr ':' '\n'
echo "=== PATH (raw) ==="
echo "$PATH"
