# WSL Distro Provisioning with Ansible

This project automates the creation and provisioning of WSL (Windows Subsystem for Linux) instances using Ansible. It supports **Ubuntu**, **Fedora**, and **Alpine** Linux distributions.

The project was created to address my need to provision WSL instances for different tasks over several years. For example, I needed a WSL instance to test Redis-related tasks, later a specific Java version, and then Python environments. While Docker is an option, I found writing and maintaining Dockerfiles tedious. There are prebuilt alternatives like devcontainers, but I found scripting and Ansible easier to work with.  



## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [GitHub Integration & Secrets Setup](#github-integration--secrets-setup)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Profile Configuration](#profile-configuration)
- [User Configuration](#user-configuration)
- [Available Roles](#available-roles)
- [Available Cloud Images](#available-cloud-images)
- [Examples](#examples)
- [Testing](#testing)
- [Teardown](#teardown)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)

---

## Overview

The project provides:
- Automated WSL instance provisioning (using cloud images or preexisting WSL-compatible local images)
- Ansible-based configuration
- File-driven configuration management for different types of instances
- Support for Ubuntu, Fedora, and Alpine distributions

## Prerequisites

- Windows 10/11 with WSL2 enabled
- PowerShell 5.1 or later

## GitHub Integration & Secrets Setup

Some roles (such as Vim plugin installation) require GitHub SSH access for passwordless authentication from your WSL instance. You can either skip GitHub integration or set up secrets for access. Without GitHub integration, GitHub access requires manual generation/upload of SSH keys or password authentication.

### Option 1: Skip GitHub Integration

If you do not want to set up GitHub SSH keys or secrets, you can skip all GitHub-dependent steps by adding `github` to the `skipsteps` variable in your profile file:

```bash
export skipsteps=github
```

When this tag is skipped, the playbook will:
- Avoid tasks that require GitHub SSH access (e.g., installing Vim plugins that clone from private repos)
- Use a minimal `.vimrc_noplug` configuration for Vim without plugins
- Skip SSH key setup (no automatic login to GitHub from WSL instance; any task requiring GitHub integration will not work)
 
### Option 2: Set Up GitHub Secrets (Recommended)

To enable full GitHub integration (Vim plugins, passwordless SSH authentication to GitHub from wsl instance, etc.), follow these steps:

1. **Copy the secrets template to the right filename:**
   ```bash
   cp secrets-template.yaml secrets.yaml
   # Edit secrets.yaml and fill in your GitHub credentials
   ```
   Only fill in the values; the keys are already set.

2. **Encrypt the secrets file (run in Linux environment):**
   ```bash
   ansible-vault encrypt secrets.yaml
   ```
   Enter a password when prompted. This will encrypt your secrets.

3. **Copy the encrypted file to Windows:**
   - If you created `secrets.yaml` in WSL or Linux, copy it to the Windows project root directory (e.g., `C:\Users\...\code\provisionwsl\`)

4. **Save the vault password:**
   - Save the password you used above in a plain text file named `secrets.pass` in the project root.
   - **Do not commit `secrets.yaml` or `secrets.pass` to version control.**

5. **Run the playbook as usual:**
   ```powershell
   .\kickoff.ps1 .\profiles\<profile-name>
   ```
   The playbook will automatically use the secrets if present.

6. **To view encrypted secrets:**
   ```bash
   ansible-vault view secrets.yaml
   ```
   Enter the password from `secrets.pass` when prompted. (Must run in Linux environment)

> **Note:** `ansible-vault` does not run natively on Windows. You must run these commands in a Linux environment, then copy the encrypted `secrets.yaml` file to your project root.
> 
> **Options for running ansible-vault:**
> - **Google Cloud Shell** (free, easiest): https://shell.cloud.google.com - Install ansible with `pip install ansible`, encrypt the file, then use Download button to copy files to Windows
> - **GitHub Codespaces** (free tier: 120 core-hours/month)
> - **Azure Cloud Shell** (free with Azure account)
> - **Existing WSL instance** on your machine
> - Any Linux VM or machine


**References:**
- [How to use Vault to protect sensitive Ansible data (DigitalOcean)](https://www.digitalocean.com/community/tutorials/how-to-use-vault-to-protect-sensitive-ansible-data)
- [Managing secrets in Ansible playbooks (Red Hat)](https://www.redhat.com/sysadmin/ansible-playbooks-secrets)

---

## Project Structure

```
provisionwsl/
├── kickoff.ps1           # Main entry point - creates and configures WSL distro
├── teardown.ps1          # Removes WSL distro
├── test.ps1              # Test harness for validating provisioned instances
├── playbook.yaml         # Main Ansible playbook
├── install.sh            # Copies project into WSL and runs Ansible
├── prep-install.sh       # Prepares distro (Python, Ansible install)
├── csv-utils.sh          # Bash utility for reading cloud image CSV data
├── ansible.cfg           # Ansible configuration (callbacks, inventory)
├── hosts                 # Ansible inventory (local connection)
├── secrets-template.yaml # Template for GitHub credentials
├── secrets.yaml          # Encrypted secrets (not committed)
├── secrets.pass          # Vault password file (not committed)
├── profiles/             # configuration files for provisioning
├── roles/                # Ansible roles
├── vars/                 # Variable definitions for Ansible roles
├── data/urls.csv         # Cloud image registry (ID, platform, type, URL, checksums)
├── files/common/         # config files deployed to instances
├── scripts/              # PowerShell and bash helper scripts
│   ├── *.ps1             # PowerShell modules (profile parsing, WSL ops, downloads, etc.)
│   └── bash/             # Per-distro prep-install scripts
├── install/              # default WSL instance install directory (can be overriden)
├── logs/                 # Log files directory
└── tmp/                  # Temporary files (downloaded cloud images)
```

## Quick Start

### 1. Configure user settings

Edit `vars/user_environment.yml` and set `target_user`, `user_home`, and `git_user_email` to match your environment. See [User Configuration](#user-configuration) for details.

### 2. Create a new WSL instance

```powershell
# From the project directory
.\kickoff.ps1 .\profiles\<profile-name>
```

### 3. Example: Create Ubuntu 22.04 instance with name ubuntu2204-sample by downloading cloud image

```powershell
.\kickoff.ps1 .\profiles\ubuntu2204-sample
```

### 4. Teardown (remove) ubuntu2204-sample instance

```powershell
.\teardown.ps1 .\profiles\ubuntu2204-sample
```
### 5. Example: Create fedora 37.04 instance with name fedora3704-sample using predownloaded tar file to a different install folder

```powershell
.\kickoff.ps1 .\profiles\fedora3704-sample
```

### 6. Teardown (remove) fedora3704-sample instance

```powershell
.\teardown.ps1 .\profiles\fedora3704-sample
```
---

## Profile Configuration

Profiles are stored in the `profiles/` directory. Each profile defines how a WSL instance should be downloaded, created and configured. Profiles are intentionally minimal — most user-specific settings are centralized in `vars/user_environment.yml`.

### Profile Variables

| Variable | Description | Example | Required | Default Behavior |
|----------|-------------|---------|----------|------------------|
| `ps_distro_id` | Cloud image ID from `data/urls.csv` | `ubuntu2204`, `alpine320` | Conditional | Required to download a cloud image. Either `ps_distro_id` or `ps_distro_source` must be set. |
| `ps_distro_source` | Local tar file path | `C:\path\to\distro.tar` | Conditional | Required to use a custom local distro image. Either `ps_distro_id` or `ps_distro_source` must be set. |
| `distro_type` | Linux distribution type | `ubuntu`, `fedora`, `alpine` | Conditional | Auto-detected from `urls.csv` when using `ps_distro_id`. Required when using `ps_distro_source`. |
| `ps_install_dir` | WSL installation directory | `C:\Users\user\wsl` | No | Defaults to `<project>/install/<distro_name>` |
| `skipsteps` | Comma-separated tags to skip | `github,gui` | No | All roles run if empty. Skip specific tags to customize installation. |
| `debug_mode` | Set to `check` for Ansible dry run | `check` | No | Normal execution if unset |

The installation script forwards a nonempty `skipsteps` value to Ansible as
`--skip-tags` in both normal and check mode, and logs the command being run.
For example, `export skipsteps=gui` skips tagged GUI tasks, including MATE and
XWayland. An unset or empty value adds no tag exclusions.

> **Note:** The WSL instance name is derived from the profile filename. For example, using profile `profiles/aa-ubu2204-sample` creates a WSL instance named `aa-ubu2204-sample`.

### Example Profile

A typical minimal profile:

```bash
# profiles/aa-ubu2204-sample
export ps_distro_id=ubuntu2204
export skipsteps=github,gui
```

This is all that's needed. The user (`target_user`) and other environment settings are read from `vars/user_environment.yml`.

---

## User Configuration

User-specific settings are centralized in `vars/user_environment.yml` — **not** in profile files. This is the single source of truth for the target user and related paths.

```yaml
# vars/user_environment.yml
target_user: snarasim                        # Non-root user to create (with sudo)
user_home: /home/snarasim                    # User home directory
root_user: root
root_user_home: /root
git_install_path: /usr                       # Where git is built/installed
git_user_email: snarasim123@gmail.com        # Git commit email
```

Edit these values to match your environment before provisioning.

---

## Available Roles

The playbook runs these roles in order (defined in `playbook.yaml`):

| Role | Tags | Description |
|------|------|-------------|
| `facts` | *(always runs)* | Detects distribution type (is_ubuntu, is_fedora, is_alpine), sets flags for skipped features (github_skipped, gui_skipped), extracts WSL distro name |
| `user` | `user` | Creates target user with sudo privileges, generates SSH keys, configures sudoers, sets up `wsl.conf` (systemd, default user) |
| `folders` | `folders` | Creates standard directories (`~/bashfiles`, `~/bin`, `~/tmp`) for target user and root |
| `cloud` | `cloud`, `aws`, `gcp` | Installs AWS CLI (Ubuntu/Fedora) and GCP CLI (all distros). Use `aws` or `gcp` tags to skip individual providers. |
| `shell` | `shell`, `bash` | Configures bash environment — copies aliases, functions, prompt, variables, dircolors, `.bashrc_custom` |
| `packages` | `packages` | Installs distro-specific system packages from `vars/packages_*.yml` |
| `git` | `git`, `gitcore`, `github` | Builds git from source (v2.48.0), configures git settings. With `github` tag: creates SSH keys and uploads to GitHub API. |
| `editor` | `editor`, `vim`, `nvim` | Installs Vim with vim-plug and plugins (or `.vimrc_noplug` if github skipped). Installs Neovim (v0.10.4). |
| `gui` | `gui`, `wmaker` | Copies window manager helper script to `~/bin` |
| `container` | `container`, `k8s`, `k9s`, `helm` | Installs kubectl, k9s (v0.27.4), Helm (v3.7.2 with s3 and env plugins). Configures `.kube_aws` and `.kube_gcp` directories. |
| `bash_extra` | `bash_extra` | Copies additional bash customization files (devsetup, ubuntu-specific scripts) |
| `dev` | `dev`, `python`, `pyenv` | Installs pyenv (v2.6.22) and pyenv-virtualenv (v1.2.4). Builds Python 3.11.9 and 3.12.4; sets global to 3.12.4. |
| `post_run` | `post_run` | Adds pyenv to `.bashrc_custom`, configures cloud/K8s PATH integration, creates kube config switcher scripts, sets default `.kube` symlink |

Java setup in the `dev` role uses SDKMAN and the configured Java versions on
Ubuntu/Fedora. Alpine instead installs APK-managed JDKs using
`alpine_java_versions` in `vars/language_versions.yml` (defaults: `"11"`, `"17"`,
`"21"`), with `alpine_java_default_version: "11"` selected in new Bash sessions.
The default must be in the configured list. Patch updates follow the Alpine
repository; choose majors available there. Alpine does not use the SDKMAN pins.
On an Alpine rerun, the role removes SDKMAN Bash initialization left by earlier
provisioning, but retains downloaded SDKMAN files. Open a fresh shell afterward.

Switch JDKs in the current Bash session with `java-use 11`, `java-use 17`, or
`java-use 21`. The helper checks both `java` and `javac` before updating
`JAVA_HOME` and `PATH`, and removes previous JDK path entries. A failed selection
leaves the current environment unchanged. New shells return to the configured
default. After rerunning Java tasks, source `~/.bashrc_custom` or open a new shell
to load the helper. JDK package installation belongs to the Alpine Java tasks
(`java`, `jdk`, or `dev` tags), not the generic packages role.

> **Note:** The `tools`, `terminal`, and `db` role directories exist but are **not active** in `playbook.yaml`. Their tasks are either commented out or have no `main.yml`.

### Skipping Roles

Use the `skipsteps` variable in your profile to skip roles by their tags:

```bash
# Skip multiple roles
export skipsteps=packages,cloud,editor,git,container

# Skip only GitHub SSH setup (keeps git install, skips key upload)
export skipsteps=github

# Skip individual cloud providers
export skipsteps=aws    # Skip AWS CLI, keep GCP
export skipsteps=gcp    # Skip GCP CLI, keep AWS

# Skip GUI support
export skipsteps=gui
```

---

## Available Cloud Images
   
Cloud images are defined in `data/urls.csv`. When a profile sets `ps_distro_id`, the image is downloaded from the URL, extracted, and used to create the WSL instance.

| ID | Type | Description |
|----|------|-------------|
| `ubuntu2204` | Ubuntu | Ubuntu 22.04 LTS (Jammy) WSL cloud image |
| `ubuntu2404` | Ubuntu | Ubuntu 24.04 LTS (Noble) WSL cloud image |
| `ubuntu2604` | Ubuntu | Ubuntu 26.04 LTS (Resolute) amd64 cloud rootfs (.tar.xz); provisioning candidate |
| `ubuntu1604` | Ubuntu | Ubuntu 16.04 (Xenial) cloud image (has MD5 checksum) |
| `alpine320` | Alpine | Alpine 3.20 minirootfs |
| `alpine321` | Alpine | Alpine 3.21.9 x86_64 minirootfs; provisioning candidate |
| `alpine322` | Alpine | Alpine 3.22.7 x86_64 minirootfs; provisioning candidate |
| `alpine323` | Alpine | Alpine 3.23.7 x86_64 minirootfs; provisioning candidate |
| `alpine324` | Alpine | Alpine 3.24.3 x86_64 minirootfs; provisioning candidate |
| `alpine318` | Alpine | Alpine 3.18 minirootfs |
| `fedora37` | Fedora | Fedora 37 cloud image (.tar.xz) |

The registry is an image catalogue, not a guarantee of upstream maintenance or
successful end-to-end provisioning. Older entries are retained for existing
profiles; Ubuntu 16.04, Alpine 3.18/3.20, and Fedora 37 are legacy choices rather
than recommended current releases.

The newer candidates above were checked against official download metadata on
2026-10-22. Their formats match the gzip/xz rootfs importer and existing distro
dispatch, but full WSL provisioning has not been tested. In particular, newer
Python versions, package availability, and Fedora's evolving DNF implementation
require separate validation before claiming support. Ubuntu 26.04 uses a generic
cloud rootfs, not the older WSL-specific image naming scheme.

Sources: [Ubuntu 26.04 images](https://cloud-images.ubuntu.com/releases/resolute/release/)
and Alpine's release metadata for
[3.21](https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/latest-releases.yaml),
[3.22](https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/latest-releases.yaml),
[3.23](https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/latest-releases.yaml),
and [3.24](https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/latest-releases.yaml).
Alpine URLs pin a patch release and include its published SHA256 as metadata.
The current download path does not enforce that SHA256 field. Ubuntu's
`release` URL is rolling, so its checksum is intentionally not pinned here.

Newer Fedora images were reviewed but not added:
[Fedora 43](https://dl.fedoraproject.org/pub/fedora/linux/releases/43/Container/x86_64/images/)
and [44](https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Container/x86_64/images/)
provide `.wsl` images, which the current filename-based importer rejects.
Their `.oci.tar.xz` images are OCI bundles, not directly importable rootfs tars.
Adding those URLs alone would not work; importing their format needs a separate
change. The existing Fedora 37 GitHub `/blob/` URL is also a legacy HTML-view URL,
not a verified direct-image download. No Fedora entry is newly certified here.

To add a new cloud image, append a row to `data/urls.csv`:

```csv
ID,PLATFORM,TYPE,URL,MD5,SHA512,SHA256
myimage,wsl,ubuntu,https://example.com/image.tar.gz,,,
```

---

## Examples

### Example 1: Full Ubuntu Development Environment

Create a profile for full development setup:

```bash
# profiles/my-ubuntu-dev
export ps_distro_id=ubuntu2204
# Don't skip anything - full install
export skipsteps=
```

Ensure `vars/user_environment.yml` has your user settings, then run:

```powershell
.\kickoff.ps1 .\profiles\my-ubuntu-dev
```

### Example 2: Minimal Alpine for Testing

```bash
# profiles/alpine-test
export ps_distro_id=alpine320
export skipsteps=cloud,container,gui,editor,git
```

Run:
```powershell
.\kickoff.ps1 .\profiles\alpine-test
```

### Example 3: AWS-focused Ubuntu Instance

```bash
# profiles/my-aws-env
export ps_distro_id=ubuntu2204
export skipsteps=gcp,github,gui
```

Run:
```powershell
.\kickoff.ps1 .\profiles\my-aws-env
```

### Example 4: Using a Local Image

```bash
# profiles/my-local-fedora
export distro_type=fedora
export ps_distro_source=C:\soft\wsl\fedora_3704.tar
export skipsteps=github,gui
```

Run:
```powershell
.\kickoff.ps1 .\profiles\my-local-fedora
```

### How Provisioning Works

Running `.\kickoff.ps1 .\profiles\aa-ubu2204-sample` performs the following:

1. Reads `target_user` from `vars/user_environment.yml`
2. Reads profile variables (`ps_distro_id`, `skipsteps`, etc.)
3. If `ps_distro_id` is set, looks up the cloud image in `data/urls.csv`, downloads it to `./tmp`, and extracts it
4. Runs `wsl --import` to create the WSL instance
5. Runs `prep-install.sh` — installs Python and Ansible inside the instance
6. Runs `install.sh` — copies the project into the instance and runs the Ansible playbook
7. Restarts the WSL instance

The WSL instance name is derived from the profile filename (e.g., `aa-ubu2204-sample`).

---

## Testing

The project includes tests (`test.ps1`) that validates a provisioned WSL instance. It runs 20+ checks inside the instance.

```powershell
.\test.ps1 .\profiles\<profile-name>
```

Tests include:
- User creation, SSH keys, and sudo access
- Bash initialization scripts (compares source files to installed copies)
- Git installation and configuration
- Python version and pyenv setup
- Cloud CLI availability (AWS/GCP)
- Kubernetes directories and kube config switchers
- `~/bin` helper scripts
- Vim/Neovim installation
- k9s, Helm, kubectl
- `wsl.conf` configuration
- Home directory permissions
- Default shell verification
- GitHub known_hosts entry

The test harness respects the `skipsteps` from the profile — skipped roles are not tested.

---

## Teardown

To remove a WSL instance:

```powershell
.\teardown.ps1 .\profiles\<profile-name>
```

You can also run the `wsl --unregister <distro-name>` command to remove the instance.  A teardown log is created in the `logs/` directory.

---

## Customization

### Adding Cloud Images

Edit `data/urls.csv` to add new cloud images:

```csv
ID,PLATFORM,TYPE,URL,MD5,SHA512,SHA256
ubuntu2204,wsl,ubuntu,https://cloud-images.ubuntu.com/wsl/releases/22.04/current/ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz,,,
ubuntu2404,wsl,ubuntu,https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-24.04lts.rootfs.tar.gz,,,
alpine320,wsl,alpine,https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.0-x86_64.tar.gz,,,
fedora37,wsl,fedora,https://github.com/fedora-cloud/docker-brew-fedora/blob/37/x86_64/fedora-37-x86_64.tar.xz,,,
```

The CSV supports optional MD5, SHA512, and SHA256 checksum columns, but these fields are not used.

### Modifying Roles

Roles are located in `roles/<role-name>/tasks/`. Edit the YAML files to customize behavior. Modify the playbook.yaml to call the new roles.

### Changing Variables

| File | Purpose |
|------|---------|
| `vars/user_environment.yml` | Target user, home directory, git email — **edit this first** |
| `vars/language_versions.yml` | Python versions (pyenv), Node.js version, GCP CLI Python range, pyenv/virtualenv versions |
| `vars/tool_versions.yml` | Helm, git, Neovim version numbers |
| `vars/packages_ubuntu.yml` | Ubuntu-specific packages to install (apt) |
| `vars/packages_fedora.yml` | Fedora-specific packages to install (dnf) |
| `vars/packages_alpine.yml` | Alpine-specific packages to install (apk) |
| `vars/vimvars.yml` | Vim directory and vimrc paths |

---

## Troubleshooting

### Log Files

Log files are created in the `logs/` directory and contain detailed information about the provisioning process:

- **`logs/<distro-name>.log`** - Main kickoff/provisioning log
  - Contains output from WSL import, prep-install scripts, and Ansible playbook execution
  - Check this file if provisioning fails or hangs
  
- **`logs/<distro-name>-teardown.log`** - Teardown/removal log
  - Contains output from the WSL unregister operation

**Viewing logs:**
```powershell
# View latest log in real-time
Get-Content .\logs\<distro-name>.log -Wait -Tail 50

# Search for errors
Select-String -Path ".\logs\<distro-name>.log" -Pattern "error|failed|fatal"
```

### Common Issues

#### Alpine Java fails to load `libjvm.so`

SDKMAN's configured Temurin builds can require glibc, whereas Alpine uses musl.
The message can report a missing `libjvm.so` even when the file exists, because
its native dependencies cannot be resolved. Do not work around this by adding
library search paths or assuming a libc compatibility package is sufficient.
The Alpine Java tasks now install and verify APK's native OpenJDK instead,
using `alpine_java_versions` and `alpine_java_default_version`.
Copy updated provisioning files into an existing failed instance's checkout
before rerunning Ansible there; a fresh shell picks up the corrected Java path.

#### XWayland fails with "System has not been booted with systemd"

Writing `systemd=true` to `/etc/wsl.conf` does not change the running init
system. WSL must restart the distro before systemd becomes PID 1.
The XWayland role now enables its service and configures the default target
offline when systemd is not running, without attempting a daemon reload.
The normal kickoff restart activates these settings after provisioning.

For an instance stopped by this error, terminate it with
`wsl --terminate <distro-name>`, start it again, and verify
`wsl -d <distro-name> -- cat /proc/1/comm` reports `systemd`.
Copy updated provisioning files into its Linux checkout before rerunning
Ansible there. Do not unregister the instance or rerun kickoff to recover it.

#### MATE prerequisites fail because `/usr/bin/python3.12` does not exist

**Cause:** The MATE prerequisites previously assumed Ubuntu 24.04's system Python
3.12, even on Ubuntu 22.04, which uses system Python 3.10. The Python installed
for Ansible and versions managed by pyenv are separate from Ubuntu's system
Python.

**Solution:** The role now reads Ubuntu's default Python from
`/usr/share/python3/debian_defaults` before configuring the `python3` alternative.
There is no need to install Python 3.12 to work around this error.
For an existing failed instance, copy the updated
`roles/mate-desktop/tasks/prerequisites.yml` into the instance's provisioning
checkout (normally `/root/code/provisionwsl`) before rerunning Ansible there.
Running `kickoff.ps1` again will refuse to overwrite an existing distro.

#### 1. Distro already exists
```
##### Distro name present in already installed distros list. cannot reinstall. exiting.
```
**Cause:** A WSL instance with the same name is already installed.

**Solution:** 
```powershell
# Option 1: Run teardown first
.\teardown.ps1 .\profiles\<profile-name>

# Option 2: Manually unregister
wsl --unregister <distro-name>

# Then run kickoff again
.\kickoff.ps1 .\profiles\<profile-name>
```

#### 2. Missing SSH keys (github tag skipped)
If you skip the `github` tag, vim plugins requiring git clone over SSH won't work.

**Solution:** The project automatically uses `.vimrc_noplug` (minimal Vim config without plugins) in this case. To enable full Vim with plugins, set up GitHub secrets as described in the [GitHub Integration section](#github-integration--secrets-setup).

#### 3. Ansible playbook fails with "Permission denied"
**Cause:** Insufficient permissions or user not created properly.

**Solution:**
- Check that `target_user` is set correctly in `vars/user_environment.yml`
- Verify the user was created: `wsl -d <distro-name> -u root id <username>`
- Check log file for user creation errors

#### 4. Cloud CLI (AWS/GCP) not found after installation
**Cause:** PATH not updated in current shell session.

**Solution:**
```bash
# Restart the WSL instance
exit
wsl -d <distro-name>

# Or manually source bashrc
source ~/.bashrc_custom
```

#### 5. Kubernetes authentication errors
```
Unable to connect to the server: getting credentials: exec: executable aws not found
```
**Cause:** kubectl is using the wrong cloud provider credentials.

**Solution:**
```bash
# Switch to AWS
~/bin/kube_aws.sh

# Or switch to GCP
~/bin/kube_gcp.sh

# Verify
kubectl config current-context
```

#### 6. Alpine-specific issues
**Issue:** Commands not found, or shell behaves unexpectedly.

**Cause:** Alpine uses `ash` shell by default instead of `bash`.

**Solution:** The project installs `bash` automatically during prep-install. If issues persist:
```bash
# Verify bash is installed
wsl -d <distro-name> -u root which bash

# Manually switch to bash
wsl -d <distro-name> -u root bash
```

#### 7. Package installation fails on Alpine
**Cause:** Alpine uses `apk` package manager, package names may differ from Ubuntu/Fedora.

**Solution:** Check `vars/packages_alpine.yml` for correct package names. Alpine packages often have different names (e.g., `python3-dev` vs `python3-devel`).

#### 8. Ansible vault errors when setting up secrets
```
ERROR! Attempting to decrypt but no vault secrets found
```
**Cause:** `secrets.pass` file not found or not in the correct location.

**Solution:**
- Ensure `secrets.pass` is in the project root directory
- Verify the file contains only the vault password (no extra whitespace or newlines)
- Check file is not empty: `Get-Content .\secrets.pass`

#### 9. WSL instance hangs or becomes unresponsive
**Solution:**
```powershell
# Terminate the instance
wsl --terminate <distro-name>

# Restart WSL service
wsl --shutdown
wsl -d <distro-name>

# If still unresponsive, teardown and recreate
.\teardown.ps1 .\profiles\<profile-name>
.\kickoff.ps1 .\profiles\<profile-name>
```

#### 10. Python version issues with GCP CLI
```
Google Cloud CLI requires Python 3.9 to 3.14
```
**Cause:** System Python version incompatible with GCP CLI.

**Solution:** The GCP CLI tarball includes a bundled Python interpreter. Ensure you're using the tarball installation method (which is default for Ubuntu/Debian and Alpine). For Fedora, the DNF package handles dependencies automatically.

### Debugging Tips

1. **Enable verbose Ansible output:**
   Edit `install.sh` and add `-vvv` to the ansible-playbook command:
   ```bash
   ansible-playbook -vvv playbook.yaml ...
   ```

2. **Test individual roles:**
   ```bash
   # From inside WSL instance
   cd ~/code/provisionwsl
   ansible-playbook playbook.yaml --tags "git" -vv
   ```

3. **Check Ansible facts:**
   ```bash
   ansible -m setup localhost
   ```

4. **Verify WSL version:**
   ```powershell
   wsl -l -v
   # Ensure VERSION shows "2" not "1"
   ```

5. **Check Windows build for WSLg support:**
   ```powershell
   winver
   # Need 10.0.19044+ for WSLg (GUI apps)
   ```

6. **Run the test harness** after provisioning to validate the instance:
   ```powershell
   .\test.ps1 .\profiles\<profile-name>
   ```

### Getting Help

If issues persist:
1. Check the log files in the `logs/` directory
2. Review the profile configuration for typos or missing variables
3. Verify `vars/user_environment.yml` has correct user settings
4. Verify all prerequisites are met (WSL2 enabled, PowerShell 5.1+)
5. Run `.\test.ps1 .\profiles\<profile-name>` to identify specific failures

---
