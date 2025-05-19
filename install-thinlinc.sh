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

url=$(curl -fsSL https://www.cendio.com/thinlinc/download/ | grep -ohE "https://.*/tl-[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+-server.zip" | head -n1)

echo "Downloading from $url"
curl -fsLo /tmp/tl-setup.zip "$url"

debfile=$(unzip -d /tmp/tl-setup /tmp/tl-setup.zip | grep "amd64.deb" | cut -d ":" -f2 | xargs)

$SUDO dpkg -i $debfile

cat > /tmp/tl-setup.answers << 'END'
install-gtk=no
email-address=noreply@turingpoint.de
install-python-ldap=no
setup-firewall=yes
setup-selinux=yes
setup-web-integration=yes
setup-apparmor=yes
server-type=master
missing-answer=abort
install-nfs=no
install-sshd=no
accept-eula=yes
migrate-conf=no
install-required-libs=yes
setup-nearest=no
setup-thinlocal=no
agent-hostname-choice=hostname
END

echo "tlwebadm-password=$(openssl rand -hex 12)" >> /tmp/tl-setup.answers

echo "Running thinlinc setup"
$SUDO /opt/thinlinc/sbin/tl-setup -a /tmp/tl-setup.answers

if [ -x "$(command -v tailscale)" ]; then
  tailscaleip="$(tailscale ip -4 | grep -ohE '^100\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$')"
  if [ -z $tailscaleip ]; then
    echo "tailscale is not connected"
  else
    echo "Setting tailscale hostnames to $tailscaleip"
    tshostname="$(tailscale status | grep -ohE "[[:space:]][[:alnum:]]+\..+\.ts\.net" | xargs)"
    $SUDO perl -pi -e "s/master_hostname=.*/master_hostname=$tailscaleip/g" /opt/thinlinc/etc/conf.d/vsmagent.hconf
    $SUDO perl -pi -e "s/agent_hostname=.*/agent_hostname=$tailscaleip/g" /opt/thinlinc/etc/conf.d/vsmagent.hconf
    $SUDO systemctl restart vsmagent
  fi
fi

echo "Cleanup"
rm /tmp/tl-setup.answers
rm -rf /tmp/tl-setup
rm /tmp/tl-setup.zip
