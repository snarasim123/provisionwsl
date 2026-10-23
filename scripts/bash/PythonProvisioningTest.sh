#!/usr/bin/env bash
set -euo pipefail

repository=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ ${1:-} == --ansible ]]; then
    sandbox=$(mktemp -d)
    trap 'rm -rf "$sandbox"' EXIT
    python3 - "$repository" <<'PYTHON'
import pathlib
import sys
import yaml

repository = pathlib.Path(sys.argv[1])
paths = list((repository / "roles/cloud/tasks").glob("gcp*.yml"))
paths.extend(repository / name for name in (
    "roles/mate-desktop/tasks/prerequisites.yml",
    "roles/dev/tasks/pyenv.yml",
    "roles/dev/tasks/python.yml",
    "vars/language_versions.yml",
))
for path in paths:
    yaml.safe_load(path.read_text())
print(f"Parsed {len(paths)} YAML files")
PYTHON
    printf '%s\n' '- hosts: localhost' '  gather_facts: false' '  tasks:' > "$sandbox/validation.yml"
    for tasks in cloud/tasks/gcp_debian.yml cloud/tasks/gcp_alpine.yml cloud/tasks/gcp_fedora.yml mate-desktop/tasks/prerequisites.yml dev/tasks/pyenv.yml; do
        printf '    - import_tasks: %s/roles/%s\n' "$repository" "$tasks" >> "$sandbox/validation.yml"
    done
    ANSIBLE_CONFIG="$repository/ansible.cfg" ansible-playbook -i localhost, --syntax-check "$sandbox/validation.yml"
    python3 - "$repository" "$sandbox" > "$sandbox/runtime.yml" <<'PYTHON'
import pathlib
import sys
import yaml

repository = pathlib.Path(sys.argv[1])
sandbox = pathlib.Path(sys.argv[2])
runtime_tasks = yaml.safe_load((repository / "roles/cloud/tasks/gcp_runtime.yml").read_text())[:2]
tasks = [
    {"name": "Select Alpine default runtime", "ansible.builtin.set_fact": {"is_alpine": True}},
    *runtime_tasks,
    {"ansible.builtin.assert": {"that": ["gcp_selected_python == '/usr/bin/python3'"]}},
    {"ansible.builtin.set_fact": {"gcp_cloudsdk_python": "/mock/selected"}},
    *runtime_tasks,
    {"ansible.builtin.assert": {"that": ["gcp_selected_python == '/mock/selected'"]}},
    {"ansible.builtin.copy": {
        "dest": str(sandbox / "gcloud"), "mode": "0755",
        "content": "#!/bin/sh\n[ \"$CLOUDSDK_PYTHON\" = /mock/selected ] || exit 99\n"
                   "[ '{{ mock_command_exit | default(0) }}' = 0 ] || exit '{{ mock_command_exit | default(0) }}'\n"
                   "if [ \"$1\" = info ]; then\n"
                   "  printf '%s\\n' '{\"basic\":{\"python_location\":\"/mock/selected\",\"python_version\":\"{{ mock_python_version | default(\"3.12.4\") }}\"}}'\n"
                   "else\n  echo 'Google Cloud SDK mock'\nfi\n",
    }},
    {"ansible.builtin.copy": {
        "dest": str(sandbox / "gke-gcloud-auth-plugin"), "mode": "0755",
        "content": "#!/bin/sh\n[ \"$CLOUDSDK_PYTHON\" = /mock/selected ] || exit 99\nexit {{ mock_plugin_exit | default(0) }}\n",
    }},
    {"ansible.builtin.import_tasks": str(repository / "roles/cloud/tasks/gcp_verify.yml")},
    {"ansible.builtin.assert": {"that": ["gcp_cli_installed | bool"]}, "when": "not ansible_check_mode"},
]
play = [{"hosts": "localhost", "connection": "local", "gather_facts": False,
         "vars": {"gcp_binary_dir": str(sandbox), "gcp_cli_python_min_version": "3.10",
                  "gcp_cli_python_max_version": "3.15"}, "tasks": tasks}]
yaml.safe_dump(play, sys.stdout, sort_keys=False)
PYTHON
    ANSIBLE_CONFIG="$repository/ansible.cfg" ansible-playbook -i localhost, "$sandbox/runtime.yml" > "$sandbox/runtime-output" 2>&1 || {
        cat "$sandbox/runtime-output"
        exit 1
    }
    for failure in 'mock_python_version=3.9.9' 'mock_python_version=3.16.0' 'mock_command_exit=127' 'mock_plugin_exit=1'; do
        if ANSIBLE_CONFIG="$repository/ansible.cfg" ansible-playbook -i localhost, "$sandbox/runtime.yml" -e "$failure" > "$sandbox/runtime-output" 2>&1; then
            echo "ERROR: Google Cloud verification accepted $failure" >&2
            exit 1
        fi
        grep -q 'no Python replacement or fallback was attempted' "$sandbox/runtime-output"
    done
    before_check=$(sha256sum "$sandbox/gcloud" "$sandbox/gke-gcloud-auth-plugin")
    ANSIBLE_CONFIG="$repository/ansible.cfg" ansible-playbook -i localhost, "$sandbox/runtime.yml" --check > "$sandbox/runtime-output" 2>&1 || {
        cat "$sandbox/runtime-output"
        exit 1
    }
    [[ "$before_check" == "$(sha256sum "$sandbox/gcloud" "$sandbox/gke-gcloud-auth-plugin")" ]]
    echo 'Google Cloud mock runtime checks passed: 6 (including check mode)'
    exit
fi
source "$repository/scripts/bash/python-bootstrap.sh"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home"
mkdir -p "$HOME" "$sandbox/checkout/scripts/bash"
cp "$repository/scripts/bash/python-bootstrap.sh" "$sandbox/checkout/scripts/bash/"
cp "$repository/scripts/bash/prep-install-"*.sh "$sandbox/checkout/scripts/bash/"
cp "$repository/csv-utils.sh" "$sandbox/checkout/"
checks=0

expect_failure() {
    if "$@" > "$sandbox/error" 2>&1; then
        echo "FAIL: Expected failure: $*" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

for PYTHON_VERSION in 3.11 3.12 3.13; do
    PYTHON_CMD="python$PYTHON_VERSION"
    select_python_distutils_package
    if [[ "$PYTHON_VERSION" == 3.11 ]]; then
        [[ "$PYTHON_DISTUTILS_PKG" == python3.11-distutils ]]
    else
        [[ -z "$PYTHON_DISTUTILS_PKG" ]]
    fi
    checks=$((checks + 1))
done
PYTHON_VERSION=malformed
expect_failure select_python_distutils_package

for value in safe legacy; do
    for ending in '' '\n' '\r\n'; do
        printf '%s%b' "$value" "$ending" > "$sandbox/checkout/python-bootstrap-mode.conf"
        read_python_bootstrap_mode "$sandbox/checkout"
        [[ "$PYTHON_BOOTSTRAP_MODE" == "$value" ]]
        record_prepared_python_mode
        require_prepared_python_mode
        checks=$((checks + 1))
    done
done

for invalid in '' 'SAFE' ' safe' 'safe ' 'safe\nlegacy' 'safe\n\n' '$(touch SHOULD_NOT_EXIST)' 'safe\r\r\n'; do
    printf '%b' "$invalid" > "$sandbox/checkout/python-bootstrap-mode.conf"
    expect_failure read_python_bootstrap_mode "$sandbox/checkout"
done
[[ ! -e SHOULD_NOT_EXIST ]]
rm "$sandbox/checkout/python-bootstrap-mode.conf"
expect_failure read_python_bootstrap_mode "$sandbox/checkout"
printf 'safe\n' > "$sandbox/checkout/python-bootstrap-mode.conf"
read_python_bootstrap_mode "$sandbox/checkout"
expect_failure require_prepared_python_mode
rm -f "$PYTHON_BOOTSTRAP_STATE"
expect_failure require_prepared_python_mode
record_prepared_python_mode
require_prepared_python_mode

for entry in prep-install.sh install.sh; do
    printf 'invalid\n' > "$sandbox/checkout/python-bootstrap-mode.conf"
    expect_failure bash "$repository/$entry" /missing-profile "$sandbox/checkout"
    grep -q 'Invalid Python bootstrap mode' "$sandbox/error"
    rm "$sandbox/checkout/python-bootstrap-mode.conf"
    expect_failure bash "$repository/$entry" /missing-profile "$sandbox/checkout"
    grep -q 'Cannot read' "$sandbox/error"
done
printf 'safe\n' > "$sandbox/checkout/python-bootstrap-mode.conf"
read_python_bootstrap_mode "$sandbox/checkout"
record_prepared_python_mode
bash -c 'source "$1/scripts/bash/python-bootstrap.sh"; read_python_bootstrap_mode "$1"; require_prepared_python_mode' bash "$sandbox/checkout"
printf 'legacy\n' > "$sandbox/checkout/python-bootstrap-mode.conf"
expect_failure bash "$repository/install.sh" /missing-profile "$sandbox/checkout"
grep -q 'differs from requested' "$sandbox/error"

printf '%s\n' 'distro_type=ubuntu' 'ps_distro_id=' \
    'configure_ansible_runtime() { :; }' \
    'prepare_safe_python() { echo safe >> "$HOME/routes"; }' \
    'upgrade() { echo legacy >> "$HOME/routes"; }' \
    'install_ansible_collections() { :; }' \
    'validate_ansible_runtime() { :; }' \
    'verify_python_ubuntu() { :; }' > "$sandbox/profile"
for value in safe legacy; do
    printf '%s\n' "$value" > "$sandbox/checkout/python-bootstrap-mode.conf"
    bash "$repository/prep-install.sh" "$sandbox/profile" "$sandbox/checkout" > "$sandbox/output" 2>&1
    [[ $(cat "$PYTHON_BOOTSTRAP_STATE") == "$value" ]]
    [[ $(tail -1 "$HOME/routes") == "$value" ]]
    checks=$((checks + 1))
done
printf 'safe\n' > "$sandbox/checkout/python-bootstrap-mode.conf"
printf '%s\n' 'prepare_safe_python() { echo failed-safe >> "$HOME/routes"; return 42; }' >> "$sandbox/profile"
expect_failure bash "$repository/prep-install.sh" "$sandbox/profile" "$sandbox/checkout"
[[ ! -e "$PYTHON_BOOTSTRAP_STATE" ]]
[[ $(tail -1 "$HOME/routes") == failed-safe ]]
grep -q 'no automatic legacy fallback was attempted' "$sandbox/error"
printf '%s\n' 'prepare_safe_python() { :; }' 'validate_ansible_runtime() { return 43; }' >> "$sandbox/profile"
expect_failure bash "$repository/prep-install.sh" "$sandbox/profile" "$sandbox/checkout"
[[ ! -e "$PYTHON_BOOTSTRAP_STATE" ]]

PYTHON_BOOTSTRAP_MODE=safe
for distro_type in ubuntu fedora alpine; do
    configure_ansible_runtime
    [[ "$MANAGED_PYTHON" == /usr/bin/python3 ]]
    [[ "$ANSIBLE_COLLECTIONS_PATH" == "$HOME/.local/share/provisionwsl/collections" ]]
    if [[ "$distro_type" == alpine ]]; then
        [[ "$ANSIBLE_PLAYBOOK" == /usr/bin/ansible-playbook ]]
    else
        [[ "$ANSIBLE_PLAYBOOK" == "$HOME/.local/share/provisionwsl/ansible/bin/ansible-playbook" ]]
        expect_failure validate_ansible_runtime
    fi
    checks=$((checks + 1))
done

PYTHON_BOOTSTRAP_MODE=legacy
ansible-playbook() { :; }
configure_ansible_runtime
[[ "$MANAGED_PYTHON" == auto_silent ]]
checks=$((checks + 1))
unset -f ansible-playbook

source "$repository/scripts/bash/prep-install-fedora.sh"
PYTHON_VERSION=3.99
PYTHON_CMD=python3.99
sudo() {
    printf '%s\n' "$*" >> "$sandbox/package-calls"
    [[ "$*" != *python3.99* ]]
}
expect_failure install_python_fedora
[[ $(grep -c python3.99 "$sandbox/package-calls") == 1 ]]
! grep -q 'Using system Python' "$sandbox/error"

source "$repository/scripts/bash/prep-install-ubuntu.sh"
PYTHON_VERSION=3.11
lsb_release() { echo jammy; }
curl() {
    printf 'Package: python3.11\n'
    printf 'Package: unrelated\n%.0s' {1..20000}
}
gunzip() { cat; }
check_deadsnakes_availability > "$sandbox/output"
checks=$((checks + 1))
curl() { printf 'Package: unrelated\n'; }
expect_failure check_deadsnakes_availability
unset -f curl gunzip lsb_release

for distro_type in ubuntu fedora alpine; do
    export distro_type
    export -f prepare_safe_python
    expect_failure bash -ec 'assert_native_ubuntu_python() { :; }; disable_problematic_fedora_repos() { :; }; sudo() { return 42; }; apk() { return 42; }; prepare_safe_python; echo UNEXPECTED_SUCCESS'
    ! grep -q UNEXPECTED_SUCCESS "$sandbox/error"
done

bash -n "$repository/prep-install.sh" "$repository/install.sh" "$repository/scripts/bash/"*.sh
echo "Python bootstrap regression checks passed: $checks"