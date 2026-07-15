#!/bin/zsh
# MIS774 Enterprise Data Management — macOS setup (Apple Silicon)
#
#   zsh -c "$(curl -fsSL https://raw.githubusercontent.com/thuc-gh/mis774-setup/main/install.sh)"
#
# Installs Java 21 and Pentaho automatically, then opens the MySQL installers
# for you to click through. Safe to re-run.

set -e
BASE="https://github.com/thuc-gh/mis774-setup/releases/download/v2026-t2"
DL="$HOME/Downloads"
TARGET="$HOME/Pentaho/data-integration"

echo "MIS774 macOS setup"
echo "=================="

# ---- Apple Silicon only -----------------------------------------------------
if [ "$(uname -m)" != arm64 ]; then
  echo "ERROR: this installer is for Apple Silicon Macs (M1/M2/M3/M4) only."
  echo "       Your Mac reports: $(uname -m) (Intel)."
  echo "       Ask your tutor for the Intel instructions."
  exit 1
fi

# ---- 1. Java 21 -------------------------------------------------------------
if /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
  echo "[1/4] Java 21 already installed."
else
  echo "[1/4] Installing Java 21 (~200MB)..."
  mkdir -p "$HOME/Library/Java/JavaVirtualMachines"
  curl -# -L -o /tmp/jdk21.tar.gz \
    "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jdk/hotspot/normal/eclipse"
  tar -xzf /tmp/jdk21.tar.gz -C "$HOME/Library/Java/JavaVirtualMachines/"
  rm -f /tmp/jdk21.tar.gz
  echo "      Installed (no admin password needed)."
fi

# Use "-v 21", never "-v 21+": the "+" means "21 or newer" and picks the wrong Java.
if grep -q 'java_home -v 21' "$HOME/.zshrc" 2>/dev/null; then
  echo "      JAVA_HOME already set."
else
  cat >> "$HOME/.zshrc" <<'EOF'

# Java 21 for Pentaho 11 (MIS774). Pentaho needs 21; on newer Java it reads
# dates in US month/day order without telling you.
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
export PATH="$JAVA_HOME/bin:$PATH"
EOF
  echo "      JAVA_HOME added to ~/.zshrc."
fi

# ---- 2. Pentaho -------------------------------------------------------------
if [ -f "$TARGET/spoon.sh" ]; then
  echo "[2/4] Pentaho already at $TARGET"
else
  echo "[2/4] Downloading Pentaho (~450MB)..."
  curl -# -L -o /tmp/pdi.zip "$BASE/pdi-ce-11.0.0.1-259-mis774-arm64.zip"
  mkdir -p "$HOME/Pentaho"
  echo "      Unzipping..."
  unzip -q /tmp/pdi.zip -d "$HOME/Pentaho"
  rm -f /tmp/pdi.zip
  xattr -r -d com.apple.quarantine "$TARGET" 2>/dev/null || true
  echo "      Installed to $TARGET (MySQL driver and macOS 26 fix already included)."
fi

# ---- 3 & 4. MySQL -----------------------------------------------------------
# These need your admin password and a root password you choose, so you must
# click through them yourself. The script just fetches and opens them.
if [ -d "/usr/local/mysql" ] || [ -n "$(ls -d /usr/local/mysql-* 2>/dev/null)" ]; then
  echo "[3/4] MySQL Server already installed."
else
  echo "[3/4] Downloading MySQL Server (~541MB)..."
  curl -# -L -o "$DL/mysql-9.7.1-macos15-arm64.dmg" "$BASE/mysql-9.7.1-macos15-arm64.dmg"
  echo "      Opening the installer."
  echo "      >>> WRITE DOWN THE ROOT PASSWORD YOU SET. You cannot recover it. <<<"
  open "$DL/mysql-9.7.1-macos15-arm64.dmg"
fi

if [ -d "/Applications/MySQLWorkbench.app" ]; then
  echo "[4/4] MySQL Workbench already installed."
else
  echo "[4/4] Downloading MySQL Workbench (~333MB)..."
  curl -# -L -o "$DL/mysql-workbench-community-8.0.47-macos-arm64.dmg" \
    "$BASE/mysql-workbench-community-8.0.47-macos-arm64.dmg"
  echo "      Opening it: drag MySQL Workbench into Applications."
  open "$DL/mysql-workbench-community-8.0.47-macos-arm64.dmg"
fi

echo
echo "Done."
echo "  1. Finish the MySQL installers if they opened (set a root password and write it down)."
echo "  2. Open a NEW Terminal window."
echo "  3. Start Pentaho:  cd ~/Pentaho/data-integration && ./spoon.sh"
echo
echo "Check Java is right (must say 21) in the new window:  java -version"
