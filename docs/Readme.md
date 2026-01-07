# WSL Distro Provisioning with Ansible

This project automates the creation and proconfiguration visioning of WSL (Windows Subsystem for Linux) instances  using Ansible. It supports **Ubuntu**, **Fedora**, and **Alpine** Linux distributions.

The project was created by my need to provision  wsl instances for different needs over several years of my career.  
For example, i wanted a wsl instance to test redis related tasks and later on i needed a specific version of java to   
for my tasks. And then it was python...  
There is docker option to do this, but i found writing and maintaining docker files was tedious.   
There are prebuilt alternatives like devcontainers , but i found scripting and ansible easier for some reason.  



## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [GitHub Integration & Secrets Setup](#github-integration--secrets-setup)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Profile Configuration](#profile-configuration)
- [Available Roles](#available-roles)
- [Examples](#examples)
- [Teardown](#teardown)
- [Customization](#customization)

---

## Overview

The project provides:
- Automated WSL instance provisioning (import from cloud images or preexisting wsl compatible local images)
- Ansible-based configuration
- file driven configuration for different types of instances
- Support for Ubuntu , Fedora , and Alpine 

## Prerequisites

- Windows 10/11 with WSL2 enabled
- PowerShell 5.1 or later

## GitHub Integration & Secrets Setup

Some roles (such as Vim plugin installation) require GitHub SSH access for passwordless authentication from your WSL instance. You can either skip GitHub integration or set up secrets for secure access.

### Option 1: Skip GitHub Integration

If you do not want to set up GitHub SSH keys or secrets, you can skip all GitHub-dependent steps by adding `github` to the `skipsteps` variable in your profile:

```bash
export skipsteps=github
```

When this tag is skipped, the playbook will:
- Avoid tasks that require GitHub SSH access (e.g., installing Vim plugins that clone from private repos)
- Use a minimal `.vimrc_noplug` configuration for Vim without plugins
- Skip SSH key setup for no automatic login to GitHub from wsl instance. any task which requires github integration will not work.
 
### Option 2: Set Up GitHub Secrets (Recommended)

To enable full GitHub integration (Vim plugins, passwordless SSH authentication to GitHub from wsl instance, etc.), follow these steps:

> **Note:** `ansible-vault` does not run natively on Windows. You must run these commands in a Linux environment, then copy the encrypted `secrets.yaml` file to your project root.
> 
> **Options for running ansible-vault:**
> - **Google Cloud Shell** (free, easiest): https://shell.cloud.google.com - Install ansible with `pip install ansible`, encrypt the password file  then Download to copy files to Windows
> - **GitHub Codespaces** (free tier: 120 core-hours/month)
> - **Azure Cloud Shell** (free with Azure account)
> - **Existing WSL instance** on your machine
> - Any Linux VM or machine

1. **Copy the secrets template to the right filename:**
   ```bash
   cp secrets-template.yaml secrets.yaml
   # Edit secrets.yaml and fill in your GitHub credentials/keys
   ```
   Only fill in the values; the keys are already set.

2. **Encrypt the secrets file (run in Linux environment):**
   ```bash
   ansible-vault encrypt secrets.yaml
   ```
   Enter a password when prompted. This will encrypt your secrets.

3. **Copy the encrypted file to Windows:**
   - If you created `secrets.yaml` in WSL or Linux, copy it to the Windows project root directory (e.g., `C:\Users\...\code\setup2\ansible\`)

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

**References:**
- [How to use Vault to protect sensitive Ansible data (DigitalOcean)](https://www.digitalocean.com/community/tutorials/how-to-use-vault-to-protect-sensitive-ansible-data)
- [Managing secrets in Ansible playbooks (Red Hat)](https://www.redhat.com/sysadmin/ansible-playbooks-secrets)

---

## Project Structure

```
ansible/
├── kickoff.ps1           # Main entry point - creates and configures WSL distro
├── teardown.ps1          # Removes WSL distro
├── playbook.yaml         # Main Ansible playbook
├── profiles/             # File configurations for provisioning
├── roles/                # Ansible roles
├── vars/                 # Variable definitions for ansible roles
├── data/urls.csv         # image information (cloud or local). local or cloud, type of image, distro type etc
└── scripts/              # PowerShell/bash helper scripts
```

## Quick Start

### 1. Create a new WSL instance

```powershell
# From the ansible directory
.\kickoff.ps1 .\profiles\<profile-name>
```

### 2. Example: Create Ubuntu 22.04 minimal instance

```powershell
.\kickoff.ps1 .\profiles\aa-ubu2204-mini
```

### 3. Teardown (remove) an instance

```powershell
.\teardown.ps1 .\profiles\aa-ubu2204-mini
```

---

## Profile Configuration

Profiles are stored in the `profiles/` directory. Each profile defines how a WSL instance should be downloaded/accessed   and configured.

### Profile Variables

| Variable | Description | Example | Optional | Default Behavior |
|----------|-------------|---------|----------|------------------|
| `distro_type` | Linux distribution type | `ubuntu`, `fedora`, `alpine` | Yes | Required for distro detection type when cloud image is not available |
| `distro_name` | Name for the WSL instance | `aa-ubu2204-mini` | Yes | Profile filename is used as instance name. no longer needed. |
| `ps_distro_id` | Cloud image ID from urls.csv | `ubuntu2204` | Yes | Required to download an image from the cloud and install it.  |
| `ps_distro_source` | Local tar file path | `C:\path\to\distro.tar` | Yes | Required to use custom distro image. If ps_distro_id and ps_distro_source are empty, the script aborts. |
| `ps_install_dir` | WSL installation directory | `C:\Users\user\wsl` | Yes | Defaults to `<project>/install/<distro_name>` if empty. if a directory is provided, it is used instead of default location. |
| `default_user` | Non-root user to create | `snarasim` | No, Mandatory | User created with sudo privileges. setup to be default user. |
| `code_base` | Base path for code mounting | `/mnt/c/Users/user/code` | No, Mandatory | Path to Parent of the Project folder. |
| `code_root` | Code subdirectory | `setup2` | No, Mandatory | Project folder name. |
| `run_as_user` | User to run Ansible as | `root` | No, Mandatory | Defaults to `root`.  |
| `upgrade` | Run package upgrades | `true` | Yes | Updates the distro after install before running ansible. |
| `skipsteps` | Comma-separated roles to skip | `packages,cloud,editor` | Yes | Optionaly skip some ansible steps (identified by their tags) to customize the installation. For example, skip installing git or skip aws.|

### Example Profile: Ubuntu 22.04 Minimal

```bash
# profiles/aa-ubu2204-test

export ps_distro_id=ubuntu2204

export default_user=snarasim
export code_base=/mnt/c/Users/SrinivasaNarasimhan/code
export code_root=setup2
export code_src="$code_base/$code_root"

export run_as_user=root
export upgrade=true
export skipsteps=packages,cloud,editor,git,container
```
Running, 

```
    .\Kickoff.ps1 .\profiles\aa-ubu2204-test 
```

will provision a wsl distro identified by ubuntu2204, specified in the .\data\urls.csv  
The csv file provides the type of this distro (ubuntu), cloud image url.
The cloud image is downloaded to .\tmp folder, unpacked and used for provisioning.  
Then the ubuntu2204 instanced is updated , ansible and python are installed in it.  
The project code is copied to it and ansible is run to do the configuration.  
All ansible roles except listed in the skipsteps above will be installed.  
To install all roles, comment out, export skipsteps , line  

---

## Available Roles

The playbook includes these roles (defined in `playbook.yaml`):

| Role | Description |
|------|-------------|
| `facts` | Sets distribution facts (is_ubuntu, is_fedora, is_alpine) |
| `user` | Creates and configures users |
| `folders` | Creates standard directory structure |
| `cloud` | Installs cloud CLIs (AWS, GCP) |
| `shell` | Configures bash, aliases, and shell environment |
| `packages` | Installs system packages per distribution |
| `git` | Installs and configures git, creates ssh keys and uploads it to specified github account. This enabled github ops from the wsl instance. |
| `editor` | Installs vim/neovim with plugins |
| `gui` | GUI application support |
| `container` | Docker, Podman, Kubernetes tools |
| `bash_extra` | Additional bash customizations |
| `dev` | Development tools (Python, Node.js, Go, Java) |
| `tools` | Additional tools (lazygit, pyenv, SDKMAN) |
| `post_run` | Final configuration tasks |

### Skipping Roles

Use the `skipsteps` variable in your profile to skip roles:

```bash
# Skip multiple roles
export skipsteps=packages,cloud,editor,git,container

# Skip only GitHub SSH setup (useful without SSH keys)
export skipsteps=github
```

---

## Examples

### Example 1: Full Ubuntu Development Environment

Create a profile for full development setup:

```bash
# profiles/my-ubuntu-dev
export ps_distro_id=ubuntu2204
export default_user=yourname
export code_base=/mnt/c/Users/YourName/code
export code_root=projects
export code_src="$code_base/$code_root"

export run_as_user=root
export upgrade=true
# Don't skip anything - full install
export skipsteps=
```

Run:
```powershell
.\kickoff.ps1 .\profiles\my-ubuntu-dev
```

### Example 2: Minimal Alpine for Testing

```bash
# profiles/alpine-test
export ps_distro_id=alpine320
export default_user=testuser
export code_base=/mnt/c/Users/YourName/code
export code_root=setup2
export code_src="$code_base/$code_root"

export run_as_user=root
export upgrade=true
export skipsteps=cloud,container,gui,editor, git
```

Run:
```powershell
.\kickoff.ps1 .\profiles\alpine-test
```

---

## Teardown

To remove a WSL instance:

```powershell
.\teardown.ps1 .\profiles\<profile-name>
```

---

## Customization

### Adding Cloud Images

Edit `data/urls.csv` to add new cloud images:

```csv
ID,PLATFORM,TYPE,URL,MD5,SHA512,SHA256
ubuntu2204,wsl,ubuntu,https://cloud-images.ubuntu.com/wsl/releases/22.04/current/ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz,,,
alpine320,wsl,alpine,https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.0-x86_64.tar.gz,,,
fedora37,wsl,fedora,https://github.com/fedora-cloud/docker-brew-fedora/blob/37/x86_64/fedora-37-x86_64.tar.xz,,,
```

### Modifying Roles

Roles are located in `roles/<role-name>/tasks/`. Edit the YAML files to customize behavior.

### Adding Variables

- `vars/language_versions.yml` - Version numbers for languages/tools
- `vars/packages_ubuntu.yml` - Ubuntu-specific packages to install  
- `vars/packages_fedora.yml` - Fedora-specific packages to install  
- `vars/packages_alpine.yml` - Alpine-specific packages to install  
- `vars/tool_versions.yml` - Tool version configurations
- `vars/user_environment.yml` - User environment settings


---

## Troubleshooting

### Distro already exists
```
##### Distro name present in already installed distros list. cannot reinstall. exiting.
```
Solution: Run teardown first, then kickoff again.

### Missing SSH keys (github tag skipped)
If you skip the `github` tag, vim plugins requiring git clone over SSH won't work. The project automatically uses `.vimrc_noplug` in this case.

### Alpine-specific issues
Alpine uses `ash` shell by default. The project installs `bash` automatically during prep-install.

---

## Log Files

Log files are created in the ansible directory:
- `<distro-name>.log` - Kickoff log
- `<distro-name>-teardown.log` - Teardown log
