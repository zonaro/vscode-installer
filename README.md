# vscode-installer

One-command installer for the latest stable **Microsoft Visual Studio Code** on any Linux distribution.

It runs fully unattended — no questions, no interactive prompts (the only prompt you may see is the system's sudo password prompt).

## What it does

1. Detects your CPU architecture (x64 / arm64)
2. Downloads the latest stable `.deb` package from the official Microsoft download endpoint
3. Closes any running VS Code instances
4. Detects your distribution and installs the package natively (converting it when needed)
5. Cleans up the downloaded file

## Distro support

| Distro family | Package manager | Install method |
|---|---|---|
| Debian, Ubuntu, Linux Mint, Pop!_OS, ... | `apt` / `dpkg` | installs the `.deb` directly |
| Arch, Manjaro, **Big Linux**, EndeavourOS, ... | `pacman` | converts with `debtap`, installs with `pacman -U` |
| Fedora, RHEL, CentOS, openSUSE, Mageia, ... | `dnf` / `yum` / `zypper` | converts with `alien`, installs the `.rpm` |
| Others (Gentoo, Alpine, Void, ...) | — | installs with `dpkg` if available (best effort) |

For non-Debian distros the system must have a **package converter** installed:

- **Arch-based:** `debtap` — Big Linux and Manjaro ship it out of the box. Otherwise: `yay -S debtap` or `pamac build debtap`
- **RPM-based:** `alien` — `sudo dnf install alien` (Fedora) or `sudo zypper install alien` (openSUSE)

If the converter is missing, the script stops with clear installation instructions.

## Requirements

- Any Linux distribution (see table above)
- `curl` and `sudo` installed
- The appropriate package converter for non-Debian distros (see above)
- Sudo access (you will be asked for your password once)

> **Important:** run it from a standalone terminal — **not** from inside VS Code's integrated terminal, because the script closes VS Code before installing.

## Usage

### Via curl (no clone needed)

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/zonaro/vscode-installer@main/install-vscode.sh | bash
```

> jsDelivr serves the latest commit automatically. The official GitHub raw URL
> (`https://raw.githubusercontent.com/zonaro/vscode-installer/main/install-vscode.sh`)
> also works, but its CDN may briefly serve a cached older version after a push.

### Via curl with sudo (if your user is not in sudoers)

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/zonaro/vscode-installer@main/install-vscode.sh | sudo bash
```

### Directly from this repository

```bash
git clone https://github.com/zonaro/vscode-installer.git
cd vscode-installer
./install-vscode.sh
```

## Notes

- The script never asks questions; the only prompt you may see is the sudo password prompt.
- If VS Code is open, the script closes it before installing.
- Supports x64 and arm64 architectures.
- The download comes from the official Microsoft endpoint: `https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-*`
- On Arch-based systems, the script automatically patches a known upstream `debtap` bug (a broken pkgfile check that makes `debtap` refuse to convert even after `debtap -u`), and skips the ~1 GB database update when it is less than 7 days old.