#!/bin/bash
set -e

# Default: audio enabled
ENABLE_AUDIO=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-audio)
      ENABLE_AUDIO=false
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --no-audio    Disable Icecast and PulseAudio streaming"
      echo "  --help, -h    Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

if [ -f ~/.env ]; then
  source ~/.env
fi

# Configuration
ICECAST_SOURCE_PASSWORD="${ICECAST_SOURCE_PASSWORD:-hackme}"
ICECAST_HOST="${ICECAST_HOST:-localhost}"
ICECAST_PORT="${ICECAST_PORT:-8000}"
ICECAST_MOUNT="${ICECAST_MOUNT:-/peon}"

if [ "$ENABLE_AUDIO" = true ]; then
  echo "[icecast] Starting Icecast2..."
  sudo service icecast2 start

  echo "[pulseaudio] Cleaning up old sinks..."
  PULSE_SERVER=unix:/mnt/wslg/PulseServer pactl unload-module module-null-sink 2>/dev/null || true
  PULSE_SERVER=unix:/mnt/wslg/PulseServer pactl unload-module module-loopback 2>/dev/null || true

  echo "[pulseaudio] Creating null sink..."
  PULSE_SERVER=unix:/mnt/wslg/PulseServer pactl load-module module-null-sink sink_name=peon_sink sink_properties=device.description="Peon-Sink"
  PULSE_SERVER=unix:/mnt/wslg/PulseServer pactl set-default-sink peon_sink

  echo "[pulseaudio] Routing to speakers..."
  PULSE_SERVER=unix:/mnt/wslg/PulseServer pactl load-module module-loopback source=peon_sink.monitor sink=RDPSink

  echo "[ffmpeg] Starting stream to Icecast..."
  PULSE_SERVER=unix:/mnt/wslg/PulseServer ffmpeg \
    -f pulse \
    -fragment_size 512 \
    -i peon_sink.monitor \
    -c:a libmp3lame \
    -b:a 128k \
    -ar 44100 \
    -ac 2 \
    -f mp3 \
    -bufsize 64k \
    -reconnect 1 \
    -reconnect_streamed 1 \
    -reconnect_delay_max 5 \
    -fflags nobuffer \
    -flags low_delay \
    -flush_packets 1 \
    "icecast://source:${ICECAST_SOURCE_PASSWORD}@${ICECAST_HOST}:${ICECAST_PORT}${ICECAST_MOUNT}" \
    > /tmp/ffmpeg-peon.log 2>&1 &

  echo "[ffmpeg] Streaming (log: /tmp/ffmpeg-peon.log)"
else
  echo "[audio] Audio streaming disabled"
fi

echo "[opencode] Starting OpenCode server..."
if pgrep -x "opencode" > /dev/null; then
  echo "[opencode] Already running, skipping..."
else
  opencode serve &
  OPENCODE_PID=$!
fi

PREV_TITLE=''
while kill -0 $OPENCODE_PID 2>/dev/null; do
  if [ -f /tmp/peon-title ] && [ /tmp/peon-title -nt /tmp/opencode-title ]; then
    CURRENT_TITLE=$(cat /tmp/peon-title 2>/dev/null || echo '')
  else
    CURRENT_TITLE=$(cat /tmp/opencode-title 2>/dev/null || echo '')
  fi
  
  echo -ne "\033]0;🔨 OpenCode\007"
  sleep 2
  
  if [ -n "$CURRENT_TITLE" ] && [ "$CURRENT_TITLE" != "$PREV_TITLE" ]; then
    echo -ne "\033]0;🔨 OpenCode - ${CURRENT_TITLE}\007"
    PREV_TITLE="$CURRENT_TITLE"
  fi
  sleep 2
done