---
name: python-provisioning-compatibility
description: Resume the provisionwsl Python compatibility fixes discussed on 2026-10-22. Use when asked to implement the Python provisioning review, preserve distro system Python, isolate Ansible, fix Fedora Python fallback, or harden Alpine Python and Google Cloud CLI setup.
---

# Python provisioning compatibility

## Purpose and scope

Implement the deferred Python compatibility improvements for this repository.
This skill records a review and proposed approach, not completed implementation
or authorization to recreate existing WSL distributions. Reinspect current files
and working changes before acting; the repository may have evolved.

Keep system Python, Ansible's execution environment, and user development Python
separate. Preserve support for Ubuntu, Fedora, and Alpine without imposing one
Python minor version on every distribution.

## Temporary rollout flag (requested 2026-10-22)

Keep both the new safe path and the existing distro-specific bootstrap path
until testing is completed. This section qualifies the implementation directions
below: preservation requirements apply to the default safe path; the legacy path
temporarily retains the existing behavior for explicit comparison and recovery.
The mode file is a proposed interface, not implemented functionality. It replaces
the earlier PowerShell-switch proposal at the user's request: keep mode selection
in Bash and do not modify PowerShell scripts to add or propagate this setting.

- Add one repository-root file named `python-bootstrap-mode.conf` containing
  exactly `safe` by default. To opt into the existing behavior, the user changes
  that value to `legacy` before starting a run. The setting persists until edited
  again and applies to every profile using that checkout; it is not per-run.
- Read this file from both `prep-install.sh` and `install.sh`, resolving its
  location from the explicit repository/script-root argument already supplied by
  kickoff. Do not depend on the current directory or a stale Linux checkout copy.
  Pass the validated mode onward to affected Ansible tasks from Bash.
- Use a small shared Bash reader/validator rather than duplicate parsing. Treat
  the file as data, not executable shell: do not source or eval its contents.
  Accept a final newline and Windows CRLF; require a single value of `safe` or
  `legacy`. Missing, unreadable, empty, or malformed configuration must fail
  explicitly before mutations, not silently select a path.
- Capture the successfully prepared mode in a minimal per-instance state file.
  Before Ansible execution, installation must compare the requested mode with
  that record and reject missing or mismatched state with an actionable error.
  Do not let editing the shared configuration midway through a run select a
  different install path. Record success only after bootstrap validation passes.
  Reuse existing state mechanisms if suitable; avoid a general configuration
  framework. Do not rely on environment changes surviving WSL invocations.
- Use one internal mode, `safe` or `legacy`, throughout the run. Reject invalid
  values before making changes. Log the mode and selected controller/managed-host
  interpreters prominently so test results identify which path ran.
- Safe mode preserves system Python, isolates Ansible where appropriate, keeps
  Alpine APK-managed, and implements the compatibility fixes described below.
- Legacy mode retains the current distro-specific logic, not a new universal
  Python-replacement algorithm. Ubuntu may replace Python/pip links; Fedora keeps
  its existing custom-interpreter approach; Alpine keeps its existing APK setup
  and system pip overrides. Warn explicitly about these legacy risks.
- Preserve the already-completed MATE missing-path correction in legacy mode;
  do not restore the hard-coded Python 3.12 failure. Gate the MATE alternative
  mutation out of safe mode, except for a separately explicit repair operation.
- Keep routing coherent across bootstrap, normal/check-mode Ansible launches,
  ansible-galaxy, collection paths, interpreter choices, and mode-dependent roles.
  Existing global Ansible executables must not silently mask safe-mode failure.
- On safe-mode failure, stop with a nonzero exit code and actionable diagnostics.
  Never automatically invoke legacy mode. The user can explicitly select the
  legacy setting for a subsequent run after inspecting the error.
- Selecting legacy mode is not transactional rollback: it cannot undo partial
  provisioning. Likewise, safe mode must not claim to repair a distro whose
  system Python was previously replaced. Detect and report that state or require
  an explicit repair; compare paths using approved disposable instances.
- Because kickoff refuses an existing distro, document how to select a new test
  profile/distro or deliberately rerun the appropriate stages in an existing
  instance. Never automatically unregister a distro to retry in legacy mode.
- Keep the temporary branching localized and reuse genuinely shared operations.
  Do not duplicate entire playbooks or maintain unrelated fixes in two copies.

Intended usage after implementation:

The repository-root `python-bootstrap-mode.conf` contains:

```text
safe
```

For an explicit legacy retry, edit its sole value to:

```text
legacy
```

The PowerShell invocation is unchanged in either case:

```powershell
.\kickoff.ps1 .\profiles\<profile-name>
```

Set the file back to `safe` for subsequent safe-mode tests. Do not edit it during
an active run or concurrent runs sharing the checkout. Re-running preparation is
required before installation can use a different mode; changing the config file
alone must not bypass the prepared-mode check.

### Testing and removal gate

Test the shipped safe default and explicit legacy selection, invalid/missing
configuration, CRLF handling, prepared-mode mismatches, mode propagation across
WSL processes, and failures that must not trigger an
automatic fallback. Exercise both branches on Ubuntu 22.04/24.04, Fedora, and
Alpine using approved test instances. Distinguish known legacy failures from new
regressions; preserving legacy is not a guarantee that existing bugs work.

Keep the legacy branch until safe-mode validation passes for the agreed distro
matrix, runtime checks and repeat-run behavior pass, and the user confirms the
testing phase is complete. Then remove the mode configuration file, reader,
temporary prepared-mode record, internal mode plumbing,
legacy-only functions and mutations, transitional tests, and temporary usage
documentation. Retain regression tests and the safe implementation. Do not
leave the mode setting as permanent configurability after successful rollout.

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
already changed to read `default-version` from
`/usr/share/python3/debian_defaults` and select that Python alternative.
[Troubleshooting documentation](../../../docs/Readme.md) was updated.
Targeted Ansible syntax checks and check-mode runs passed on Ubuntu 22.04 and
24.04. A complete provisioning rerun was not performed.

That correction fixes the immediate failure, but the preferred long-term design
is to stop replacing system Python during bootstrap. Reassess the MATE
alternative-setting task once that change is implemented.

Earlier GitHub SSH host-key errors during Vim plugin installation were ignored
and were not the fatal blocker. They are outside this skill's scope.

## Findings to address

### 1. Ubuntu bootstrap replaces package-managed system Python

Relevant files:
- [Bootstrap entry point](../../../prep-install.sh)
- [Ubuntu bootstrap](../../../scripts/bash/prep-install-ubuntu.sh)
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
- [Fedora bootstrap](../../../scripts/bash/prep-install-fedora.sh)
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
- [Ubuntu package installation](../../../scripts/bash/prep-install-ubuntu.sh)

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
- [Alpine bootstrap](../../../scripts/bash/prep-install-alpine.sh)
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

- [ ] The shipped mode file selects safe; legacy requires an explicit file edit.
- [ ] PowerShell scripts need no changes for mode selection or propagation.
- [ ] Bash validates mode data, including CRLF, without source/eval.
- [ ] Missing/invalid config or absent/mismatched prepared state fails explicitly.
- [ ] Both paths remain available until the testing/removal gate is satisfied.
- [ ] Mode selection reaches every relevant stage without implicit WSL state.
- [ ] Safe-mode failures stop and never automatically invoke legacy behavior.
- [ ] Legacy risks, partial-run state, and existing-distro retry limits are clear.
- [ ] Both paths are tested; legacy code is removed after successful sign-off.

The following preservation checks apply to the safe path during rollout and
to the sole remaining implementation after legacy cleanup:

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
