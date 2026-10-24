---
name: python-provisioning-compatibility
description: Maintain provisionwsl Python compatibility. Use when asked to preserve distro system Python, isolate Ansible, clean up Python bootstrap, or harden Alpine Python and Google Cloud CLI setup.
---

# Python provisioning compatibility

## Purpose and scope

Maintain the system-Python-preserving implementation. On 2026-10-23 the user
explicitly authorized removing the old Python replacement path and retaining
only newer distributions. The temporary rollout gate has been superseded;
do not reintroduce mode flags, prepared-mode state, or Python replacement code.
Reinspect current files and working changes before acting. This skill does not
authorize recreating existing WSL distributions or claim full integration passed.

Keep system Python, Ansible's execution environment, and user development Python
separate. Preserve support for Ubuntu, Fedora, and Alpine without imposing one
Python minor version on every distribution.

## Current contract

- Require Ubuntu 22.04+, Fedora 37+, or Alpine 3.20+ before package operations.
  The installed distro must match the profile. Leave historical profiles and
  existing instances alone; obsolete image registry entries are removed.
- The user successfully provisioned Fedora 37 with the preserving path and
  explicitly requested continued compatibility. Warn about Fedora 37 EOL rather
  than rejecting it; runtime checks still apply. Do not impose a maintained-release
  minimum as a substitute for actual compatibility requirements.
- The user explicitly requested restoring Alpine 3.20 and will test provisioning.
  Keep its registry entry and APK-managed Python/Ansible; do not claim full
  integration passed or restore system-pip overrides to support it.
- Keep `/usr/bin/python3` distro-owned. Never redirect Python/pip, bypass PEP 668,
  remove system Python, or rebuild python-apt for a replacement interpreter.
- Use root's `~/.local/share/provisionwsl/ansible` venv on Ubuntu/Fedora, and APK
  Ansible on Alpine. Set explicit playbook/galaxy executables, isolated collection
  paths, and `/usr/bin/python3` for managed-host execution in both entry points.
- Ubuntu 22.04 can install controller Python 3.11 alongside native Python 3.10;
  fail if that controller is unavailable. Native controller Python 3.11 uses
  core 2.19; Python 3.12-3.14 uses core 2.20. Review core 2.19 before its November
  2026 upstream EOL. Collection installation requires core 2.17+. Core 2.17 uses
  community.general >=8,<9, kubernetes.core >=3,<4, and ansible.posix >=1.5,<2;
  core 2.18+ keeps the normal collection selection.
- Never fall back to global Ansible or silently repair a previously replaced
  system interpreter. MATE must not configure a Python alternative.
- Keep regression checks in the normal `test.ps1` suite. Its Bash helper uses
  temporary fixtures and mocked package failures; `--ansible` adds explicit task
  imports and mock Google Cloud runtime/check-mode checks with installed tooling.
- Report full disposable-image provisioning and repeat-run validation separately
  from mock and syntax checks. Newer Fedora `.wsl` imports remain a separate task.

## Discussion and existing fix

On 2026-10-22, `kickoff.ps1` provisioning `aa-ubu2204` failed in MATE
prerequisites with:

```text
Specified path /usr/bin/python3.12 does not exist
```

The failed task assumed Ubuntu 24.04's Python 3.12 on Ubuntu 22.04, whose native
Python is 3.10. Bootstrap separately installed Python 3.11 for Ansible.
Ansible returned exit code 2, which PowerShell correctly reported.

[MATE prerequisites](../../../roles/mate-desktop/tasks/prerequisites.yml) were
initially changed to read `default-version` from
`/usr/share/python3/debian_defaults` and select that Python alternative.
[Troubleshooting documentation](../../../docs/Readme.md) was updated.
Targeted Ansible syntax checks and check-mode runs passed on Ubuntu 22.04 and
24.04. A complete provisioning rerun was not performed.

The final implementation stops replacing system Python and removes the MATE
alternative-setting tasks entirely. The old correction is historical context,
not an instruction to restore alternatives.

Earlier GitHub SSH host-key errors during Vim plugin installation were ignored
and were not the fatal blocker. They are outside this skill's scope.

## Historical Review Findings

The following describes the original defects and the rationale for the current
contract. References point to the retained owners, not deleted helper files.

### 1. Ubuntu bootstrap replaces package-managed system Python

Relevant files:
- [Bootstrap entry point](../../../prep-install.sh)
- [Shared bootstrap](../../../scripts/bash/python-bootstrap.sh)
- [Ansible launch and repository copy](../../../install.sh)
- [PowerShell entry point](../../../kickoff.ps1)
- [Inventory](../../../hosts)
- [Ansible configuration](../../../ansible.cfg)
- [MATE prerequisites](../../../roles/mate-desktop/tasks/prerequisites.yml)
- [Python GUI dependencies](../../../roles/dev/tasks/python.yml)

At review time, bootstrap pins `PYTHON_VERSION="3.11"`, removes preinstalled
Python packages, redirects `/usr/bin/python3` with `update-alternatives`, and
redirects pip commands. It builds `python-apt` for the replacement interpreter,
but that does not make other distro Python extensions compatible. A probe on
Ubuntu 24.04 found that Python 3.11 could not load the installed Qt bindings.
Treat live distro state as transient, not as a stable test fixture.

Implementation direction:
- Do not remove or redirect the distro's system Python or overwrite its pip.
- Install Ansible in a dedicated virtual environment using an available,
  compatible interpreter.
- Explicitly wire the Ansible executable, `ansible-galaxy`, collection locations,
  and launch environment through bootstrap and `install.sh`; merely creating a
  virtual environment is incomplete.
- Distinguish the controller interpreter from the managed-host interpreter.
  A local connection does not remove that distinction. Ensure apt operations use
  an interpreter with the appropriate distro bindings, and verify compatibility
  with the chosen Ansible version.
- Reassess whether building `python-apt` for a custom interpreter is still needed.
- Remove the MATE role's normal need to switch Python back. If existing modified
  instances need repair, make that behavior explicit rather than silently
  changing interpreter links during desktop installation.
- Preserve PEP 668 protections instead of bypassing them for system pip.

### 2. Fedora fallback is not implemented

Relevant files:
- [Shared bootstrap](../../../scripts/bash/python-bootstrap.sh)
- [Bootstrap caller](../../../prep-install.sh)

The attempted alternative package names are identical to the initial names.
When installation fails, the function reports "Using system Python" and returns
1 without selecting another interpreter. Its caller proceeds with the original
`PYTHON_CMD`, potentially invoking nonexistent `python3.11`.

This control flow was reproduced with mocked package-manager calls, without
installing or removing packages.

Implementation direction:
- Select and validate an actual available interpreter on fallback, or fail
  explicitly if the required interpreter cannot be provided.
- Propagate installation failures; do not continue with an unusable command.
- Keep system Python and DNF's bindings intact.
- If using an isolated Ansible environment on Fedora, verify DNF module execution
  against the distro interpreter rather than assuming the controller's custom
  Python can import DNF.
- Avoid a retry that repeats the same package request.

### 3. Ubuntu versioned distutils dependency fails for newer Python

Relevant files:
- [Version-derived package configuration](../../../prep-install.sh)
- [Ubuntu package installation](../../../scripts/bash/python-bootstrap.sh)

`PYTHON_DISTUTILS_PKG="${PYTHON_CMD}-distutils"` is always included in the apt
installation command. Python 3.12 removed standard-library distutils, so the
documented option to choose 3.12 or 3.13 can request a nonexistent package and
fail the entire installation transaction.

Implementation direction:
- Make package selection version-aware.
- Do not require versioned distutils packages for Python 3.12+.
- Verify actual interpreter, venv, and packaging prerequisites before installing
  Ansible. Do not assume changing one version variable guarantees support.

### 4. Google Cloud checks system Python instead of its selected runtime

Relevant files:
- [Ubuntu Google Cloud tasks](../../../roles/cloud/tasks/gcp_debian.yml)
- [Alpine Google Cloud tasks](../../../roles/cloud/tasks/gcp_alpine.yml)
- [Fedora Google Cloud tasks](../../../roles/cloud/tasks/gcp_fedora.yml)
- [Configured version bounds](../../../vars/language_versions.yml)

The roles check `python3 --version` against fixed configured bounds before
installation. Ubuntu and Alpine download an archive that may include a bundled
interpreter; the precheck can reject a system Python that the CLI would not use.
Do not blindly remove validation or assume bundled interpreters always work.

Implementation direction:
- Validate the interpreter actually selected by the CLI.
- Respect an explicit `CLOUDSDK_PYTHON` selection where applicable.
- Verify current CLI requirements when implementing; the saved bounds of 3.9
  through 3.14 are configuration from the review, not a permanent compatibility
  guarantee.
- Verify `gcloud --version` and GKE authentication plugin execution as relevant.
- Surface installation/runtime failures rather than suppressing them and
  reporting successful installation.

### 5. Existing Python tests can pass on headings alone

Relevant file:
- [PowerShell validation harness](../../../test.ps1)

`Test-PythonVersion` matches output against `"Python"` and `Test-PyenvSetup`
against `"pyenv"`. PowerShell matching is case-insensitive, and the printed
headings already contain these strings. Missing commands and failed setup can
therefore produce false positives.

Implementation direction:
- Check exit codes and expected executable behavior.
- Validate system Python separately from Ansible and pyenv.
- Check configured pyenv versions and the selected global version.
- Add negative cases proving missing commands and heading-only output fail.

## Alpine-specific design

Relevant files:
- [Shared bootstrap](../../../scripts/bash/python-bootstrap.sh)
- [Bootstrap distro branches](../../../prep-install.sh)
- [Alpine Google Cloud tasks](../../../roles/cloud/tasks/gcp_alpine.yml)

Alpine already obtains Python and Ansible through APK. Preserve that approach:
- Keep `python3`, `python3-dev`, `py3-pip`, `py3-cryptography`, `py3-passlib`, and
  `ansible` APK-managed as needed.
- Do not redirect system Python to the Ubuntu/Fedora bootstrap version.
- Do not introduce Ubuntu distutils packages or alternatives logic.
- Remove system-wide pip self-upgrades and pip overrides of APK-managed
  cryptography/passlib. Use a project venv or pyenv for development packages.
- A separate Ansible venv is not required just to match the Ubuntu strategy;
  validate the APK-provided Ansible and its required collections.
- Alpine uses musl. A bundled Linux Google Cloud interpreter may require glibc;
  the presence of the archive or `libc6-compat` alone does not prove it works.
- Prefer explicitly selecting `/usr/bin/python3` through `CLOUDSDK_PYTHON` on
  Alpine, validating that runtime against the CLI's actual requirements.
  Persist the selection wherever install commands, verification, GKE plugins,
  and user sessions need it.
- If the CLI cannot run on a supported Alpine image, report the incompatibility
  clearly; do not replace Alpine's system Python as a workaround.

## Intentional pins to preserve

[Language versions](../../../vars/language_versions.yml) intentionally configures
pyenv Python 3.11.9 and 3.12.4, with 3.12.4 global.
[Pyenv tasks](../../../roles/dev/tasks/pyenv.yml) install those versions before
selecting them. These development-version pins are not the same defect as
assuming a distro binary already exists.

Do not upgrade those pins incidentally. Ensure the configured global version is
among installed versions, and keep development configuration separate from the
Ansible controller and system runtimes.

## Execution workflow

1. Read current working changes and the relevant files above. Integrate existing
   changes without reverting unrelated work.
2. Confirm distro/profile support from the current profiles and
   [image registry](../../../data/urls.csv). Do not claim an untested image works.
3. Implement the smallest coherent bootstrap/runtime separation across all
   callers, followed by distro-specific fixes and stronger tests.
4. Add focused regression coverage using existing tooling. Mock package-manager
   commands for failure paths rather than running destructive operations on the
   user's existing WSL instances.
5. Update the relevant sections of [Readme.md](../../../docs/Readme.md) to explain
   interpreter ownership, Ansible invocation, and recovery.
6. Run targeted validation, then approved disposable-distro integration checks.
   Report exactly what passed and what remains unverified.

## Acceptance checklist

- [ ] Only the system-Python-preserving path remains, without mode plumbing.
- [ ] Older releases fail before package operations; profile and distro match.
- [ ] Required executables and local managed-host ping validate successfully.
- [ ] Failures stop without global-Ansible or Python-replacement fallback.

- [ ] Ubuntu 22.04 and 24.04 keep their native system Python and distro modules.
- [ ] Configured custom Python does not redirect system Python or pip.
- [ ] Ansible and ansible-galaxy use the intended runtime and collection paths.
- [ ] Ubuntu apt and Fedora DNF module execution work with distro bindings.
- [ ] Fedora missing-version behavior selects a working fallback or fails clearly.
- [ ] Python 3.12+ configuration does not request obsolete distutils packages.
- [ ] Alpine keeps Python and Ansible APK-managed without system pip overrides.
- [ ] Google Cloud validation checks its actual runtime, including Alpine musl.
- [ ] Applicable GKE plugin commands inherit the required interpreter selection.
- [ ] Pyenv installs and selects the configured development versions.
- [ ] Tests reject heading-only output, missing interpreters, and failed commands.
- [ ] Shell syntax and Ansible syntax/check-mode validation pass where applicable.
- [ ] Repeated provisioning of a test instance is idempotent where intended.
- [ ] Full integration results are distinguished from dry-runs and mocks.

## Operational safeguards

- `kickoff.ps1` refuses to overwrite an existing distro. Do not unregister or
  recreate a user's distro without explicit approval.
- Do not rerun bootstrap removal/upgrade commands on existing instances merely
  to validate this skill.
- For recovery, the Linux provisioning checkout is normally
  `/root/code/provisionwsl`; verify the actual location and copy updated files
  before rerunning Ansible there.
- Do not read, embed, or commit secrets. Avoid unrelated GitHub SSH remediation,
  broad dependency upgrades, or changes to user development-version choices.
