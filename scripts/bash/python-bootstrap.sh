#!/usr/bin/env bash

assert_supported_python_distro() {
    local release_file="${1:-/etc/os-release}"
    local ID VERSION_ID installed_distro
    source "$release_file" || return 1
    installed_distro="$ID"
    case "$installed_distro" in
        fedoraremixforwsl) installed_distro=fedora ;;
    esac
    if [[ "$installed_distro" != "$distro_type" ]]; then
        echo "ERROR: Profile distro '$distro_type' does not match installed distro '$ID'." >&2
        return 1
    fi
    case "$installed_distro" in
        ubuntu)
            if [[ ! "$VERSION_ID" =~ ^([0-9]+)[.]([0-9]+)$ ]] ||
                (( 10#${BASH_REMATCH[1]} < 22 || (10#${BASH_REMATCH[1]} == 22 && 10#${BASH_REMATCH[2]} < 4) )); then
                echo "ERROR: Ubuntu $VERSION_ID is unsupported. Use Ubuntu 22.04 or newer." >&2
                return 1
            fi
            ;;
        fedora)
            if [[ ! "$VERSION_ID" =~ ^[0-9]+$ ]] || (( 10#$VERSION_ID < 37 )); then
                echo "ERROR: Fedora $VERSION_ID is unsupported. Use Fedora 37 or newer." >&2
                return 1
            fi
            if (( 10#$VERSION_ID == 37 )); then
                echo "WARNING: Fedora 37 is end-of-life and receives no security updates; package repositories may be unavailable." >&2
            fi
            ;;
        alpine)
            if [[ ! "$VERSION_ID" =~ ^([0-9]+)[.]([0-9]+)([.][0-9]+)?$ ]] ||
                (( 10#${BASH_REMATCH[1]} < 3 || (10#${BASH_REMATCH[1]} == 3 && 10#${BASH_REMATCH[2]} < 20) )); then
                echo "ERROR: Alpine $VERSION_ID is unsupported. Use Alpine 3.20 or newer." >&2
                return 1
            fi
            ;;
        *)
            echo "ERROR: Unsupported distro: $ID. Use Ubuntu, Fedora, or Alpine." >&2
            return 1
            ;;
    esac
}

configure_ansible_runtime() {
    MANAGED_PYTHON=/usr/bin/python3
    ANSIBLE_ENV="$HOME/.local/share/provisionwsl/ansible"
    export ANSIBLE_COLLECTIONS_PATH="$HOME/.local/share/provisionwsl/collections"
    export ANSIBLE_COLLECTIONS_SCAN_SYS_PATH=false
    if [[ "$distro_type" == alpine ]]; then
        ANSIBLE_BIN=/usr/bin
    else
        ANSIBLE_BIN="$ANSIBLE_ENV/bin"
    fi
    export ANSIBLE_PYTHON_INTERPRETER="$MANAGED_PYTHON"
    export PATH="$ANSIBLE_BIN:$PATH"
    ANSIBLE_PLAYBOOK="$ANSIBLE_BIN/ansible-playbook"
    ANSIBLE_GALAXY="$ANSIBLE_BIN/ansible-galaxy"
    echo "#### Ansible executable: $ANSIBLE_PLAYBOOK; managed-host Python: $MANAGED_PYTHON"
}

assert_native_ubuntu_python() {
    local native_version
    native_version=$(awk -F ' *= *' '$1 == "default-version" {print $2}' /usr/share/python3/debian_defaults) || return 1
    if [[ -z "$native_version" || "$(readlink /usr/bin/python3)" != "$native_version" ]]; then
        echo "ERROR: Ubuntu system Python was replaced or cannot be identified. Bootstrap does not repair links. Use a fresh disposable instance or explicitly repair the distro Python first." >&2
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

check_deadsnakes_availability() {
    local ID VERSION_CODENAME
    source "${1:-/etc/os-release}" || return 1
    if [[ "$ID" != ubuntu || -z "$VERSION_CODENAME" ]]; then
        echo "ERROR: Cannot determine the Ubuntu codename for controller Python installation." >&2
        return 1
    fi
    local ppa_url="https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu/dists/${VERSION_CODENAME}/main/binary-amd64/Packages.gz"
    if ! curl -fsS "$ppa_url" | gunzip | grep "^Package: python${CONTROLLER_PYTHON_VERSION}$" >/dev/null; then
        echo "ERROR: Controller Python $CONTROLLER_PYTHON_VERSION is unavailable for Ubuntu $VERSION_CODENAME. Install a compatible interpreter alongside system Python before rerunning preparation." >&2
        return 1
    fi
}

disable_problematic_fedora_repos() {
    local wslu_copr_repo="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:wslutilities:wslu.repo"
    if [[ -f "$wslu_copr_repo" ]]; then
        echo "Disabling broken Fedora COPR repo: $wslu_copr_repo"
        sudo sed -i 's/^enabled=.*/enabled=0/' "$wslu_copr_repo"
    fi
}

prepare_python() {
    local controller_command="python${CONTROLLER_PYTHON_VERSION}"
    local controller_binary="/usr/bin/$controller_command"
    case "$distro_type" in
        ubuntu)
            assert_native_ubuntu_python
            sudo apt update -y
            sudo apt install -y unzip aptitude python3 python3-dev python3-venv python3-apt curl ca-certificates
            CONTROLLER_PYTHON=/usr/bin/python3
            if ! "$CONTROLLER_PYTHON" -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
                if [[ ! -x "$controller_binary" ]]; then
                    check_deadsnakes_availability || return 1
                    sudo apt install -y software-properties-common
                    sudo add-apt-repository -y ppa:deadsnakes/ppa
                    sudo apt update -y
                fi
                sudo apt install -y "$controller_command" "${controller_command}-venv"
                CONTROLLER_PYTHON="$controller_binary"
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
    "$ANSIBLE_BIN/ansible" localhost -i localhost, -c local -m ansible.builtin.ping -e "ansible_python_interpreter=$MANAGED_PYTHON"
)

install_ansible_collections() (
    # Avoid Ansible's config warning from the world-writable Windows checkout.
    # This subshell leaves the caller's working directory unchanged.
    cd "$HOME" || return 1
    local controller_python="$ANSIBLE_ENV/bin/python"
    local core_minor
    if [[ "$distro_type" == alpine ]]; then
        controller_python=/usr/bin/python3
    fi
    core_minor=$("$controller_python" -c 'import ansible; print(ansible.__version__.split(".")[1])') || return 1
    if (( core_minor < 17 )); then
        echo "ERROR: Ansible core 2.17 or newer is required. Install the distro's supported Ansible package or rerun preparation." >&2
        return 1
    elif (( core_minor == 17 )); then
        echo "#### Ansible core 2.17: using compatible collection ranges."
        "$ANSIBLE_GALAXY" collection install 'community.general:>=8.0.0,<9.0.0' 'kubernetes.core:>=3.0.0,<4.0.0' 'ansible.posix:>=1.5.0,<2.0.0'
        return
    fi
    "$ANSIBLE_GALAXY" collection install community.general kubernetes.core ansible.posix
)