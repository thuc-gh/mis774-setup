# MIS774 — macOS Setup (Apple Silicon)

Everything you need for MIS774 Enterprise Data Management, in one command. No vendor sites, no account sign-ups, no version guessing.

> **Apple Silicon only** (M1/M2/M3/M4). Check with `uname -m` — it must say `arm64`. If it says `x86_64` you have an Intel Mac; ask your tutor.

## Install

Open **Terminal** and paste this:

```bash
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/thuc-gh/mis774-setup/main/install.sh)"
```

It installs Java 21 and Pentaho automatically, then opens the MySQL installers for you to click through (those need your Mac password, so they can't be automated).

Then open a **new** Terminal window and start Pentaho:

```bash
cd ~/Pentaho/data-integration && ./spoon.sh
```

The Spoon window can take up to a minute to appear.

## What you get

| Component | Version |
|---|---|
| Pentaho Data Integration | 11.0.0.1-259 (macOS 26 fix + MySQL driver already included) |
| MySQL Community Server | 9.7.1 (arm64) |
| MySQL Workbench | 8.0.47 (arm64) |
| MySQL Connector/J | 8.0.33 |
| Java (Temurin JDK) | 21 (LTS) |

## Two things that will waste your afternoon if you skip them

**Java must be 21.** Not 25, not 26. On newer Java, Pentaho reads dates in **US month/day order without any error** — `1/07/26` becomes 7 January instead of 1 July. The installer handles this; just don't override it later.

**Open a new Terminal window after installing.** The Java setting only applies to windows opened afterwards. If `java -version` says 26, that's all this is.

## If something goes wrong

**Pentaho window is blank / grey.** You're on an unpatched Pentaho. Use the download from here rather than one from the Pentaho website: this build already contains the fix (Pentaho ships a 2022 graphics library that cannot draw on macOS 26).

**`java -version` says 26.** Open a new Terminal window. If it still says 26, run `source ~/.zshrc`.

**"Cannot be opened because the developer cannot be verified".** System Settings → Privacy & Security → scroll down → **Open Anyway**.

**Forgot your MySQL root password.** There is no recovery. Uninstall MySQL Server and reinstall.

## Manual downloads

If you'd rather not run the script, all files are on the [Releases page](../../releases/latest).

## What's in this repo

| File | Purpose |
|---|---|
| `install.sh` | The installer |
| `LICENSES.md` | Licences and source availability for everything distributed here |

---

*Unit mirror for Deakin MIS774. Files are hosted here so the versions stay pinned and the links keep working — vendor download URLs move when versions are superseded. See [LICENSES.md](LICENSES.md) for licensing and source.*
