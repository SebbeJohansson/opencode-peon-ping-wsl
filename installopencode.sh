#!/bin/bash
set -e

echo "[install] Updating apt..."
sudo apt update

echo "[install] Installing dependencies..."
sudo apt install -y pulseaudio pulseaudio-utils ffmpeg icecast2

echo "[install] Installing OpenCode..."
curl -fsSL https://opencode.ai/install | bash

echo "[install] Installing peon-ping..."
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash

echo "[install] Installing peon-ping OpenCode adapter..."
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh | bash

echo "[install] Patching peon-ping tab title to write to file..."
sed -i 's|process.stdout.write(`\\x1b]0;${title}\\x07`)|process.stdout.write(`\\x1b]0;${title}\\x07`); fs.writeFileSync("/tmp/peon-title", title, "utf8")|' ~/.config/opencode/plugins/peon-ping.ts

echo "[install] Done. Run ./start.sh to start everything."
