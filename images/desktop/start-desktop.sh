#!/usr/bin/env bash
set -euo pipefail

VNC_PW="${VNC_PW:-changeme}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1600x900}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-24}"
DISPLAY="${DISPLAY:-:1}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6901}"

export DISPLAY
mkdir -p "$HOME/.vnc"

printf "%s\n%s\n\n" "$VNC_PW" "$VNC_PW" | vncpasswd

cat > "$HOME/.vnc/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x "$HOME/.vnc/xstartup"

vncserver "$DISPLAY" -geometry "$VNC_RESOLUTION" -depth "$VNC_COL_DEPTH" -localhost no
websockify --web=/usr/share/novnc/ "$NOVNC_PORT" "localhost:${VNC_PORT}" &

echo "noVNC: /user/<name>/proxy/${NOVNC_PORT}/"
tail -f /dev/null
