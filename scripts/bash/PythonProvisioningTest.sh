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
cp "$repository/csv-utils.sh" "$sandbox/checkout/"
checks=0

expect_failure() {
    if "$@" > "$sandbox/error" 2>&1; then
        echo "FAIL: Expected failure: $*" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

for specification in ubuntu:16.04 ubuntu:18.04 ubuntu:20.04 ubuntu:invalid fedora:36 fedora:invalid alpine:3.18.0 alpine:3.19.9 alpine:invalid; do
    distro_type=${specification%%:*}
    version=${specification#*:}
    expect_failure assert_supported_python_distro <(printf 'ID=%s\nVERSION_ID=%s\n' "$distro_type" "$version")
done
for specification in ubuntu:22.04 ubuntu:24.04 ubuntu:26.04 fedora:37 fedora:42 fedora:43 fedora:44 alpine:3.20.0 alpine:3.20.9 alpine:3.21.9 alpine:3.22.7 alpine:3.23.7 alpine:3.24.3; do
    distro_type=${specification%%:*}
    version=${specification#*:}
    assert_supported_python_distro <(printf 'ID=%s\nVERSION_ID=%s\n' "$distro_type" "$version") 2> "$sandbox/release-warning"
    if [[ "$specification" == fedora:37 ]]; then
        grep -q 'WARNING: Fedora 37 is end-of-life' "$sandbox/release-warning"
    fi
    checks=$((checks + 1))
done
for version in 37 44; do
    distro_type=fedora
    assert_supported_python_distro <(printf 'ID=fedoraremixforwsl\nID_LIKE=fedora\nVERSION_ID=%s\n' "$version") 2> "$sandbox/release-warning"
    if [[ "$version" == 37 ]]; then
        grep -q 'WARNING: Fedora 37 is end-of-life' "$sandbox/release-warning"
    fi
    checks=$((checks + 1))
done
for version in 36 invalid; do
    expect_failure assert_supported_python_distro <(printf 'ID=fedoraremixforwsl\nID_LIKE=fedora\nVERSION_ID=%s\n' "$version")
    grep -q "ERROR: Fedora $version is unsupported." "$sandbox/error"
done
for distro_type in ubuntu alpine; do
    expect_failure assert_supported_python_distro <(printf 'ID=fedoraremixforwsl\nID_LIKE=fedora\nVERSION_ID=37\n')
done
distro_type=fedora
expect_failure assert_supported_python_distro <(printf 'ID=unrecognized\nID_LIKE=fedora\nVERSION_ID=44\n')
distro_type=ubuntu
expect_failure assert_supported_python_distro <(printf 'ID=fedora\nVERSION_ID=43\n')
expect_failure assert_supported_python_distro /nonexistent-os-release

printf '%s\n' 'distro_type=ubuntu' 'ps_distro_id=' \
    'assert_supported_python_distro() { return 42; }' \
    'configure_ansible_runtime() { touch "$HOME/unexpected-mutation"; }' > "$sandbox/profile"
for entry in prep-install.sh install.sh; do
    expect_failure bash "$repository/$entry" "$sandbox/profile" "$sandbox/checkout"
    [[ ! -e "$HOME/unexpected-mutation" ]]
done
printf '%s\n' 'distro_type=ubuntu' 'ps_distro_id=' \
    'assert_supported_python_distro() { :; }' \
    'configure_ansible_runtime() { :; }' \
    'prepare_python() { echo prepare >> "$HOME/routes"; }' \
    'install_ansible_collections() { echo collections >> "$HOME/routes"; }' \
    'validate_ansible_runtime() { echo validate >> "$HOME/routes"; }' > "$sandbox/profile"
bash "$repository/prep-install.sh" "$sandbox/profile" "$sandbox/checkout" > "$sandbox/output" 2>&1
[[ $(cat "$HOME/routes") == $'prepare\ncollections\nvalidate' ]]
checks=$((checks + 1))
rm "$HOME/routes"
printf '%s\n' 'prepare_python() { echo failed-prepare >> "$HOME/routes"; return 42; }' >> "$sandbox/profile"
expect_failure bash "$repository/prep-install.sh" "$sandbox/profile" "$sandbox/checkout"
[[ $(cat "$HOME/routes") == failed-prepare ]]
grep -q 'system Python will not be replaced' "$sandbox/error"
rm "$HOME/routes"
printf '%s\n' 'prepare_python() { :; }' 'install_ansible_collections() { return 43; }' >> "$sandbox/profile"
expect_failure bash "$repository/prep-install.sh" "$sandbox/profile" "$sandbox/checkout"
[[ ! -e "$HOME/routes" ]]

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

CONTROLLER_PYTHON_VERSION=3.11
printf 'ID=ubuntu\nVERSION_CODENAME=jammy\n' > "$sandbox/os-release"
curl() {
    printf 'Package: python3.11\n'
    printf 'Package: unrelated\n%.0s' {1..20000}
}
gunzip() { cat; }
check_deadsnakes_availability "$sandbox/os-release" > "$sandbox/output"
checks=$((checks + 1))
curl() { printf 'Package: unrelated\n'; }
expect_failure check_deadsnakes_availability "$sandbox/os-release"
unset -f curl gunzip

for distro_type in ubuntu fedora alpine; do
    export distro_type CONTROLLER_PYTHON_VERSION
    export -f prepare_python
    expect_failure bash -ec 'assert_native_ubuntu_python() { :; }; disable_problematic_fedora_repos() { :; }; sudo() { return 42; }; apk() { return 42; }; prepare_python; echo UNEXPECTED_SUCCESS'
    ! grep -q UNEXPECTED_SUCCESS "$sandbox/error"
done

distro_type=ubuntu
configure_ansible_runtime
mkdir -p "$ANSIBLE_BIN"
for executable in ansible-playbook ansible-galaxy ansible; do
    printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$PWD" >> "$HOME/ansible-directories"' \
        'if [[ "${0##*/}" == ansible-galaxy && "${1:-}" == collection ]]; then printf "%s\n" "$@" >> "$HOME/galaxy-arguments"; fi' > "$ANSIBLE_BIN/$executable"
    chmod +x "$ANSIBLE_BIN/$executable"
done
printf '%s\n' '#!/usr/bin/env bash' 'echo "${MOCK_CORE_MINOR:-20}"' > "$ANSIBLE_BIN/python"
chmod +x "$ANSIBLE_BIN/python"
original_directory=$PWD
validate_ansible_runtime
install_ansible_collections
[[ "$PWD" == "$original_directory" ]]
[[ $(wc -l < "$HOME/ansible-directories") == 4 ]]
[[ $(sort -u "$HOME/ansible-directories") == "$HOME" ]]
[[ $(cat "$HOME/galaxy-arguments") == $'collection\ninstall\ncommunity.general\nkubernetes.core\nansible.posix' ]]
checks=$((checks + 1))
for MOCK_CORE_MINOR in 17 18; do
    export MOCK_CORE_MINOR
    rm "$HOME/galaxy-arguments"
    install_ansible_collections
    if (( MOCK_CORE_MINOR == 17 )); then
        [[ $(cat "$HOME/galaxy-arguments") == $'collection\ninstall\ncommunity.general:>=8.0.0,<9.0.0\nkubernetes.core:>=3.0.0,<4.0.0\nansible.posix:>=1.5.0,<2.0.0' ]]
    else
        [[ $(cat "$HOME/galaxy-arguments") == $'collection\ninstall\ncommunity.general\nkubernetes.core\nansible.posix' ]]
    fi
    checks=$((checks + 1))
done
export MOCK_CORE_MINOR=16
expect_failure install_ansible_collections
[[ $(wc -l < "$HOME/ansible-directories") == 6 ]]
[[ "$PWD" == "$original_directory" ]]

for script in "$repository/prep-install.sh" "$repository/install.sh" "$repository/scripts/bash/"*.sh; do
    bash -n "$script"
done
echo "Python bootstrap regression checks passed: $checks"