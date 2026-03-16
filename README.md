# OpenCode Setup

An OpenCode environment with peon-ping sound notifications, with optional Icecast2 + ffmpeg audio stream for remote playback.

## Prerequisites
- Windows with WSL or Debian/Ubuntu system
- `sudo` access

## Install

```bash
./installopencode.sh
```

What it does:

1. Installs the [OpenCode](https://opencode.ai) CLI
1. Installs the [peon-ping](https://github.com/PeonPing/peon-ping) sound plugin and its OpenCode adapter
1. Installs system dependencies: `pulseaudio`, `pulseaudio-utils`, `ffmpeg`, `icecast2`
1. Patches the peon-ping plugin to write the current tab title to `/tmp/peon-title`

## Start

```bash
./startopencode.sh
```

What it does:

1. Sources `~/.env` for configuration (see [Configuration](#configuration))
2. Starts the Icecast2 streaming server
3. Creates a PulseAudio virtual null sink (`peon_sink`) and routes it to the RDP speaker output
4. Streams audio from `peon_sink` to Icecast via `ffmpeg` (MP3, 128k) — log at `/tmp/ffmpeg-peon.log`
5. Starts `opencode serve` in the background
6. Polls `/tmp/peon-title` and `/tmp/opencode-title` to keep the terminal tab title up to date

## Configuration

The start script reads the following environment variables from `~/.env`:

| Variable | Default | Description |
|---|---|---|
| `ICECAST_SOURCE_PASSWORD` | `hackme` | Icecast2 source password |
| `ICECAST_HOST` | `localhost` | Icecast2 host |
| `ICECAST_PORT` | `8000` | Icecast2 port |
| `ICECAST_MOUNT` | `/peon` | Icecast2 mount point |

## Peon-ping

[peon-ping](https://github.com/PeonPing/peon-ping) is a sound plugin for OpenCode that plays audio cues during coding events (task complete, errors, permission prompts, etc.). It supports multiple voice packs and is configured via the OpenCode plugin system. Refer to the peon-ping docs for details on switching voice packs and adjusting settings.
