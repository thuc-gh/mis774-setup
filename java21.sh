#!/bin/zsh
# Install Java 21 and set JAVA_HOME — macOS, Apple Silicon.
#
#   zsh install-java21-macos.sh
#
# Pentaho 11 needs Java 21. On newer Java (25/26) Pentaho silently reads dates
# in US month/day order: 1/07/26 becomes 7 January instead of 1 July, with no
# error. This script installs 21 and points your Mac at it.
#
# Safe to re-run. Repairs the broken JAVA_HOME line left by earlier versions.

set -e
RC="$HOME/.zshrc"

echo "Java 21 setup"
echo "============="

# ---- Apple Silicon only -----------------------------------------------------
if [ "$(uname -m)" != arm64 ]; then
  echo "ERROR: this script is for Apple Silicon Macs (M1/M2/M3/M4)."
  echo "       Your Mac reports: $(uname -m)"
  exit 1
fi

# ---- Never run as root ------------------------------------------------------
if [ "$EUID" = 0 ]; then
  echo "ERROR: do not run this with sudo."
  echo "       It would create root-owned files in your home folder and break your Terminal."
  echo "       Run it again WITHOUT sudo."
  exit 1
fi

# ---- Can we write ~/.zshrc? -------------------------------------------------
if [ ! -e "$RC" ]; then
  touch "$RC" 2>/dev/null || {
    echo "ERROR: cannot create $RC — home folder not writable. Contact IT support."
    exit 1
  }
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
    echo "       Then run this script again."
    echo "       If that does not work, show this message to your tutor."
    exit 1
  fi
  echo "      NOTE: ~/.zshrc was read-only; made it writable."
fi

# ---- Is Java 21 REALLY installed? -------------------------------------------
# Critical: "java_home -v 21" alone is useless. Without -F it ALWAYS exits 0,
# falling back to whatever Java it can find (even a Java 8 applet plugin), so
# "-v 21" happily returns Java 8 or 26. -F makes it fail when 21 is absent.
# We then confirm the JVM really reports 21, in case -F is unavailable.
java21_home() {
  local h
  h=$(/usr/libexec/java_home -v 21 -F 2>/dev/null) || return 1
  [ -n "$h" ] && [ -x "$h/bin/java" ] || return 1
  "$h/bin/java" -version 2>&1 | grep -qE '(java|openjdk) version "21' || return 1
  printf '%s' "$h"
}

# ---- 1. Install -------------------------------------------------------------
if H=$(java21_home); then
  echo "[1/4] Java 21 already installed:"
  echo "      $H"
else
  echo "[1/4] Installing Java 21..."
  if command -v brew >/dev/null 2>&1; then
    echo "      Using Homebrew (may ask for your Mac password)."
    brew install --cask temurin@21
  else
    echo "      Downloading Temurin 21 (~200MB, no password needed)..."
    mkdir -p "$HOME/Library/Java/JavaVirtualMachines"
    curl -# -fL -o /tmp/jdk21.tar.gz \
      "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jdk/hotspot/normal/eclipse"
    tar -xzf /tmp/jdk21.tar.gz -C "$HOME/Library/Java/JavaVirtualMachines/"
    rm -f /tmp/jdk21.tar.gz
  fi
  if H=$(java21_home); then
    echo "      Installed: $H"
  else
    echo "ERROR: Java 21 still not found after installing."
    echo "       Installed Java versions on this Mac:"
    /usr/libexec/java_home -V 2>&1 | sed 's/^/         /'
    echo "       Show this to your tutor."
    exit 1
  fi
fi

# ---- 2. Repair any broken line from an earlier version of this script -------
# Earlier versions wrote java_home WITHOUT -F, which can point JAVA_HOME at the
# wrong Java. Upgrade those lines in place rather than adding a second block.
if grep -q 'java_home -v 21' "$RC" 2>/dev/null && ! grep -q 'java_home -v 21 -F' "$RC" 2>/dev/null; then
  cp "$RC" "$RC.mis774-backup"
  sed -i '' -e 's|java_home -v 21)|java_home -v 21 -F)|g' \
            -e 's|java_home -v 21 2>/dev/null)|java_home -v 21 -F 2>/dev/null)|g' "$RC"
  echo "[2/4] Repaired an earlier JAVA_HOME line that could point at the wrong Java."
  echo "      (backup saved as ~/.zshrc.mis774-backup)"
fi

# ---- 3. Set JAVA_HOME -------------------------------------------------------
if grep -q 'java_home -v 21 -F' "$RC" 2>/dev/null; then
  echo "[3/4] JAVA_HOME already configured in ~/.zshrc."
else
  echo "[3/4] Adding JAVA_HOME to ~/.zshrc..."
  cat >> "$RC" <<'EOF'

# Java 21 for Pentaho 11. Pentaho needs 21; on newer Java it reads dates in
# US month/day order without any error.
# -F makes java_home FAIL when 21 is missing, instead of silently handing back
# a different Java. Without -F this line can point at Java 8 or 26.
_j21=$(/usr/libexec/java_home -v 21 -F 2>/dev/null)
if [ -n "$_j21" ]; then
  export JAVA_HOME="$_j21"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
unset _j21
EOF
fi

# ---- 4. Verify --------------------------------------------------------------
# .zshrc only loads for interactive shells, so "zsh -i" is the honest test.
# Filter for the version line specifically: Terminal's "Restored session:"
# banner and other startup output can otherwise land on line 1.
echo "[4/4] Verifying in a fresh interactive shell..."
VER=$(zsh -i -c 'java -version' 2>&1 | grep -E '(java|openjdk) version' | head -1)
JH=$(zsh -i -c 'echo "JH=$JAVA_HOME"' 2>&1 | grep '^JH=' | head -1 | sed 's/^JH=//')

echo
if echo "$VER" | grep -q '"21'; then
  echo "SUCCESS"
  echo "  JAVA_HOME = $JH"
  echo "  $VER"
  echo
  echo "Open a NEW Terminal window, then check:  java -version"
  echo "Old windows keep the old setting until you close them."
else
  echo "PROBLEM: expected Java 21 but a fresh shell reports:"
  echo "  version   : ${VER:-(no version line found)}"
  echo "  JAVA_HOME : ${JH:-(empty)}"
  echo
  echo "Java 21 IS installed at:"
  echo "  $H"
  echo
  echo "So something in your shell config is overriding it. Check for another"
  echo "JAVA_HOME line in these files, and delete it:"
  for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" "$HOME/.zlogin"; do
    [ -f "$f" ] && grep -n 'JAVA_HOME' "$f" 2>/dev/null | sed "s|^|    $(basename $f):|"
  done
  echo
  echo "Show this to your tutor."
  exit 1
fi
