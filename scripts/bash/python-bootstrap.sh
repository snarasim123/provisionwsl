#!/usr/bin/env bash

read_python_bootstrap_mode() {
    local mode_file="$1/python-bootstrap-mode.conf"
    local values=()
    if [[ ! -f "$mode_file" || ! -r "$mode_file" ]]; then
        echo "ERROR: Cannot read $mode_file; create it with the sole value safe or legacy." >&2
        return 1
    fi
    mapfile -t values < "$mode_file" || return 1
    if [[ ${#values[@]} -ne 1 ]]; then
        echo "ERROR: $mode_file must contain exactly one value: safe or legacy." >&2
        return 1
    fi
    PYTHON_BOOTSTRAP_MODE="${values[0]%$'\r'}"
    case "$PYTHON_BOOTSTRAP_MODE" in
        safe|legacy) ;;
        *) echo "ERROR: Invalid Python bootstrap mode in $mode_file; use safe or legacy." >&2; return 1 ;;
    esac
    PYTHON_BOOTSTRAP_STATE="$HOME/.local/state/provisionwsl/python-bootstrap-mode"
    export PYTHON_BOOTSTRAP_MODE
    echo "#### Python bootstrap mode: $PYTHON_BOOTSTRAP_MODE"
    if [[ "$PYTHON_BOOTSTRAP_MODE" == legacy ]]; then
        echo "WARNING: Legacy mode may replace Ubuntu Python/pip links and override distro-managed pip packages. It does not roll back previous changes." >&2
    fi
}

require_prepared_python_mode() {
    local prepared_mode
    if [[ ! -r "$PYTHON_BOOTSTRAP_STATE" ]]; then
        echo "ERROR: Missing prepared Python state. Rerun prep-install.sh for this instance before install.sh." >&2
        return 1
    fi
    prepared_mode=$(cat "$PYTHON_BOOTSTRAP_STATE") || return 1
    if [[ "$prepared_mode" != "$PYTHON_BOOTSTRAP_MODE" ]]; then
        echo "ERROR: Prepared Python mode '$prepared_mode' differs from requested '$PYTHON_BOOTSTRAP_MODE'. Restore the configuration or rerun prep-install.sh; mode changes are not rollback." >&2
        return 1
    fi
}

record_prepared_python_mode() {
    mkdir -p "$(dirname "$PYTHON_BOOTSTRAP_STATE")" || return 1
    printf '%s\n' "$PYTHON_BOOTSTRAP_MODE" > "$PYTHON_BOOTSTRAP_STATE"
}

select_python_distutils_package() {
    [[ "$PYTHON_VERSION" =~ ^3\.[0-9]+$ ]] || {
        echo "ERROR: PYTHON_VERSION must be a Python 3 major.minor value." >&2
        return 1
    }
    PYTHON_DISTUTILS_PKG=""
    if (( 10#${PYTHON_VERSION#3.} < 12 )); then
        PYTHON_DISTUTILS_PKG="${PYTHON_CMD}-distutils"
    fi
}

configure_ansible_runtime() {
    MANAGED_PYTHON=/usr/bin/python3
    ANSIBLE_ENV="$HOME/.local/share/provisionwsl/ansible"
    if [[ "$PYTHON_BOOTSTRAP_MODE" == safe ]]; then
        export ANSIBLE_COLLECTIONS_PATH="$HOME/.local/share/provisionwsl/collections"
        export ANSIBLE_COLLECTIONS_SCAN_SYS_PATH=false
        if [[ "$distro_type" == alpine ]]; then
            ANSIBLE_BIN=/usr/bin
        else
            ANSIBLE_BIN="$ANSIBLE_ENV/bin"
        fi
        export ANSIBLE_PYTHON_INTERPRETER="$MANAGED_PYTHON"
        export PATH="$ANSIBLE_BIN:$PATH"
    else
        ANSIBLE_BIN=$(dirname "$(command -v ansible-playbook)") || return 1
        MANAGED_PYTHON=auto_silent
    fi
    ANSIBLE_PLAYBOOK="$ANSIBLE_BIN/ansible-playbook"
    ANSIBLE_GALAXY="$ANSIBLE_BIN/ansible-galaxy"
    export PYTHON_BOOTSTRAP_MODE
    echo "#### Ansible executable: $ANSIBLE_PLAYBOOK; managed-host Python: $MANAGED_PYTHON"
}

assert_native_ubuntu_python() {
    local native_version
    native_version=$(awk -F ' *= *' '$1 == "default-version" {print $2}' /usr/share/python3/debian_defaults) || return 1
    if [[ -z "$native_version" || "$(readlink /usr/bin/python3)" != "$native_version" ]]; then
        echo "ERROR: Ubuntu system Python was replaced or cannot be identified. Safe mode does not repair links. Use a fresh disposable instance or explicitly repair the distro Python first." >&2
        return 1
    fi
}

select_ansible_core() {
    "$CONTROLLER_PYTHON" -c 'import sys; sys.exit(not ((3, 11) <= sys.version_info[:2] <= (3, 14)))' || {
        echo "ERROR: Ansible controller $CONTROLLER_PYTHON needs Python 3.11 through 3.14; install a compatible interpreter without replacing system Python." >&2
        return 1
    }
    if "$CONTROLLER_PYTHON" -c 'import sys; sys.exit(sys.version_info < (3, 12))'; then
        ANSIBLE_CORE_REQUIREMENT='ansible-core>=2.20,<2.21'
    else
        ANSIBLE_CORE_REQUIREMENT='ansible-core>=2.19,<2.20'
    fi
}

install_isolated_ansible() {
    select_ansible_core || return 1
    echo "#### Controller Python: $CONTROLLER_PYTHON ($ANSIBLE_CORE_REQUIREMENT)"
    "$CONTROLLER_PYTHON" -m venv "$ANSIBLE_ENV"
    "$ANSIBLE_ENV/bin/python" -m pip install "$ANSIBLE_CORE_REQUIREMENT" cryptography passlib
    "$ANSIBLE_ENV/bin/python" -c 'import ansible, cryptography, passlib'
}

prepare_safe_python() {
    case "$distro_type" in
        ubuntu)
            assert_native_ubuntu_python
            sudo apt update -y
            sudo apt install -y unzip aptitude python3 python3-dev python3-venv python3-apt curl ca-certificates
            CONTROLLER_PYTHON=/usr/bin/python3
            if ! "$CONTROLLER_PYTHON" -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
                if [[ ! -x "$PYTHON_BIN" ]]; then
                    check_deadsnakes_availability || {
                        echo "ERROR: No compatible Ansible controller available. Install Python 3.11+ alongside system Python, then rerun preparation." >&2
                        return 1
                    }
                    sudo apt install -y software-properties-common
                    sudo add-apt-repository -y ppa:deadsnakes/ppa
                    sudo apt update -y
                fi
                sudo apt install -y "$PYTHON_CMD" "$PYTHON_VENV_PKG"
                CONTROLLER_PYTHON="$PYTHON_BIN"
            fi
            install_isolated_ansible
            /usr/bin/python3 -c 'import apt, apt_pkg'
            assert_native_ubuntu_python
            ;;
        fedora)
            disable_problematic_fedora_repos
            sudo dnf install -y unzip python3 python3-pip python3-devel python3-dnf
            CONTROLLER_PYTHON=/usr/bin/python3
            install_isolated_ansible
            /usr/bin/python3 -c 'import dnf'
            ;;
        alpine)
            apk add --no-cache sudo bash lsb-release openssh tar gzip unzip zip python3 python3-dev py3-pip py3-cryptography py3-passlib ansible
            /usr/bin/python3 -c 'import cryptography, passlib'
            ;;
        *) echo "ERROR: Unsupported distro type: $distro_type" >&2; return 1 ;;
    esac
}

validate_ansible_runtime() (
    # Avoid Ansible's config warning from the world-writable Windows checkout.
    # This subshell leaves the caller's working directory unchanged.
    cd "$HOME" || return 1
    [[ -x "$ANSIBLE_PLAYBOOK" && -x "$ANSIBLE_GALAXY" ]] || {
        echo "ERROR: Missing prepared Ansible at $ANSIBLE_BIN. Rerun preparation; global Ansible is not a fallback." >&2
        return 1
    }
    "$ANSIBLE_PLAYBOOK" --version
    "$ANSIBLE_GALAXY" --version
    if [[ "$PYTHON_BOOTSTRAP_MODE" == safe ]]; then
        "$ANSIBLE_BIN/ansible" localhost -i localhost, -c local -m ansible.builtin.ping -e "ansible_python_interpreter=$MANAGED_PYTHON"
    fi
)

install_ansible_collections() (
    # Avoid Ansible's config warning from the world-writable Windows checkout.
    # This subshell leaves the caller's working directory unchanged.
    cd "$HOME" || return 1
    local controller_python="$ANSIBLE_ENV/bin/python"
    local core_minor
    if [[ "$ANSIBLE_BIN" == /usr/bin || "$PYTHON_BOOTSTRAP_MODE" == legacy ]]; then
        controller_python=python3
    fi
    if [[ "$PYTHON_BOOTSTRAP_MODE" == safe ]]; then
        core_minor=$("$controller_python" -c 'import ansible; print(ansible.__version__.split(".")[1])') || return 1
        if (( core_minor < 16 )); then
            echo "ERROR: APK Ansible must provide ansible-core 2.16 or newer. Use a supported Alpine image." >&2
            return 1
        elif (( core_minor < 18 )); then
            "$ANSIBLE_GALAXY" collection install 'community.general:>=8.0.0,<9.0.0' 'kubernetes.core:>=3.0.0,<4.0.0' 'ansible.posix:>=1.5.0,<2.0.0'
            return
        fi
    fi
    "$ANSIBLE_GALAXY" collection install community.general kubernetes.core ansible.posix
)