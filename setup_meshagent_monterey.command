#!/bin/bash
# MeshCentral agent installer for macOS 12.x Monterey (Intel).
# Downloads a fresh invite, installs the official agent package, configures
# launchd with --disableUpdate=1 and verifies the portal connection.
#
# Download and run in one line (Terminal):
#   curl -fsSL https://raw.githubusercontent.com/kualkon/MeshCentral/refs/heads/opencode/monterey-installer/setup_meshagent_monterey.command -o /tmp/setup_meshagent_monterey.command && bash /tmp/setup_meshagent_monterey.command
#
# Or paste the one directly:
#   curl -fsSL https://raw.githubusercontent.com/kualkon/MeshCentral/refs/heads/opencode/monterey-installer/setup_meshagent_monterey.command | bash
set -euo pipefail

PORTAL="support.kualkon.top"
INVITE_URL='https://support.kualkon.top/agentinvite?c=fAcKPBtL5y7RwyzOXEIy3NAGrS5iLG4cketkejoFbqwZx$77I83tJeeL4RxaZtMjj$MQ2zlH0QZvqXo1KtCakfvYPrWBw6QdgPHgZgmKdY6FMWRLOXGRj101hZh520b74eV4V3tOjZPqk$DxUdl5gj@jxF2GdHMkVd$fZ1EzpyZXb7TX7r0VaPf9$8mCbXJ4RK6mW6wz$U8zASs@'
SELF_URL='https://raw.githubusercontent.com/kualkon/MeshCentral/refs/heads/opencode/monterey-installer/setup_meshagent_monterey.command'
ARCHID=16

DAEMON_PLIST='/Library/LaunchDaemons/meshagent.plist'
AGENT_PLIST='/Library/LaunchAgents/meshagent-launchagent.plist'
INSTALL_DIR='/usr/local/mesh_services/meshagent/meshagent'

# --- elevate once -----------------------------------------------------------
# `sudo bash "$0"` works even if the downloaded file lost its executable bit.
# When piped from curl, download a copy to /tmp first, then run it as root.
if [ "$(id -u)" -ne 0 ]; then
  echo "Requesting administrator privileges..."
  if [ -f "$0" ]; then
    exec sudo bash "$0" "$@"
  fi
  curl -fsSL --retry 3 --connect-timeout 20 "$SELF_URL" -o /tmp/setup_meshagent_monterey.command
  exec sudo bash /tmp/setup_meshagent_monterey.command "$@"
fi

echo "=========================================================="
echo " MeshCentral agent installer - macOS Monterey (12.x, Intel)"
echo "=========================================================="
OS_VERSION="$(sw_vers -productVersion)"
OS_MAJOR="${OS_VERSION%%.*}"
echo "Detected macOS ${OS_VERSION} ($(uname -m))"
if [ "$OS_MAJOR" != "12" ]; then
  echo "WARNING: этот скрипт предназначен для macOS 12.x Monterey. Продолжаем."
fi
if [ "$(uname -m)" != "x86_64" ] || [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ]; then
  echo "ERROR: Intel x86-64 required (ARCHID ${ARCHID}). Apple Silicon needs ARCHID 29/10005." >&2
  exit 1
fi
echo

# --- already healthy? -------------------------------------------------------
if launchctl print system/meshagent 2>/dev/null | grep -q 'state = running'; then
  PID=$(launchctl print system/meshagent 2>/dev/null | awk '/pid = /{print $3; exit}')
  if [ -n "${PID:-}" ] && lsof -nP -iTCP -a -p "$PID" 2>/dev/null | grep -q "ESTABLISHED"; then
    echo "Agent is already running and connected (PID $PID). Nothing to do."
    exit 0
  fi
fi

TMP="$(mktemp -d /tmp/meshagent-install.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# --- stop whatever is there -------------------------------------------------
CONSOLE_UID="$(stat -f '%u' /dev/console 2>/dev/null || echo 501)"
launchctl bootout system "$DAEMON_PLIST" >/dev/null 2>&1 || true
launchctl bootout "gui/${CONSOLE_UID}" "$AGENT_PLIST" >/dev/null 2>&1 || true
sleep 1

# --- download ---------------------------------------------------------------
# The invite page issues a fresh, short-lived meshid each time it is opened,
# so it must be read at runtime instead of being hardcoded.
echo "Reading a fresh agent invitation from ${PORTAL} ..."
curl -fsSL --retry 3 --connect-timeout 20 -o "$TMP/invite.html" "$INVITE_URL"
MESHID="$(grep -oE "var meshid = '[^']*'" "$TMP/invite.html" | head -1 | sed "s/var meshid = '//; s/'$//")"
if [ -z "$MESHID" ]; then
  echo "ERROR: could not read meshid from the invitation page" >&2
  exit 1
fi
AGENT_URL="https://${PORTAL}/meshosxagent?id=${ARCHID}&meshid=${MESHID}"
echo "Downloading agent (Intel, ARCHID ${ARCHID}) from ${PORTAL} ..."
curl -fL --retry 3 --connect-timeout 20 -o "$TMP/agent.zip" "$AGENT_URL"
unzip -oq "$TMP/agent.zip" -d "$TMP/agent"

PKG="$(find "$TMP/agent" -maxdepth 2 -name 'MeshAgent.pkg' -print -quit)"
if [ -z "$PKG" ]; then
  echo "ERROR: MeshAgent.pkg not found in the downloaded archive" >&2
  exit 1
fi

# --- install package --------------------------------------------------------
echo "Installing package ..."
installer -pkg "$PKG" -target /

# --- write LaunchDaemon (with --disableUpdate=1) ----------------------------
cat > "$DAEMON_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>meshagent</string>
    <key>ProgramArguments</key>
    <array>
      <string>/usr/local/mesh_services/meshagent/meshagent/meshagent</string>
      <string>--disableUpdate=1</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/usr/local/mesh_services/meshagent/meshagent/</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>1</integer>
  </dict>
</plist>
EOF

# --- disable the auxiliary launch agent ------------------------------------
# It can crash with EX_CONFIG; the system daemon provides the portal link.
cat > "$AGENT_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Disabled</key>
    <true/>
    <key>Label</key>
    <string>meshagent-launchagent</string>
    <key>ProgramArguments</key>
    <array>
      <string>/usr/local/mesh_services/meshagent/meshagent/meshagent</string>
      <string>--disableUpdate=1</string>
      <string>-kvmagent</string>
    </array>
    <key>LimitLoadToSessionType</key>
    <array>
      <string>LoginWindow</string>
      <string>Aqua</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/usr/local/mesh_services/meshagent/meshagent/</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
  </dict>
</plist>
EOF

chown root:wheel "$DAEMON_PLIST" "$AGENT_PLIST"
chmod 644 "$DAEMON_PLIST" "$AGENT_PLIST"
chown -R root:wheel /usr/local/mesh_services/meshagent
xattr -dr com.apple.quarantine /usr/local/mesh_services/meshagent >/dev/null 2>&1 || true

# --- start service ----------------------------------------------------------
# The package postinstall may already have loaded a service. Unload it after
# replacing the plist, then bootstrap ours.
echo "Starting service ..."
launchctl bootout system "$DAEMON_PLIST" >/dev/null 2>&1 || true
sleep 1
launchctl bootstrap system "$DAEMON_PLIST"
sleep 6

# --- verify -----------------------------------------------------------------
echo
echo "--- verification ---"
launchctl print system/meshagent 2>/dev/null | grep -E 'state =|pid =|successive crashes' || true
PID="$(pgrep -f "${INSTALL_DIR}/meshagent --disableUpdate=1" | head -1 || true)"
if [ -n "$PID" ]; then
  lsof -nP -iTCP -a -p "$PID" 2>/dev/null | grep ESTABLISHED || true
fi
echo
echo "Done. Check the device in MeshCentral (group Test)."
