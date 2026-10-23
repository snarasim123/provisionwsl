---
name: wsl-image-format-support
description: Implement .wsl root filesystem image support in provisionwsl. Use when asked to enable Fedora 43/44 WSL images, accept local or downloaded .wsl files, extend image preparation beyond .tar.gz/.tar.xz, or resume the .wsl format analysis from 2026-10-22.
---

# Support .wsl distribution images

## Scope

Implement support for downloaded and local `.wsl` root filesystem images while
preserving the existing profile-driven, noninteractive provisioning workflow.
This skill records analysis and an implementation plan, not implemented support.
Reinspect the current checkout and working changes before editing.

Do not conflate image import support with full support for newer Fedora package
sets, Python, DNF, desktop components, or SDKMAN. Report those separately.
Do not implement the deferred Python-bootstrap rollout as part of this change.

## Verified format facts (2026-10-22)

- Microsoft describes `.wsl` as a root filesystem tar with a different extension.
  It is not an Appx/MSIX/ZIP package and is not an OCI container bundle.
- Gzip is the recommended compression. The extension alone does not prove the
  compression format; do not globally classify every `.wsl` as gzip.
- The newer distribution-install experience documented by Microsoft requires
  WSL 2.4.4 or newer. Do not infer that this version is required for importing a
  normalized tar through the project's existing `--import` route.
- The root of the archive must be the Linux filesystem root, not a containing
  directory. Preserve archive bytes, Linux ownership, permissions, and symlinks.
- `/etc/wsl-distribution.conf` may describe a first-launch OOBE command, default
  UID, and default distribution name. Installing through a modern file-installer
  path may introduce interaction and defaults the project does not intend.
- Range requests against both official Fedora files below returned gzip magic
  bytes `1f 8b 08` on the analysis date. Their server content type was
  `application/x-troff-man`, so MIME type is not a reliable archive classifier.

Sources:
- [Microsoft: build a custom WSL distribution](https://learn.microsoft.com/en-us/windows/wsl/build-custom-distro)
- [Microsoft: import a Linux distribution](https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro)
- [Fedora 43 image listing](https://dl.fedoraproject.org/pub/fedora/linux/releases/43/Container/x86_64/images/)
- [Fedora 44 image listing](https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Container/x86_64/images/)

Reverify official metadata and exact URLs before implementation:

```text
https://dl.fedoraproject.org/pub/fedora/linux/releases/43/Container/x86_64/images/Fedora-WSL-Base-43-1.6.x86_64.wsl
https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Container/x86_64/images/Fedora-WSL-Base-44-1.7.x86_64.wsl
```

Do not substitute their `.oci.tar.xz` downloads. Those are OCI bundles, requiring
layer processing beyond the requested rootfs import feature.

## Current project trace and blockers

### Profile and import entry point

[kickoff.ps1](../../../kickoff.ps1) loads
[Profile.ps1](../../../scripts/Profile.ps1), resolves the profile, derives the
instance name from its filename, and selects local or cloud installation.

- `ps_distro_id` selects a row in [urls.csv](../../../data/urls.csv).
- `ps_distro_source` supplies a local image and bypasses cloud preparation.
- A provided `ps_install_dir` is combined with the profile-derived instance name.
- Existing instances are rejected before import.
- Import currently runs `wsl --import <name> <directory> <source>`, followed
  immediately by `wsl --terminate`.
- The import exit code is not checked before termination can overwrite
  `$LASTEXITCODE`; a failed import can fall through into prerequisite commands.
- The initial diagnostic `wsl -d <name> ls /` does not explicitly select root,
  while the subsequent preparation and installation commands do.

Local `.wsl` files are not explicitly classified or normalized today. Do not
claim local import is necessarily impossible at the WSL layer: test it and make
the project's supported behavior consistent and explicit.

### Download and preparation

[CloudInstallPrep.ps1](../../../scripts/CloudInstallPrep.ps1):

1. Loads the CSV with [CloudImageCSV.ps1](../../../scripts/CloudImageCSV.ps1).
2. Derives a cache filename from the URL and reuses an existing file.
3. Calls [UrlDownload.ps1](../../../scripts/UrlDownload.ps1) when needed.
4. Dispatches on [CompressionUtils.ps1](../../../scripts/CompressionUtils.ps1).
5. Decompresses gzip or xz and returns a separately calculated output filename.

Concrete issues relevant to this feature:
- `Get-CompressionType` only recognizes `.gz`, `.tgz`, and `.xz` by extension.
  `.wsl` reaches the unsupported-format failure.
- `GetUncompressedFileName` strips the final extension. Merely treating `.wsl`
  as gzip would produce an extensionless output rather than a clear `.tar`.
- `Prepare-CloudInstall` assigns the extractor result but returns its own
  predicted path even when the extractor failed or returned nothing.
- Download failure can return an empty string while callers continue.
- Download and preparation both derive names with `Path.GetFileName` on the
  whole URL; a URI query string must not become a Windows filename.
- Cached bytes are trusted just because a file exists.

### Decompression helpers

[GzExtract.ps1](../../../scripts/GzExtract.ps1) and
[XzExtract.ps1](../../../scripts/XzExtract.ps1) both define `DeGZip-File` and
`GetUncompressedFileName`. Kickoff sources XzExtract after GzExtract, so the later
definitions win. Trace effective definitions before changing either helper.

- Gzip output is chosen by stripping the final suffix and is written directly.
  Streams are not protected by `try/finally`.
- Xz commands expect a recognized input suffix and determine their own output.
  Classifying an xz-compressed `.wsl` without adapting extraction is insufficient.
- Do not broaden duplicate-helper cleanup into unrelated refactoring; if touched,
  ensure there is one effective implementation of the changed behavior.

### Downstream provisioning and documentation

- [prep-install.sh](../../../prep-install.sh) and
  [csv-utils.sh](../../../csv-utils.sh) use the CSV `TYPE` for distro dispatch.
  A new Fedora image should retain `TYPE=fedora`, `PLATFORM=wsl`.
- Local profiles still need an appropriate distro type or lookup record; verify
  actual profile loading rather than assuming file extension supplies a distro.
- [Readme.md](../../../docs/Readme.md) currently documents the `.wsl` limitation
  and excludes Fedora 43/44 from the registry on that basis.
- Existing [CloudImageTest.ps1](../../../scripts/CloudImageTest.ps1) and
  [UrlDownloadTest.ps1](../../../scripts/UrlDownloadTest.ps1) have stale IDs/API
  assumptions; the latter references a missing `CloudImage.ps1`.
  Use [Assert.ps1](../../../scripts/Assert.ps1) and the viable existing test style,
  but do not claim those stale scripts constitute passing regression coverage.

## Recommended implementation

### 1. Preserve the existing import contract

Prefer preparing `.wsl` into a validated rootfs `.tar`, then using the existing
`wsl --import` path. Avoid switching all images to
`wsl --install --from-file`, invoking a shell association, double-clicking an
image, or introducing distro-vendor default names/OOBE prompts.

Keep cloud download responsibilities separate from local image preparation.
Use one shared preparation path for `.wsl` sources so local and cloud behavior do
not drift. Preserve the existing handling of local plain `.tar` images.
Do not decompress unrelated existing local formats without considering their
current import behavior.

Required initial `.wsl` payload support:
- Gzip-compressed rootfs tar, including the verified Fedora images.
- Valid uncompressed rootfs tar.

Identify payloads by bytes and actual archive structure, not MIME type or a
new extension-only gzip alias. Unsupported compression must fail explicitly.
Supporting xz inside `.wsl` is optional for this initial scope; only claim it if
the extractor supports arbitrary input suffixes and has regression coverage.
No requirement to add zstd, Appx/MSIX, OCI, VHD, or other formats here.

### 2. Make preparation reliable

- Resolve local input paths, handle spaces and uppercase `.WSL`, and derive
  remote filenames from the URI path. Preserve query parameters for the request,
  not for the cache filename.
- Derive a deterministic output such as `<image-base>.tar`, without modifying
  the source `.wsl`. Stage local outputs in a controlled cache rather than
  requiring write access beside a read-only source image.
- Stream decompression to disk; do not load an entire distro into memory.
- Keep archive extraction inside WSL import. Do not unpack the Linux rootfs onto
  the Windows project tree and repack it.
- Validate a tar payload, not just its gzip header. Reject HTML error pages,
  empty/truncated data, obvious OCI bundles and wrapped/non-rootfs archives.
  Define a lightweight, tested validation mechanism usable on the supported
  Windows/PowerShell baseline; do not assume PowerShell 7 or .NET tar APIs exist.
- Write new outputs to a staging file and publish them only after success.
  Dispose streams on every path and remove only files created by this attempt.
- Return the actual successful output path. Verify it exists and is nonempty
  before import; fail with useful diagnostics and a nonzero process result.
- Ensure cached output belongs to the current source. A previous successful tar
  must not hide a corrupt/changed input or a failed new preparation attempt.
  Keep cache validation narrow; do not introduce a broad caching framework.
- Do not delete original images or unrelated cached files. Do not return a
  success-shaped fallback when validation, download, or decompression fails.

### 3. Wire import and startup failure handling

- Check the import result immediately before running any other native command.
  On failure, stop before termination, bootstrap, or a "ready" message.
- Preserve the profile-selected name, destination, target user, and logging.
- Use explicit root for noninteractive preparation and diagnostics where needed.
  Test behavior with `/etc/wsl-distribution.conf` rather than assuming `--import`
  eliminates all OOBE/default-UID effects.
- If additional first-launch handling is required, document and test it;
  do not silently strip vendor metadata or create an extra interactive user.
- Keep PowerShell 5.1 compatibility and handle paths with spaces.

### 4. Add Fedora catalogue entries and update documentation

After the verified `.wsl` preparation/import route works, add `fedora43` and
`fedora44` using official direct-image URLs verified at implementation time.
Keep the existing seven-column CSV schema and existing profile IDs.
Do not repoint Fedora 37 profiles to a different major version.

Update the cloud-image table, local source examples, format requirements, and
the existing paragraph saying `.wsl` files are unsupported. Explicitly distinguish
working import from full Fedora provisioning support.
If recording checksums, use the vendor's checksum file for the exact artifact.
Do not claim SHA256 enforcement unless the downloader actually checks it; the
current CSV loader omits SHA fields when populating its dictionary.

## Validation and acceptance

Add persistent, focused regression tests using the existing test tooling where
viable. Use generated tiny fixtures rather than downloading full images in unit
tests. No WSL registration should occur in unit tests.

- [ ] Downloaded and local gzip `.wsl` sources produce valid importable tars.
- [ ] Plain tar `.wsl`, uppercase extensions, and filenames with spaces work.
- [ ] Local plain `.tar` and cloud `.tar.gz`, `.tgz`, `.tar.xz` behavior is
      preserved, including correct output names.
- [ ] URL queries do not pollute local filenames or remove request parameters.
- [ ] Invalid image ID, failed HTTP request, unreadable input, HTML response,
      corrupt gzip, truncated tar, empty payload, unsupported compression,
      OCI bundle, and non-rootfs archive fail explicitly.
- [ ] Cached success works, but partial/stale cached artifacts cannot mask failure.
- [ ] Input images remain intact; failed attempts leave no importable partial tar
      or open file handles.
- [ ] Import receives the correct source, instance name, and destination.
- [ ] A failed import stops before later native commands and returns failure.
- [ ] A source with vendor distribution metadata does not hang on OOBE or use an
      unexpected UID during automated setup.
- [ ] Registry IDs resolve through both PowerShell and Bash CSV consumers.
- [ ] Updated scripts parse and run on Windows PowerShell 5.1.

With explicit approval, perform integration tests using uniquely named disposable
instances: one official Fedora `.wsl`, one existing gzip image, and one existing
xz image. Verify registration, `/etc/os-release`, root command execution,
profile-derived install directory, and absence of unexpected interactive setup.
Then test full provisioning separately, recording newer Fedora/DNF/Python
failures as distinct from format support.

Report mocks, archive validation, actual imports, and full provisioning results
separately. Do not declare end-to-end support based only on a download, a magic
byte check, or a mocked import command.

## Safety and scope boundaries

- Never unregister, terminate, overwrite, or repurpose an existing user distro
  merely to test this feature. Cleanup only explicitly approved test instances.
- No full-image downloads or integration installs are required just to load this
  skill or plan the implementation.
- No changes to secrets, unrelated roles, Python rollout settings, or the JDK
  switcher are part of this task.
- Do not add a new packaging manager, Docker dependency, or archive framework
  merely to support the two verified gzip-based Fedora files.
- Recheck repository state; preserve unrelated uncommitted changes.
