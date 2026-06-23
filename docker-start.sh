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

if [ "${1:-}" = "setup" ]; then
    shift
    exec /bridge/bridge -c "$@"
fi

exec /bridge/bridge -n -l=info "$@"
