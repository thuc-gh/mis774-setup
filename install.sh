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
RC="$HOME/.zshrc"

echo "MIS774 macOS setup"
echo "=================="

# ---- Checks before we download a gigabyte ------------------------------------
if [ "$(uname -m)" != arm64 ]; then
  echo "ERROR: this installer is for Apple Silicon Macs (M1/M2/M3/M4) only."
  echo "       Your Mac reports: $(uname -m) (Intel)."
  echo "       Ask your tutor for the Intel instructions."
  exit 1
fi

FREE_GB=$(df -g "$HOME" | tail -1 | awk '{print $4}')
if [ "${FREE_GB:-99}" -lt 4 ]; then
  echo "ERROR: not enough free disk space."
  echo "       This needs about 4GB free; you have ${FREE_GB}GB."
  echo "       Free some space and run this again."
  exit 1
fi

mkdir -p "$DL"   # normally exists, but the download fails hard if it doesn't

# Never run as root: sudo writes root-owned files into the student's home,
# which is the usual reason ~/.zshrc later becomes unwritable.
if [ "$EUID" = 0 ]; then
  echo "ERROR: do not run this with sudo."
  echo "       It would create root-owned files in your home folder and break your Terminal."
  echo "       Run it again WITHOUT sudo."
  exit 1
fi

# Check we can write ~/.zshrc BEFORE downloading a gigabyte.
if [ ! -e "$RC" ]; then
  touch "$RC" 2>/dev/null || { echo "ERROR: cannot create $RC — home folder not writable. Contact IT support."; exit 1; }
fi
if [ ! -w "$RC" ]; then
  RC_OWNER=$(stat -f%Su "$RC" 2>/dev/null || echo "?")
  ME=$(whoami)
  [ "$RC_OWNER" = "$ME" ] && chmod u+w "$RC" 2>/dev/null || true
  if [ ! -w "$RC" ]; then
    echo "ERROR: cannot write to ~/.zshrc — permission denied."
    echo
    if [ "$RC_OWNER" != "$ME" ]; then
      echo "       The file is owned by '$RC_OWNER', but you are '$ME'."
      echo "       This normally happens when something was run with sudo earlier."
      echo
      echo "       Fix it by running this one line (it will ask for your Mac password):"
      echo
      echo "         sudo chown $ME ~/.zshrc && chmod u+w ~/.zshrc"
    else
      echo "       You own the file, but it is still locked."
      echo
      echo "       Try these two lines:"
      echo
      echo "         chflags nouchg ~/.zshrc"
      echo "         chmod u+w ~/.zshrc"
    fi
    echo
    echo "       Then run this installer again."
    echo "       If that does not work, show this message to your tutor."
    exit 1
  fi
  echo "      NOTE: ~/.zshrc was read-only; made it writable."
fi

# ---- 1. Java 21 -------------------------------------------------------------
# Critical: "java_home -v 21" alone is useless. Without -F it ALWAYS exits 0,
# falling back to whatever Java it finds (even a Java 8 applet plugin), so it
# happily reports "21 installed" when it isn't. -F makes it fail properly.
# We then confirm the JVM really reports 21.
java21_home() {
  local h
  h=$(/usr/libexec/java_home -v 21 -F 2>/dev/null) || return 1
  [ -n "$h" ] && [ -x "$h/bin/java" ] || return 1
  "$h/bin/java" -version 2>&1 | grep -qE '(java|openjdk) version "21' || return 1
  printf '%s' "$h"
}

if J21=$(java21_home); then
  echo "[1/4] Java 21 already installed."
else
  echo "[1/4] Installing Java 21 (~200MB)..."
  mkdir -p "$HOME/Library/Java/JavaVirtualMachines"
  curl -# -L -o /tmp/jdk21.tar.gz \
    "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jdk/hotspot/normal/eclipse"
  tar -xzf /tmp/jdk21.tar.gz -C "$HOME/Library/Java/JavaVirtualMachines/"
  rm -f /tmp/jdk21.tar.gz
  if J21=$(java21_home); then
    echo "      Installed (no admin password needed)."
  else
    echo "ERROR: Java 21 still not found after installing. Java versions present:"
    /usr/libexec/java_home -V 2>&1 | sed 's/^/         /'
    echo "       Show this to your tutor."
    exit 1
  fi
fi

# Repair the line written by earlier versions of this script, which used
# java_home WITHOUT -F and so could point JAVA_HOME at the wrong Java.
if grep -q 'java_home -v 21' "$RC" 2>/dev/null && ! grep -q 'java_home -v 21 -F' "$RC" 2>/dev/null; then
  cp "$RC" "$RC.mis774-backup"
  sed -i '' -e 's|java_home -v 21)|java_home -v 21 -F)|g' \
            -e 's|java_home -v 21 2>/dev/null)|java_home -v 21 -F 2>/dev/null)|g' "$RC"
  echo "      Repaired an earlier JAVA_HOME line (backup: ~/.zshrc.mis774-backup)."
fi

if grep -q 'java_home -v 21 -F' "$RC" 2>/dev/null; then
  echo "      JAVA_HOME already set."
else
  cat >> "$RC" <<'EOF'

# Java 21 for Pentaho 11 (MIS774). Pentaho needs 21; on newer Java it reads
# dates in US month/day order without telling you.
# -F makes java_home FAIL when 21 is missing, instead of silently handing back
# a different Java. Without -F this line can point at Java 8 or 26.
_j21=$(/usr/libexec/java_home -v 21 -F 2>/dev/null)
if [ -n "$_j21" ]; then
  export JAVA_HOME="$_j21"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
unset _j21
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
echo "Checking what was installed..."
OK=1

# .zshrc only loads for interactive shells, so "zsh -i" is the honest test.
# Grep for the version line specifically: Terminal's "Restored session:" banner
# and other startup output can otherwise land on line 1 and be mistaken for it.
VER=$(zsh -i -c 'java -version' 2>&1 | grep -E '(java|openjdk) version' | head -1)
if echo "$VER" | grep -q '"21'; then
  echo "  Java 21        OK"
else
  echo "  Java           PROBLEM -> ${VER:-(no version line found)}"
  echo "                 Java 21 is installed at: $J21"
  echo "                 Something in your shell config is overriding it."
  echo "                 Look for another JAVA_HOME line here and delete it:"
  for f in "$RC" "$HOME/.zprofile" "$HOME/.zshenv"; do
    [ -f "$f" ] && grep -n 'JAVA_HOME' "$f" 2>/dev/null | sed "s|^|                   $(basename $f):|"
  done
  OK=0
fi

if [ -x "$TARGET/spoon.sh" ]; then
  echo "  Pentaho        OK"
else
  echo "  Pentaho        PROBLEM -> not found at $TARGET"
  OK=0
fi

if [ -f "$TARGET/lib/mysql-connector-j-8.0.33.jar" ]; then
  echo "  MySQL driver   OK"
else
  echo "  MySQL driver   PROBLEM -> missing from $TARGET/lib"
  OK=0
fi

echo
if [ "$OK" = 1 ]; then
  echo "Java and Pentaho are ready."
else
  echo "SOMETHING WENT WRONG (see above). Show this output to your tutor."
fi

echo
echo "You still need to do these yourself:"
echo "  1. If a MySQL installer window opened, click through it now."
echo "     >>> Write down the MySQL root password you set. It CANNOT be recovered. <<<"
echo "  2. If the Workbench window opened, drag MySQL Workbench into Applications."
echo "  3. Open a NEW Terminal window (this one still has the old Java setting)."
echo "  4. Start Pentaho:  cd ~/Pentaho/data-integration && ./spoon.sh"

[ "$OK" = 1 ] || exit 1
