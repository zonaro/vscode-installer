#!/usr/bin/env bash
#
# vscode-installer
#
# Downloads the latest stable Microsoft Visual Studio Code (.deb) from the
# official Microsoft website and installs it on this machine.
#
# It runs fully unattended: no questions, no prompts (except the sudo
# password prompt required by the system). Running VS Code instances are
# closed before the package is installed.
#
# Usage:
#   ./install-vscode.sh
#   curl -fsSL https://raw.githubusercontent.com/zonaro/vscode-installer/main/install-vscode.sh | bash
#
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
for cmd in curl sudo dpkg; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

# ------------------------------------------ 1. open the official website ----
info "Opening the official VS Code website ..."
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "https://code.visualstudio.com/" >/dev/null 2>&1 || true
fi

# -------------------------------------------------- 2. detect architecture ----
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  OS="linux-deb-x64"   ;;
  aarch64|arm64) OS="linux-deb-arm64" ;;
  *) die "Unsupported architecture: $ARCH" ;;
esac

URL="https://code.visualstudio.com/sha/download?build=stable&os=${OS}"
DEB="$(mktemp /tmp/vscode-XXXXXX.deb)"

# ------------------------------------------------- 3. download the .deb -------
info "Downloading the latest VS Code package ($OS) ..."
curl -fL --retry 3 --retry-delay 2 -o "$DEB" "$URL" || die "Download failed: $URL"

# ----------------------------------------- 4. close running VS Code ----------
info "Closing running VS Code instances ..."
pkill -f '/usr/share/code/code' 2>/dev/null || true
pkill -f 'code --' 2>/dev/null || true
sleep 1

# ----------------------------------------------------- 5. install ------------
info "Installing the package (sudo may ask for your password once) ..."
sudo dpkg -i "$DEB" 2>/dev/null || sudo apt-get install -f -y
sudo apt-get install -f -y >/dev/null

# ------------------------------------------------------ 6. cleanup ------------
rm -f "$DEB"

info "Done. Installed version:"
code --version | head -1