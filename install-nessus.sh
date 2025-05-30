#!/bin/sh

set -eu

CAN_ROOT=
SUDO=
if [ "$(id -u)" = 0 ]; then
  CAN_ROOT=1
  SUDO=""
elif type sudo >/dev/null; then
  CAN_ROOT=1
  SUDO="sudo"
fi

if [ "$CAN_ROOT" != "1" ]; then
  echo "This installer needs to run commands as root."
  echo "We tried looking for 'sudo', but couldn't find it."
  echo "Either re-run this script as root, or set up sudo."
  exit 1
fi

file=$(curl -fsSL "https://www.tenable.com/downloads/nessus?loginAttempted=true" | grep -ohE "Nessus-[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+-debian1[[:digit:]]_amd64\.deb" | head -n1)

url="https://www.tenable.com/downloads/api/v2/pages/nessus/files/$file"

curl -fsLo /tmp/nessus.deb "$url"

$SUDO dpkg -i /tmp/nessus.deb

rm /tmp/nessus.deb

$SUDO systemctl enable nessusd
