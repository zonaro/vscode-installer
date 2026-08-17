# vscode-installer

One-command installer for the latest stable **Microsoft Visual Studio Code** on any Linux distribution.

It runs fully unattended — no questions, no interactive prompts (the only prompt you may see is the system's sudo password prompt).

## What it does

1. Detects your CPU architecture (x64 / arm64)
2. Downloads the latest stable Linux `tar.gz` from the official Microsoft download endpoint
3. Closes any running VS Code instances
4. Extracts it to `/opt/vscode`
5. Creates the `/usr/bin/code` symlink and a desktop entry with icon
6. Cleans up the downloaded file

## Why tar.gz?

The official VS Code `tar.gz` is **self-contained** — it bundles the application and its runtime libraries, so it works on **any** Linux distribution with no package conversion at all (no `debtap`, no `alien`, no `dpkg`).

## Requirements

- Any Linux distribution
- `curl`, `sudo` and `tar` installed
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

## Options

| Option / Variable | Description |
|---|---|
| `--no-banner` | Skip the ASCII art banner |
| `--help` | Show usage information |
| `VC_INSTALL_QUIET=1` | Environment variable to skip the banner (useful for CI/automation) |

### Examples

```bash
# Skip banner via flag
./install-vscode.sh --no-banner

# Skip banner via environment variable (great for CI/CD)
VC_INSTALL_QUIET=1 ./install-vscode.sh

# Show help
./install-vscode.sh --help
```

The script displays a beautiful Unicode banner by default in supported terminals. In minimal environments (CI, dumb terminals, non-TTY), it automatically falls back to a clean text banner.

## What gets installed

| Path | Purpose |
|---|---|
| `/opt/vscode/` | The VS Code application files |
| `/usr/bin/code` | Symlink to the `code` command |
| `/usr/share/applications/code.desktop` | Desktop entry (app menu) |
| `/usr/share/pixmaps/code.png` | Application icon |

Your settings, extensions and workspace data live in `~/.config/Code` and `~/.vscode`, so they are preserved across reinstalls.

## Uninstall

```bash
sudo rm -rf /opt/vscode /usr/bin/code /usr/share/applications/code.desktop /usr/share/pixmaps/code.png
```

## Notes

- The script never asks questions; the only prompt you may see is the sudo password prompt.
- If VS Code is open, the script closes it before installing.
- Supports x64 and arm64 architectures.
- The download comes from the official Microsoft endpoint: `https://code.visualstudio.com/sha/download?build=stable&os=linux-*`