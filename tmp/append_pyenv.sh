#!/bin/bash
# Append pyenv initialization to ~/.bashrc_custom
cat >> ~/.bashrc_custom << 'PYENV_BLOCK'

# Pyenv initialization
export PYENV_ROOT="$HOME/.pyenv"
if [[ -d "$PYENV_ROOT/bin" ]]; then
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    # pyenv-virtualenv initialization
    if [[ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]]; then
        eval "$(pyenv virtualenv-init -)"
    fi
fi
PYENV_BLOCK
echo "Pyenv init block appended to ~/.bashrc_custom"
