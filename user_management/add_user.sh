#!/usr/bin/env bash
set -euo pipefail

# add_user.sh - Safely add a user with optional groups and expiration
# Usage: ./add_user.sh -u USERNAME [-g GROUPS] [-e EXPIRY] [--no-password]

usage() {
  echo "Usage: $0 -u USERNAME [-g GROUPS] [-e EXPIRY_DATE] [--no-password]"
  echo
  echo "  -u  Login name (required)"
  echo "  -g  Comma-separated groups (e.g., sudo,developers)"
  echo "  -e  Expiry date in YYYY-MM-DD format"
  echo "  --no-password  Don't prompt for password"
  echo
  echo "Example: $0 -u alice -g sudo -e 2025-12-31"
}

# --- Default values
USERNAME=""
GROUPS=""
EXPIRY=""
NO_PASS=false

# --- Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u) USERNAME="$2"; shift 2;;
    -g) GROUPS="$2"; shift 2;;
    -e) EXPIRY="$2"; shift 2;;
    --no-password) NO_PASS=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

# --- Validate
if [[ -z "$USERNAME" ]]; then
  echo "❌ Error: Username is required."
  usage
  exit 1
fi

# --- Build useradd command
CMD=(sudo useradd -m -s /bin/bash)

[[ -n "$GROUPS" ]] && CMD+=(-G "$GROUPS")
[[ -n "$EXPIRY" ]] && CMD+=(-e "$EXPIRY")

CMD+=("$USERNAME")

# --- Run it
echo "➕ Creating user: $USERNAME"
"${CMD[@]}"

# --- Set password
if $NO_PASS; then
  echo "⚠️ User created without password. Login is locked until set."
else
  echo "🔐 Set password for $USERNAME:"
  sudo passwd "$USERNAME"
fi

echo "✅ User '$USERNAME' successfully created."
