#!/bin/bash
#
# uninstall-mysql.sh
# Detects and completely removes MySQL on macOS, whatever the install method:
#   - Homebrew (mysql, mysql@8.4, mysql-client, ... on Apple Silicon or Intel)
#   - Official Oracle DMG/PKG installer (/usr/local/mysql*)
#   - Leftovers: launch daemons, data dirs, configs, package receipts
#
# Usage:
#   bash uninstall-mysql.sh            # interactive (asks before deleting)
#   bash uninstall-mysql.sh --dry-run  # show what would be removed, change nothing
#   bash uninstall-mysql.sh --yes      # no confirmation prompt
#
# Or straight from GitHub without downloading:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/thuc-gh/mis774-setup/main/uninstall-mysql.sh)"
#
# WARNING: this permanently deletes all MySQL databases on the machine.
# Back up first if needed:  mysqldump --all-databases > backup.sql
#
set -u

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --yes|-y)  ASSUME_YES=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run this script with sudo. Run it as your normal user;"
  echo "it will ask for your password when it needs admin rights."
  exit 1
fi

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }

run() {
  # Execute a command, or just print it in dry-run mode
  if $DRY_RUN; then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

sudo_rm_rf() {
  for path in "$@"; do
    [ -e "$path" ] || continue
    run sudo rm -rf "$path"
  done
}

# ---------------------------------------------------------------------------
# 1. DETECT
# ---------------------------------------------------------------------------
bold "Scanning for MySQL installations..."

FOUND_ANY=false

# --- Homebrew ---
BREW_FORMULAE=()
BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"
  while IFS= read -r f; do
    [ -n "$f" ] && BREW_FORMULAE+=("$f")
  done < <(brew list --formula 2>/dev/null | grep -E '^mysql(@[0-9.]+)?$|^mysql-client(@[0-9.]+)?$')
fi
if [ "${#BREW_FORMULAE[@]}" -gt 0 ]; then
  FOUND_ANY=true
  bold "Found: Homebrew installation"
  for f in "${BREW_FORMULAE[@]}"; do info "formula: $f"; done
fi

# --- Homebrew data dirs (may exist even if formula was already uninstalled) ---
BREW_DATA_DIRS=()
for d in "/opt/homebrew/var/mysql" "/usr/local/var/mysql" "/opt/homebrew/etc/my.cnf" "/usr/local/etc/my.cnf"; do
  [ -e "$d" ] && BREW_DATA_DIRS+=("$d")
done
if [ "${#BREW_DATA_DIRS[@]}" -gt 0 ]; then
  FOUND_ANY=true
  bold "Found: Homebrew MySQL data/config"
  for d in "${BREW_DATA_DIRS[@]}"; do info "$d"; done
fi

# --- Oracle DMG installer ---
DMG_DIRS=()
for d in /usr/local/mysql /usr/local/mysql-*; do
  # -e is false for broken symlinks, so check -L too
  { [ -e "$d" ] || [ -L "$d" ]; } && DMG_DIRS+=("$d")
done
if [ "${#DMG_DIRS[@]}" -gt 0 ]; then
  FOUND_ANY=true
  bold "Found: Oracle DMG installation"
  for d in "${DMG_DIRS[@]}"; do info "$d"; done
fi

# --- Launch daemons / agents ---
LAUNCH_ITEMS=()
for d in /Library/LaunchDaemons /Library/LaunchAgents; do
  for p in "$d"/*mysql*; do
    [ -e "$p" ] && LAUNCH_ITEMS+=("$p")
  done
done
if [ "${#LAUNCH_ITEMS[@]}" -gt 0 ]; then
  FOUND_ANY=true
  bold "Found: launch daemons/agents"
  for p in "${LAUNCH_ITEMS[@]}"; do info "$p"; done
fi

# --- Misc system leftovers ---
MISC_PATHS=()
for p in "/Library/PreferencePanes/MySQL.prefPane" "/Library/StartupItems/MySQLCOM" \
         "/etc/my.cnf" "/etc/mysql" "/var/mysql"; do
  [ -e "$p" ] && MISC_PATHS+=("$p")
done
if [ "${#MISC_PATHS[@]}" -gt 0 ]; then
  FOUND_ANY=true
  bold "Found: system leftovers"
  for p in "${MISC_PATHS[@]}"; do info "$p"; done
fi

# --- Package receipts ---
RECEIPTS=()
while IFS= read -r r; do
  [ -n "$r" ] && RECEIPTS+=("$r")
done < <(pkgutil --pkgs 2>/dev/null | grep -i mysql)
if [ "${#RECEIPTS[@]}" -gt 0 ]; then
  FOUND_ANY=true
  bold "Found: installer receipts"
  for r in "${RECEIPTS[@]}"; do info "$r"; done
fi

# --- Running processes ---
RUNNING=false
if pgrep -x mysqld >/dev/null 2>&1 || pgrep -f mysqld_safe >/dev/null 2>&1; then
  RUNNING=true
  FOUND_ANY=true
  bold "Found: mysqld is currently running"
fi

# --- Things this script deliberately does NOT touch ---
if [ -d "/Applications/MAMP" ] || [ -d "/Applications/XAMPP" ]; then
  bold "Note: MAMP/XAMPP detected — its bundled MySQL is left alone."
  info "Remove the whole app from /Applications if you want it gone."
fi
if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Image}}' 2>/dev/null | grep -qi mysql; then
  bold "Note: a MySQL Docker container is running — left alone (docker rm it yourself)."
fi

if ! $FOUND_ANY; then
  echo
  bold "No MySQL installation found. Nothing to do."
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. CONFIRM
# ---------------------------------------------------------------------------
echo
bold "WARNING: this will permanently delete ALL MySQL databases on this machine."
echo "         Back up first if needed:  mysqldump --all-databases > backup.sql"
echo
if $DRY_RUN; then
  bold "Dry run: showing what would be done, changing nothing."
elif ! $ASSUME_YES; then
  printf 'Type "yes" to uninstall everything listed above: '
  # Read from the terminal, not stdin — stdin is the script itself under `curl | bash`
  if [ -r /dev/tty ]; then
    read -r answer < /dev/tty
  else
    read -r answer
  fi
  if [ "$answer" != "yes" ]; then
    echo "Aborted. Nothing was changed."
    exit 0
  fi
fi
echo

# ---------------------------------------------------------------------------
# 3. STOP SERVICES AND PROCESSES
# ---------------------------------------------------------------------------
bold "Stopping MySQL..."

for f in "${BREW_FORMULAE[@]+"${BREW_FORMULAE[@]}"}"; do
  run brew services stop "$f" 2>/dev/null || true
done

for p in "${LAUNCH_ITEMS[@]+"${LAUNCH_ITEMS[@]}"}"; do
  run sudo launchctl bootout system "$p" 2>/dev/null || \
    run sudo launchctl unload "$p" 2>/dev/null || true
done

if $RUNNING; then
  run sudo pkill -x mysqld 2>/dev/null || true
  run sudo pkill -f mysqld_safe 2>/dev/null || true
  $DRY_RUN || sleep 2
  if ! $DRY_RUN && pgrep -x mysqld >/dev/null 2>&1; then
    info "mysqld still running, forcing..."
    run sudo pkill -9 -x mysqld 2>/dev/null || true
  fi
fi

# ---------------------------------------------------------------------------
# 4. REMOVE
# ---------------------------------------------------------------------------
bold "Removing files..."

for f in "${BREW_FORMULAE[@]+"${BREW_FORMULAE[@]}"}"; do
  run brew uninstall --force "$f"
done

sudo_rm_rf "${BREW_DATA_DIRS[@]+"${BREW_DATA_DIRS[@]}"}"
sudo_rm_rf "${DMG_DIRS[@]+"${DMG_DIRS[@]}"}"
sudo_rm_rf "${LAUNCH_ITEMS[@]+"${LAUNCH_ITEMS[@]}"}"
sudo_rm_rf "${MISC_PATHS[@]+"${MISC_PATHS[@]}"}"

for r in "${RECEIPTS[@]+"${RECEIPTS[@]}"}"; do
  run sudo pkgutil --forget "$r"
done

# Per-user config (harmless to keep, but "complete uninstall" means complete)
if [ -f "$HOME/.my.cnf" ]; then
  run rm -f "$HOME/.my.cnf"
fi

# ---------------------------------------------------------------------------
# 5. VERIFY
# ---------------------------------------------------------------------------
echo
bold "Verifying..."
if $DRY_RUN; then
  info "dry run complete — nothing was changed."
  exit 0
fi

OK=true
if pgrep -x mysqld >/dev/null 2>&1; then
  info "FAIL: mysqld is still running"
  OK=false
fi
LEFTOVER="$(command -v mysql 2>/dev/null || true)"
if [ -n "$LEFTOVER" ]; then
  info "NOTE: a 'mysql' binary is still on PATH at $LEFTOVER"
  info "(open a NEW terminal window — this may just be a stale shell cache)"
fi
for d in /usr/local/mysql /opt/homebrew/var/mysql /usr/local/var/mysql; do
  if [ -e "$d" ]; then
    info "FAIL: $d still exists"
    OK=false
  fi
done

if $OK; then
  bold "MySQL has been completely removed."
  echo "If your shell still autocompletes 'mysql', run: hash -r  (or open a new terminal)."
else
  bold "Some items could not be removed — see FAIL lines above."
  exit 1
fi
