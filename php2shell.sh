#!/usr/bin/env bash
# PHP2Shell package assessment and optional update
#
# --check: Read installed PHP package versions; never changes the server.
# --apply: On supported Ubuntu releases only, updates affected PHP packages
#          after explicit confirmation and verifies the versions afterward.
# This checks distribution packages, NOT container/source PHP or live processes.
# CVE-2026-109618 / CVE-2026-109619
# Usage: bash php2shell-v2.1.1-commented.sh --check
#        sudo bash php2shell-v2.1.1-commented.sh --apply
# Fail on unexpected command errors, undefined variables and pipeline failures.
set -euo pipefail
export LC_ALL=C

# Select check mode by default and reject unsupported command-line options.
MODE=${1:---check}
if [[ $# -gt 1 || ( $MODE != --check && $MODE != --apply ) ]]; then
  echo 'Usage: bash php2shell-v2.1.1-commented.sh [--check|--apply]' >&2
  exit 3
fi
[[ -r /etc/os-release ]] || { echo 'ERROR: Cannot read /etc/os-release' >&2; exit 3; }
. /etc/os-release

# Identify which package database/manager belongs to this Linux host.
case ${ID:-} in
  ubuntu|debian) PM=apt-get ;;
  rhel|rocky|almalinux|centos|fedora|amzn|ol) PM=$(command -v dnf >/dev/null && echo dnf || echo yum) ;;
  alpine) PM=apk ;;
  sles|sled|opensuse*|suse) PM=zypper ;;
  *) echo "ERROR: Unsupported Linux distribution: ${ID:-unknown}" >&2; exit 3 ;;
esac

# Ubuntu package-version floors based on the Canonical vendor advisory.
# Other distributions remain UNKNOWN until separately verified.
FAMILY='' FIXED=''
if [[ $ID == ubuntu ]]; then
  case ${VERSION_ID:-} in
    18.04) FAMILY=php7.2; FIXED='7.2.24-0ubuntu0.18.04.17+esm14' ;;
    20.04) FAMILY=php7.4; FIXED='7.4.3-4ubuntu2.29+esm5' ;;
    22.04) FAMILY=php8.1; FIXED='8.1.2-1ubuntu2.28' ;;
    24.04) FAMILY=php8.3; FIXED='8.3.6-0ubuntu0.24.04.13' ;;
    26.04) FAMILY=php8.5; FIXED='8.5.4-0ubuntu1.5' ;;
    26.10) FAMILY=php8.5; FIXED='8.5.9-0ubuntu2.1' ;;
  esac
fi

# Print names of PHP packages currently installed through the OS package manager.
# The caller sorts/deduplicates these names before assessing them.
packages() {
  case $PM in
    apt-get)
      dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null |
        awk '$1=="ii" && ($2 ~ /^php[0-9]+[.][0-9]+($|-)/ || $2 ~ /^libapache2-mod-php[0-9]+[.][0-9]+$/) {print $2}' ;;
    dnf|yum|zypper)
      rpm -qa --qf '%{NAME}\n' 2>/dev/null | grep -E '^(php([0-9]+)?(-|$)|rh-php|ea-php)' || true ;;
    apk)
      apk info 2>/dev/null | grep -E '^php[0-9]+(-|$)' || true ;;
  esac
}

# Exit codes: 0=patched, 1=update needed, 2=unknown, 3=execution error.
# Compare installed package revisions with the known Ubuntu fixed revision.
# Unverified releases, additional PHP versions and missing PHP return UNKNOWN.
assess() {
  local p v mark matched=0 old=0 other=0 status=UNKNOWN
  local -a installed=()
  # Collect installed packages without modifying the package database.
  mapfile -t installed < <(packages | sort -u)
  printf '\n=== PHP2Shell security assessment ===\n'
  printf 'OS          : %s\n' "$PRETTY_NAME"
  printf 'PHP CLI     : %s\n' "$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo 'Not found')"
  printf 'PHP packages: %s detected\n' "${#installed[@]}"
  printf 'CVEs        : CVE-2026-109618 / CVE-2026-109619\n\n'

  if ((${#installed[@]} == 0)); then
    echo 'No distribution-managed PHP packages detected.'
  elif [[ -z $FIXED ]]; then
    echo 'Vendor fix  : Not verified for this distribution/version.'
  else
    printf 'Vendor fix  : %s\n' "$FIXED"
    # Inspect each package in the supported PHP release family.
    for p in "${installed[@]}"; do
      case $p in
        "$FAMILY"|"$FAMILY"-*|"libapache2-mod-$FAMILY")
          v=$(dpkg-query -W -f='${Version}' "$p") || { echo "ERROR: Could not read version of $p" >&2; return 3; }
          ((matched+=1))
          # dpkg handles Debian/Ubuntu revision ordering correctly.
          # The Ubuntu revision check rejects unknown third-party version strings.
          if [[ $v == *ubuntu* ]] && dpkg --compare-versions "$v" ge "$FIXED"; then
            mark=OK
          else
            mark=OLD
            ((old+=1))
          fi
          printf '  %-4s %-28s %s\n' "$mark" "$p" "$v" ;;
        *) ((other+=1)) ;;
      esac
    done
    if ((matched>0 && other==0)); then
      if ((old>0)); then status=UPDATE_NEEDED; else status=PATCHED; fi
    fi
    if ((other>0)); then printf 'Note: %s other PHP package(s) could not be verified.\n' "$other"; fi
  fi

  # Provide one prominent human-readable verdict.
  case $status in
    PATCHED) echo 'RESULT: PATCHED — recognized Ubuntu PHP packages meet the vendor fix.' ;;
    UPDATE_NEEDED) echo 'RESULT: UPDATE NEEDED — PHP packages below the vendor fix.' ;;
    UNKNOWN) echo 'RESULT: UNKNOWN — manual vendor/package verification required.' ;;
  esac
  echo 'Scope: distro-managed packages only; containers, source builds and running workers not checked.'
  echo 'Reference: https://ubuntu.com/blog/php2shell-vulnerability-fixes-available'
  # Return a machine-readable result for monitoring/automation.
  case $status in
    PATCHED) return 0 ;;
    UPDATE_NEEDED) return 1 ;;
    *) return 2 ;;
  esac
}

# Do not let set -e prematurely terminate the script on an assessment result.
result=0
assess || result=$?
# In read-only mode, finish immediately with the assessment exit code.
if [[ $MODE == --check ]]; then
  echo 'Mode: CHECK ONLY — no changes.'
  exit "$result"
fi