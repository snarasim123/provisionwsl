#!/bin/bash
###############################################################
# start-desktop.sh - Start a desktop session via XWayland
# Usage: sudo start-desktop.sh [mate|wmaker|xfce|stop]
#   stop  ends the desktop and returns to multi-user target
#   No argument starts the session currently configured.
# Switching while a desktop is running restarts LightDM.
# To stop: sudo poweroff  (from GUI or terminal)
###############################################################
set -e

CONF=/etc/lightdm/lightdm.conf.d/50-desktop-session.conf
XSESSIONS=/usr/share/xsessions

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 $*" >&2
  exit 1
fi

if [ "$1" = "stop" ]; then
  echo "Stopping desktop..."
  systemctl isolate multi-user.target
  exit 0
fi

session="$1"
if [ -n "$session" ]; then
  if [ ! -f "$XSESSIONS/$session.desktop" ]; then
    echo "Unknown session '$session'. Available:" >&2
    ls "$XSESSIONS" | sed 's/\.desktop$//' | sed 's/^/  /' >&2
    exit 1
  fi
  mkdir -p "$(dirname "$CONF")"
  # autologin-session applies only with autologin; user-session is the default
  # the greeter preselects.
  printf '[Seat:*]\nautologin-session=%s\nuser-session=%s\n' "$session" "$session" > "$CONF"

  # The greeter prefers the user's saved session over user-session, so update that too.
  user="${SUDO_USER:-}"
  if [ -n "$user" ] && [ "$user" != root ]; then
    home=$(getent passwd "$user" | cut -d: -f6)
    printf '[Desktop]\nSession=%s\n' "$session" > "$home/.dmrc"
    chown "$user": "$home/.dmrc"
    acct="/var/lib/AccountsService/users/$user"
    if [ -f "$acct" ]; then
      if grep -q '^XSession=' "$acct"; then
        sed -i "s/^XSession=.*/XSession=$session/" "$acct"
      else
        sed -i "/^\[User\]/a XSession=$session" "$acct"
      fi
    fi
  fi
  echo "Session set to $session"
fi

if systemctl is-active --quiet lightdm; then
  echo "Restarting LightDM..."
  systemctl restart lightdm
else
  echo "Starting graphical target..."
  systemctl start graphical.target
fi
echo "Desktop is running. Use 'sudo poweroff' to shut down cleanly."
