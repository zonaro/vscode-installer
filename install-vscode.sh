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
# Interactive: asks whether to install system-wide (requires sudo/pkexec) or
# user-only (no sudo needed, installs to ~/.local/share/vscode).
# Running VS Code instances are closed before installing.
#
# Usage:
#   ./install-vscode.sh
#   curl -fsSL https://cdn.jsdelivr.net/gh/zonaro/vscode-installer@main/install-vscode.sh | bash
#
# Options:
#   --no-banner    Skip the ASCII art banner
#   --help         Show this help message
#
# Environment variables:
#   VC_INSTALL_QUIET=1  Skip the ASCII art banner (same as --no-banner)

set -euo pipefail

# ----------------------------------------------------------- VS Code ASCII art --
print_banner() {
  # Check if terminal supports Unicode/box-drawing characters
  # If not, fall back to a simple text banner
  if [ -t 1 ] && [ "${TERM:-}" != "dumb" ] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
    cat <<'EOF'
                                 #*++*     
                             ****+===++* 
                         *******+======+
             #          ********#*+++++++
           #****#     +*********#++++++++
           ******** #**********  ++++++++
           #********##******    ++++++++
             #*********##       ++++++++
             *##*********#      ++++++++
           ****###*********#    ++++++++
           *#####** #**********  ++++++++
           **##**     #***********+++++++
                       #*********+++++++
                         #*******+++++++
                           #*****++++*# 
                             %#***#     
     
     Visual Studio Code Installer for Linux
EOF
  else
    cat <<'EOF'
    ==========================================
    Visual Studio Code Installer for Linux
    ==========================================
EOF
  fi
  printf '\n'
}

# ---------------------------------------------------- ask install scope ------
ask_install_scope() {
  # Check if running in non-interactive mode (piped from curl)
  if [ ! -t 0 ]; then
    # Non-interactive: default to system-wide for backward compatibility
    info "Non-interactive mode detected, defaulting to system-wide installation."
    INSTALL_SYSTEM_WIDE=true
    return
  fi

  printf '\n'
  info "Where would you like to install VS Code?"
  printf '  1) System-wide (requires sudo) - installs to /opt/vscode, symlink in /usr/bin/code\n'
  printf '  2) User-only (no sudo needed) - installs to ~/.local/share/vscode, symlink in ~/.local/bin/code\n'
  printf '\n'
  while true; do
    printf 'Enter choice [1/2] (default: 1): '
    read -r choice
    choice="${choice:-1}"
    case "$choice" in
      1)
        INSTALL_SYSTEM_WIDE=true
        break
        ;;
      2)
        INSTALL_SYSTEM_WIDE=false
        break
        ;;
      *)
        warn "Invalid choice. Please enter 1 or 2."
        ;;
    esac
  done
}

# Parse command-line arguments
SHOW_BANNER=true
for arg in "$@"; do
  case "$arg" in
    --no-banner)
      SHOW_BANNER=false
      ;;
    --help)
      # Print only the header documentation (up to the first non-comment line after the header)
      sed -n '2,/^set -euo pipefail$/p' "$0" | head -n -1 | cut -c4-
      exit 0
      ;;
    *)
      die "Unknown option: $arg"
      ;;
  esac
done

# Environment variable override
if [ "${VC_INSTALL_QUIET:-}" = "1" ]; then
  SHOW_BANNER=false
fi

# ------------------------------------------------------------------ helpers --
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# Print banner if not suppressed
if [ "$SHOW_BANNER" = true ]; then
  print_banner
fi

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
for cmd in curl tar; do
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

# ---------------------------------------------------- 2. ask install scope ----
ask_install_scope

# Set installation paths based on scope
if [ "$INSTALL_SYSTEM_WIDE" = true ]; then
  INSTALL_DIR="/opt/vscode"
  BIN_DIR="/usr/bin"
  DESKTOP_DIR="/usr/share/applications"
  ICON_DIR="/usr/share/pixmaps"
  SUDO="sudo"
  # Check for pkexec as alternative to sudo
  if command -v pkexec >/dev/null 2>&1; then
    SUDO="pkexec"
  fi
  # Verify sudo/pkexec is available for system-wide install
  if ! command -v "$SUDO" >/dev/null 2>&1; then
    die "System-wide installation requires '$SUDO' but it's not installed."
  fi
else
  INSTALL_DIR="$HOME/.local/share/vscode"
  BIN_DIR="$HOME/.local/bin"
  DESKTOP_DIR="$HOME/.local/share/applications"
  ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
  SUDO=""
  mkdir -p "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
fi

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

# ------------------------------------------- 4. install to target directory ----
info "Installing to $INSTALL_DIR ..."
if [ -n "$SUDO" ]; then
  $SUDO rm -rf "$INSTALL_DIR"
  $SUDO mkdir -p "$INSTALL_DIR"
  $SUDO tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1
else
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1
fi

# ------------------------------------------- 5. symlink the code command ----
info "Creating $BIN_DIR/code symlink ..."
if [ -n "$SUDO" ]; then
  $SUDO ln -sf "$INSTALL_DIR/bin/code" "$BIN_DIR/code"
else
  ln -sf "$INSTALL_DIR/bin/code" "$BIN_DIR/code"
fi

# ------------------------------------------- 6. desktop integration ----------
info "Installing desktop entry and icon ..."
if [ -n "$SUDO" ]; then
  $SUDO mkdir -p "$DESKTOP_DIR" "$ICON_DIR"
  if curl -fsSL -o /tmp/vscode-icon.png \
    "https://raw.githubusercontent.com/microsoft/vscode/main/resources/linux/code.png" 2>/dev/null; then
    $SUDO cp /tmp/vscode-icon.png "$ICON_DIR/code.png"
    rm -f /tmp/vscode-icon.png
  fi
else
  mkdir -p "$DESKTOP_DIR" "$ICON_DIR"
  if curl -fsSL -o /tmp/vscode-icon.png \
    "https://raw.githubusercontent.com/microsoft/vscode/main/resources/linux/code.png" 2>/dev/null; then
    cp /tmp/vscode-icon.png "$ICON_DIR/code.png"
    rm -f /tmp/vscode-icon.png
  fi
fi

if [ -n "$SUDO" ]; then
  $SUDO tee "$DESKTOP_DIR/code.desktop" >/dev/null <<'EOF'
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
  $SUDO update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
else
  tee "$DESKTOP_DIR/code.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Name=Visual Studio Code
Comment=Code editing. Redefined.
Exec=$HOME/.local/bin/code %F
Icon=$HOME/.local/share/icons/hicolor/256x256/apps/code.png
Terminal=false
Type=Application
Categories=Utility;TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;
StartupWMClass=Code
EOF
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# ------------------------------------------------------ 7. cleanup ------------
rm -f "$TARBALL"

info "Done. Installed version:"
code --version | head -1