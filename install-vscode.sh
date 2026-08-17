#!/usr/bin/env bash
#
# vscode-installer
#
# Downloads the latest stable Microsoft Visual Studio Code (Linux tar.gz) from
# the official Microsoft website and installs it on this machine.
#
# The tar.gz is self-contained, so this works on ANY Linux distribution —
# no package conversion needed.
#
# Fully unattended: no questions, no prompts (except the sudo password prompt).
# Running VS Code instances are closed before installing.
#
# Usage:
#   ./install-vscode.sh
#   curl -fsSL https://cdn.jsdelivr.net/gh/zonaro/vscode-installer@main/install-vscode.sh | bash
#

# ----------------------------------------------------------- VS Code ASCII art --
cat <<'EOF'
    ██████╗ ███████╗███╗   ██╗███████╗███████╗███████╗
    ██╔══██╗██╔════╝████╗  ██║██╔════╝██╔════╝██╔════╝
    ██║  ██║█████╗  ██╔██╗ ██║███████╗█████╗  ███████╗
    ██║  ██║██╔══╝  ██║╚██╗██║╚════██║██╔══╝  ╚════██║
    ██████╔╝███████╗██║ ╚████║███████║███████╗███████║
    ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚══════╝╚══════╝╚══════╝
    
    Visual Studio Code Installer for Linux
EOF
echo

set -euo pipefail

# ------------------------------------------------------------------ helpers --
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# ------------------------------------------- refuse to run inside VS Code ----
# The script closes VS Code before installing; running it from VS Code's own
# integrated terminal would kill the terminal (and this script) mid-run.
if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
  warn "You are running this script from inside VS Code's integrated terminal."
  warn "The script must close VS Code before installing, which would kill this terminal."
  warn "Please run it from a standalone terminal instead (e.g. Ctrl+Alt+T)."
  exit 1
fi

# ----------------------------------------------------- required commands ----
for cmd in curl sudo tar; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

# -------------------------------------------------- 1. detect architecture ----
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  OS="linux-x64"   ;;
  aarch64|arm64) OS="linux-arm64" ;;
  *) die "Unsupported architecture: $ARCH" ;;
esac

URL="https://code.visualstudio.com/sha/download?build=stable&os=${OS}"
TARBALL="$(mktemp /tmp/vscode-XXXXXX.tar.gz)"
INSTALL_DIR="/opt/vscode"

# ------------------------------------------------- 2. download the tar.gz ----
info "Downloading the latest VS Code ($OS) ..."
curl -fL --retry 3 --retry-delay 2 -o "$TARBALL" "$URL" || die "Download failed: $URL"

# Sanity check: the download must be a gzip archive (magic bytes 1f 8b).
if [ "$(head -c 2 "$TARBALL" | od -An -tx1 | tr -d ' \n')" != "1f8b" ]; then
  die "Downloaded file is not a valid gzip archive."
fi

# ----------------------------------------- 3. close running VS Code ----------
info "Closing running VS Code instances ..."
pkill -f "$INSTALL_DIR/code" 2>/dev/null || true
pkill -f '/usr/share/code/code' 2>/dev/null || true
pkill -f 'code --' 2>/dev/null || true
sleep 1

# ------------------------------------------- 4. install to /opt/vscode -------
info "Installing to $INSTALL_DIR ..."
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1

# ------------------------------------------- 5. symlink the code command ----
info "Creating /usr/bin/code symlink ..."
sudo ln -sf "$INSTALL_DIR/bin/code" /usr/bin/code

# ------------------------------------------- 6. desktop integration ----------
info "Installing desktop entry and icon ..."
sudo mkdir -p /usr/share/applications /usr/share/pixmaps
if curl -fsSL -o /tmp/vscode-icon.png \
  "https://raw.githubusercontent.com/microsoft/vscode/main/resources/linux/code.png" 2>/dev/null; then
  sudo cp /tmp/vscode-icon.png /usr/share/pixmaps/code.png
  rm -f /tmp/vscode-icon.png
fi
sudo tee /usr/share/applications/code.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Visual Studio Code
Comment=Code editing. Redefined.
Exec=/usr/bin/code %F
Icon=/usr/share/pixmaps/code.png
Terminal=false
Type=Application
Categories=Utility;TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;
StartupWMClass=Code
EOF
sudo update-desktop-database /usr/share/applications 2>/dev/null || true

# ------------------------------------------------------ 7. cleanup ------------
rm -f "$TARBALL"

info "Done. Installed version:"
code --version | head -1