#!/bin/bash
set -e

# Proton Mail Bridge — Docker startup script
#
# Default mode runs the bridge headless (IMAP/SMTP server only).
#
# To add/manage accounts interactively, use the "setup" command:
#   docker run --rm -it -v ./data:/data proton-bridge setup
# Then type "login" and follow the prompts.
#
# You CANNOT run setup while the headless server is running because
# Proton Bridge uses a single-instance lock file. Stop the server first
# or run setup in a separate throwaway container as shown above.

# Ensure pass password manager is initialized so the bridge has a usable keychain.
export GNUPGHOME=/data/gnupg
export PASSWORD_STORE_DIR=/data/pass
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

if [ -z "$(gpg --list-keys --with-colons 2>/dev/null | grep fpr)" ]; then
    gpg --batch --passphrase '' --quick-gen-key 'Proton Bridge <bridge@localhost>' default default 2>/dev/null
fi

if [ ! -f "$PASSWORD_STORE_DIR/.gpg-id" ]; then
    KEY_ID=$(gpg --list-keys --with-colons 2>/dev/null | grep fpr | head -1 | cut -d: -f10)
    if [ -n "$KEY_ID" ]; then
        pass init "$KEY_ID" 2>/dev/null
    fi
fi

if [ "${1:-}" = "setup" ]; then
    shift
    exec /bridge/bridge -c "$@"
fi

exec /bridge/bridge -n -l=info "$@"
