#!/usr/bin/env bash
#
# vscode-installer
#
# Downloads the latest stable Microsoft Visual Studio Code (.deb) from the
# official Microsoft website and installs it on this machine.
#
# Distro support:
#   - Debian/Ubuntu (apt/dpkg)          -> installs the .deb directly
#   - Arch-based (pacman), incl. Big Linux, Manjaro, EndeavourOS
#                                       -> converts with debtap, installs with pacman
#   - RPM-based (dnf/yum/zypper)        -> converts with alien, installs the .rpm
#   - Others with dpkg available        -> installs with dpkg (best effort)
#
# For non-Debian distros the system must have a package converter installed:
#   - Arch-based: debtap (Big Linux and Manjaro ship it; otherwise yay -S debtap)
#   - RPM-based:  alien (sudo dnf install alien / sudo zypper install alien)
#
# Fully unattended: no questions, no prompts (except the sudo password prompt).
# Running VS Code instances are closed before installing.
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
for cmd in curl sudo; do
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
# Debian/Ubuntu: install the .deb directly with dpkg + apt dependency fix.
install_deb() {
  command -v dpkg >/dev/null 2>&1 || die "dpkg not found."
  info "Installing with dpkg/apt ..."
  sudo dpkg -i "$DEB" 2>/dev/null || sudo apt-get install -f -y
  sudo apt-get install -f -y >/dev/null
}

# Arch-based (Arch, Manjaro, Big Linux, EndeavourOS, ...): convert with debtap.
install_arch() {
  DEBTAP="$(command -v debtap || command -v debtap-mod || true)"
  if [ -z "$DEBTAP" ]; then
    die "Arch-based distro detected but the 'debtap' converter is missing.
Install it first (Big Linux and Manjaro ship it; otherwise: yay -S debtap or pamac build debtap)."
  fi

  # Some debtap versions (upstream and Big Linux's fork) ship a broken pkgfile
  # check: the pattern '*.files?(.[[:digit:]]{3})' never matches modern pkgfile
  # databases, so debtap refuses to convert even after a successful "debtap -u".
  # Patch the pattern to a working one (idempotent, covers both install paths).
  for f in /usr/sbin/debtap /usr/bin/debtap; do
    if [ -f "$f" ] && grep -qF "grep -E '*.files?(.[[:digit:]]{3})'" "$f" 2>/dev/null; then
      warn "Patching the broken pkgfile check in $f ..."
      sudo sed -i "s|grep -E '\*\.files?(\.\[\[:digit:\]\]{3})'|grep -E '\\.files'|g" "$f"
    fi
  done

  # Update the debtap database only if it is missing or older than 7 days
  # (a full update re-downloads ~1 GB of Debian/Ubuntu package lists).
  if find /var/cache/debtap -maxdepth 1 -name '*-packages-files' -mtime -7 2>/dev/null | grep -q .; then
    info "debtap database is up to date; skipping update."
  else
    info "Updating the debtap database (first run may take a while) ..."
    sudo debtap -u || warn "debtap database update failed; continuing with existing data."
  fi

  WORK="$(mktemp -d /tmp/vscode-debtap-XXXXXX)"
  info "Converting the .deb to an Arch package ..."
  "$DEBTAP" -Q -o "$WORK" "$DEB" || die "debtap conversion failed."
  info "Installing with pacman ..."
  sudo pacman -U --noconfirm "$WORK"/*.pkg.tar.*
  rm -rf "$WORK"
}

# RPM-based (Fedora, RHEL, CentOS, openSUSE, Mageia, ...): convert with alien.
install_rpm() {
  if ! command -v alien >/dev/null 2>&1; then
    die "RPM-based distro detected but the 'alien' converter is missing.
Install it first (Fedora: sudo dnf install alien, openSUSE: sudo zypper install alien)."
  fi
  WORK="$(mktemp -d /tmp/vscode-alien-XXXXXX)"
  info "Converting the .deb to an RPM package ..."
  ( cd "$WORK" && sudo alien --to-rpm --scripts "$DEB" ) || die "alien conversion failed."
  if command -v dnf >/dev/null 2>&1; then
    info "Installing with dnf ..."
    sudo dnf install -y "$WORK"/*.rpm
  elif command -v zypper >/dev/null 2>&1; then
    info "Installing with zypper ..."
    sudo zypper --non-interactive install "$WORK"/*.rpm
  else
    info "Installing with yum ..."
    sudo yum install -y "$WORK"/*.rpm
  fi
  rm -rf "$WORK"
}

# pacman is checked first: some Arch-based distros (e.g. Big Linux) ship a
# fake "apt-get" shim that redirects to pamac, so apt-get alone is not a
# reliable Debian indicator. Real Debian/Ubuntu systems never have pacman.
if command -v pacman >/dev/null 2>&1; then
  install_arch
elif command -v apt-get >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then
  install_deb
elif command -v dnf >/dev/null 2>&1 || command -v zypper >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
  install_rpm
elif command -v dpkg >/dev/null 2>&1; then
  info "No native package manager detected; installing with dpkg (best effort) ..."
  sudo dpkg -i "$DEB" || true
else
  die "Unsupported distribution: no package manager or .deb converter found.
Install a converter first: debtap (Arch-based), alien (RPM-based) or dpkg (others)."
fi

# ------------------------------------------------------ 6. cleanup ------------
rm -f "$DEB"

info "Done. Installed version:"
code --version | head -1