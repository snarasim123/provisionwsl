#!/usr/bin/env bash
# Install the VS Code extensions used for development in this WSL environment.
# Extensions are installed on the WSL (remote) side, which is where Java/Python
# extensions need to run.
#
# Usage: ./install-vscode-extensions.sh
#
# Requires VS Code on Windows with the WSL extension, and VS Code must have been
# opened against WSL at least once (that creates ~/.vscode-server).
# Installs the latest marketplace version of each extension.

set -uo pipefail

EXTENSIONS=(
  # Java
  redhat.java
  oracle.oracle-java
  vscjava.vscode-java-pack
  vscjava.vscode-java-debug
  vscjava.vscode-java-dependency
  vscjava.vscode-java-test
  vscjava.vscode-gradle
  vscjava.vscode-maven
  visualstudioexptteam.vscodeintellicode
  visualstudioexptteam.intellicode-api-usage-examples
  # Python
  ms-python.python
  ms-python.vscode-pylance
  ms-python.debugpy
  ms-python.vscode-python-envs
  donjayamanne.python-extension-pack
  donjayamanne.python-environment-manager
  kevinrose.vsc-python-indent
  njpwerner.autodocstring
  batisteo.vscode-django
  wholroyd.jinja
  # Other
  anthropic.claude-code
)

# Prefer the VS Code server CLI inside WSL; works from any bash shell.
CLI=$(ls -t "$HOME"/.vscode-server/bin/*/bin/code-server 2>/dev/null | head -1)
if [ -z "$CLI" ]; then
  # Inside a VS Code integrated terminal connected to WSL, `code` is the remote CLI.
  if [ -n "${VSCODE_IPC_HOOK_CLI:-}" ] && command -v code >/dev/null; then
    CLI=code
  else
    echo "ERROR: VS Code server not found in ~/.vscode-server." >&2
    echo "Open VS Code on Windows, run 'WSL: Connect to WSL' once, then re-run this script." >&2
    exit 1
  fi
fi
echo "Using: $CLI"

failed=()
for ext in "${EXTENSIONS[@]}"; do
  echo "--- $ext"
  "$CLI" --install-extension "$ext" --force || failed+=("$ext")
done

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "All ${#EXTENSIONS[@]} extensions installed. Reload VS Code windows to pick them up."
else
  echo "Failed: ${failed[*]}" >&2
  exit 1
fi
