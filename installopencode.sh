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

echo "[install] Patching peon-ping WSL audio to route through PulseAudio (peon_sink)..."
python3 - ~/.config/opencode/plugins/peon-ping.ts <<'PYEOF'
import sys

path = sys.argv[1]
content = open(path).read()

MARKER = "if (isWSL) {"

if content.count(MARKER) != 1:
    print(f"[warn] WSL audio patch: expected exactly 1 occurrence of '{MARKER}', found {content.count(MARKER)}. Skipping.")
    sys.exit(0)

start = content.index(MARKER)
i = start + len(MARKER)
depth = 1
while i < len(content) and depth > 0:
    if content[i] == "{":
        depth += 1
    elif content[i] == "}":
        depth -= 1
    i += 1

rest = content[i:].lstrip()
if not rest.startswith("} else {") and not rest.startswith("else {"):
    print(f"[warn] WSL audio patch: unexpected structure after isWSL block. Found: {repr(rest[:30])}. Skipping.")
    sys.exit(0)

NEW_BLOCK = """if (isWSL) {
        // Route audio through the WSL PulseAudio server so it hits peon_sink,
        // which feeds both the local RDP loopback (speakers) and the Icecast stream.
      const pulseServer = process.env.PULSE_SERVER ?? "unix:/mnt/wslg/PulseServer"
      const paVol = Math.round(Math.max(0, Math.min(65536, volume * 65536)))
      const env = { ...process.env, PULSE_SERVER: pulseServer }
	  
      const pulsePlayed = (() => {
        const backends: string[][] = [
          ["pw-play", "--volume", String(volume), filePath],
          ["paplay", `--volume=${paVol}`, filePath],
        ]
        for (const args of backends) {
          try {
            const which = Bun.spawnSync(["which", args[0]], { stdout: "pipe", stderr: "ignore" })
            if (which.exitCode !== 0) continue
            const proc = Bun.spawn(args, { env, stdout: "ignore", stderr: "ignore" })
            proc.unref()
            return true
          } catch {}
        }
        return false
      })()
	  
      if (!pulsePlayed) {
        // Fallback: play directly on the Windows host via PowerShell (not captured by Icecast)
        const distro = process.env.WSL_DISTRO_NAME ?? "Ubuntu"
        const uri = `file:////wsl.localhost/${distro}${filePath}`
        const cmd = [
          "Add-Type -AssemblyName PresentationCore",
          `$p = New-Object System.Windows.Media.MediaPlayer`,
          `$p.Open([Uri]::new('${uri}'))`,
          `$p.Volume = ${volume}`,
          "Start-Sleep -Milliseconds 200",
          "$p.Play()",
          "Start-Sleep -Seconds 3",
          "$p.Close()",
        ].join("; ")
        const proc = Bun.spawn(
          ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", cmd],
          { stdout: "ignore", stderr: "ignore" },
        )
        proc.unref()
      }
    }"""

open(path, "w").write(content[:start] + NEW_BLOCK + content[i:])
print("[ok] WSL audio patch applied.")
PYEOF

echo "[install] Done. Run ./start.sh to start everything."