# Proton Mail Bridge — Docker Setup

> This is a minimal, headless Docker image for Proton Mail Bridge. It builds the official bridge binary without the Qt GUI and runs it as an IMAP/SMTP server inside a container.

## Quick Start

```bash
docker compose up -d
```

The container will start on the default ports:

- **IMAP:** `1143`
- **SMTP:** `1025`

## First-Time Login

Proton Bridge uses a single-instance file lock. You **cannot** run the interactive CLI while the headless server is already running.

### Option 1: One-shot setup container (recommended)

```bash
# Run an interactive setup container that shares the same data volume
docker run --rm -it \
  -v "$(pwd)/data:/data" \
  ghcr.io/<your-username>/proton-bridge:latest \
  setup
```

Inside the shell:

```
>>> login
Username: your-username@proton.me
Password: your-password
# Follow any 2FA prompts if applicable
>>> exit
```

Then start the server:

```bash
docker compose up -d
```

### Option 2: Stop the server, set up, then restart

```bash
docker compose down
docker compose run --rm proton-bridge setup
# ...login interactively...
docker compose up -d
```

## Building the Image Locally

```bash
docker build -t proton-bridge .
```

Or with Buildx:

```bash
docker buildx build --platform linux/amd64 -t proton-bridge .
```

## Configuration

All persistent data lives under `/data` via a single volume mount:

| Path inside container | Purpose |
|---|---|
| `/data/config` | Vault, settings, TLS certs |
| `/data/data` | Logs, gluon DB, message cache |
| `/data/cache` | Bridge lock files, feature flag caches |

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `XDG_CONFIG_HOME` | `/data/config` | Config root |
| `XDG_DATA_HOME` | `/data/data` | Data root |
| `XDG_CACHE_HOME` | `/data/cache` | Cache root |

### Ports

| Port | Protocol | Notes |
|---|---|---|
| `1143` | IMAP | Bridge scans upward if occupied |
| `1025` | SMTP | Bridge scans upward if occupied |

If the defaults are taken, check the container logs for the actual ports:

```bash
docker logs proton-bridge | grep -i "port"
```

## Keeping Up with Upstream

This repo is intended to be a fork of the official Proton Bridge repository. To sync with upstream:

```bash
# Add the upstream remote (one-time)
git remote add upstream https://github.com/ProtonMail/proton-bridge.git

# Fetch and merge
git fetch upstream
git merge upstream/main
git push origin main
```

Pushing the merge triggers the GitHub Actions workflow, which rebuilds and publishes the image automatically.

## GitHub Container Registry

The included workflow publishes to:

```
ghcr.io/<your-username>/proton-bridge:latest
```

Make sure **Actions** and **Packages** are enabled in your fork's repository settings.

## Troubleshooting

### "Failed to create lock file; another instance is already running"
You tried to run `setup` while the headless server was already running. Stop it first:

```bash
docker compose down
```

### "Could not create keychain: no keychain"
This is expected in a headless container. The bridge falls back to an **insecure vault** stored under `/data/config/.../insecure/`. The vault is still encrypted on disk but uses a predictable key since no system keychain is available. This is the same behavior as other headless bridge containers.

### "This version of the app is no longer supported"
The workflow hardcodes a version string during build. If Proton starts rejecting it, update the `BRIDGE_APP_VERSION` build arg in the Dockerfile or the `ldflags` version string.

### "This version of the app is no longer supported" (feature flags)
If the bridge starts but logs warnings about unsupported versions, it usually still works. The warning comes from Proton's feature flag API and does not block IMAP/SMTP functionality.
