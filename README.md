# vscode-installer

One-command installer for the latest stable **Microsoft Visual Studio Code** on Debian/Ubuntu (`.deb`).

It runs fully unattended — no questions, no interactive prompts (the only prompt you may see is the system's sudo password prompt).

## What it does

1. Opens the official VS Code website (<https://code.visualstudio.com/>)
2. Detects your CPU architecture (x64 / arm64)
3. Downloads the latest stable `.deb` package from the official Microsoft download endpoint
4. Closes any running VS Code instances
5. Installs the package with `dpkg` / `apt`
6. Cleans up the downloaded file

## Requirements

- Debian/Ubuntu-based Linux distribution
- `curl`, `sudo` and `dpkg` installed
- Sudo access (you will be asked for your password once)

> **Important:** run it from a standalone terminal — **not** from inside VS Code's integrated terminal, because the script closes VS Code before installing.

## Usage

### Via curl from GitHub raw (no clone needed)

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/vscode-installer/main/install-vscode.sh | bash
```

### Via curl with sudo (if your user is not in sudoers)

```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/vscode-installer/main/install-vscode.sh | sudo bash
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