#!/usr/bin/env bash
# disable-user.sh — safely disable (lock) a Linux user account in a distro-friendly way
# Usage:
#   sudo ./disable-user.sh <username> [--kill] [--nologin]
# Options:
#   --kill     terminate the user's processes/sessions
#   --nologin  set shell to nologin (extra hardening; preserves account)

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
info(){ echo "==> $*"; }

# --- preflight ---
[[ $EUID -eq 0 ]] || die "This script must be run as root."
[[ $# -ge 1 ]] || die "Usage: $0 <username> [--kill] [--nologin]"

USER="$1"; shift || true
KILL=false
NOLOGIN=false
for arg in "$@"; do
  case "$arg" in
    --kill) KILL=true ;;
    --nologin) NOLOGIN=true ;;
    *) die "Unknown option: $arg" ;;
  esac
done

# --- verify user exists and is not root ---
id "$USER" &>/dev/null || die "User '$USER' does not exist."
[[ "$USER" != "root" ]] || die "Refusing to disable 'root'."

# --- helpers for tool availability ---
have() { command -v "$1" &>/dev/null; }

# --- 1) Lock the account (primary method + fallbacks) ---
locked=false
if have usermod; then
  info "Locking account with: usermod -L $USER"
  usermod -L "$USER" && locked=true
fi

if ! $locked && have passwd; then
  # BusyBox/alpine & many distros: 'passwd -l' locks by adding '!' to the hash
  info "Locking account with: passwd -l $USER"
  passwd -l "$USER" && locked=true
fi

$locked || die "Failed to lock account (neither 'usermod -L' nor 'passwd -l' worked)."

# --- 2) Expire the account immediately (prevents login even if passwordless methods exist) ---
expired=false
if have chage; then
  info "Expiring account with: chage -E 0 $USER"
  chage -E 0 "$USER" && expired=true
elif have usermod; then
  # usermod -e 1 sets the expiry date to 1970-01-02 (effectively expired)
  info "Expiring account with: usermod -e 1 $USER"
  usermod -e 1 "$USER" && expired=true
fi

$expired || info "Could not set an expiry (no 'chage' or suitable 'usermod'); relying on lock."

# --- 3) Optionally set shell to nologin for extra hardening ---
if $NOLOGIN; then
  # Prefer common nologin locations
  NOLOGIN_SHELL=""
  for s in /usr/sbin/nologin /sbin/nologin /bin/false; do
    [[ -x $s || -f $s ]] && NOLOGIN_SHELL="$s" && break
  done
  if [[ -n "$NOLOGIN_SHELL" ]]; then
    if have chsh; then
      info "Setting login shell to $NOLOGIN_SHELL with chsh"
      chsh -s "$NOLOGIN_SHELL" "$USER"
    elif have usermod; then
      info "Setting login shell to $NOLOGIN_SHELL with usermod"
      usermod -s "$NOLOGIN_SHELL" "$USER"
    else
      info "No 'chsh' or 'usermod' to set nologin shell; skipping."
    fi
  else
    info "No nologin shell found on system; skipping."
  fi
fi

# --- 4) Optionally terminate running sessions/processes ---
if $KILL; then
  killed=false
  if have loginctl; then
    # systemd systems
    info "Terminating sessions via: loginctl terminate-user $USER"
    loginctl terminate-user "$USER" && killed=true || true
  fi

  if have pkill && ! $killed; then
    info "Killing processes via: pkill -u $USER"
    pkill -u "$USER" || true
    killed=true
  elif have killall && ! $killed; then
    info "Killing processes via: killall -u $USER"
    killall -u "$USER" || true
    killed=true
  fi

  $killed || info "Could not terminate user processes (no loginctl/pkill/killall)."
fi

# --- 5) Show final status ---
info "Account status for '$USER':"
if have passwd; then
  passwd -S "$USER" 2>/dev/null || true   # shadow-utils format on many distros
fi
if have chage; then
  chage -l "$USER" 2>/dev/null || true
fi

info "User '$USER' has been disabled (locked)."
$NOLOGIN && info "Shell set to nologin."
$KILL && info "Active sessions/processes terminated."