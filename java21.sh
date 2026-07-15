#!/bin/zsh
# Install Java 21 and set JAVA_HOME — macOS, Apple Silicon.
#
#   zsh install-java21-macos.sh
#
# Pentaho 11 needs Java 21. On newer Java (25/26) Pentaho silently reads dates
# in US month/day order: 1/07/26 becomes 7 January instead of 1 July, with no
# error. This script installs 21 and points your Mac at it.
#
# Safe to re-run. No admin password needed if Homebrew is absent.

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

# ---- 1. Install -------------------------------------------------------------
if /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
  echo "[1/3] Java 21 already installed:"
  echo "      $(/usr/libexec/java_home -v 21)"
else
  echo "[1/3] Installing Java 21..."
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
  /usr/libexec/java_home -v 21 >/dev/null 2>&1 \
    || { echo "ERROR: install finished but Java 21 still not found. Stopping."; exit 1; }
  echo "      Installed: $(/usr/libexec/java_home -v 21)"
fi

# ---- 2. Warn about competing settings ---------------------------------------
# A JAVA_HOME set in .zshenv/.zprofile is harmless (our .zshrc line runs later
# and wins for interactive shells), but an unrelated one already in .zshrc will
# fight ours, so say so rather than silently appending a second definition.
for f in "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zlogin"; do
  if [ -f "$f" ] && grep -q 'JAVA_HOME' "$f" 2>/dev/null; then
    echo "      NOTE: $f also sets JAVA_HOME. Ours takes effect for Terminal windows,"
    echo "            but remove that line if anything behaves oddly."
  fi
done
if [ -f "$RC" ] && grep -q 'JAVA_HOME' "$RC" 2>/dev/null && ! grep -q 'java_home -v 21' "$RC" 2>/dev/null; then
  echo
  echo "      WARNING: ~/.zshrc already sets JAVA_HOME to something else:"
  grep -n 'JAVA_HOME' "$RC" | sed 's/^/               /'
  echo "      Our setting is added at the end of the file, so it wins. Delete the"
  echo "      old line(s) above if you want to keep things tidy."
  echo
fi

# ---- 3. Set JAVA_HOME -------------------------------------------------------
# "-v 21" means exactly Java 21. Never "-v 21+": the "+" means "21 or newer",
# which resolves to Java 26 and silently undoes this whole script.
if grep -q 'java_home -v 21' "$RC" 2>/dev/null; then
  echo "[2/3] JAVA_HOME already configured in ~/.zshrc."
else
  echo "[2/3] Adding JAVA_HOME to ~/.zshrc..."
  cat >> "$RC" <<'EOF'

# Java 21 for Pentaho 11. Pentaho needs 21; on newer Java it reads dates in
# US month/day order without any error. "-v 21" not "-v 21+" ("+" means 21-or-newer).
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
export PATH="$JAVA_HOME/bin:$PATH"
EOF
fi

# ---- Verify -----------------------------------------------------------------
# Check the way a real Terminal window will see it: .zshrc only loads for
# interactive shells, so "zsh -i" is the honest test ("zsh -l -c" is not).
echo "[3/3] Verifying in a fresh interactive shell..."
VER=$(zsh -i -c 'java -version' 2>&1 | head -1)
JH=$(zsh -i -c 'echo $JAVA_HOME' 2>/dev/null | tail -1)

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
  echo "  $VER"
  echo "  JAVA_HOME = $JH"
  echo
  echo "Try:  source ~/.zshrc && java -version"
  echo "If it still fails, check ~/.zshrc for another JAVA_HOME line after ours."
  exit 1
fi
