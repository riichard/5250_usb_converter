#!/bin/bash
# Install the ibm5250 systemd service on a Raspberry Pi (or similar Linux system).
# Run as root or with sudo.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_USER="${SERVICE_USER:-pi}"
INSTALL_DIR="/home/${SERVICE_USER}/dev/5250_usb_converter"
SERVICE_FILE="ibm5250.service"
SUDOERS_FILE="/etc/sudoers.d/ibm5250"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (e.g. sudo $0)"
    exit 1
fi

echo "==> Installing ibm5250 systemd service"
echo "    Service user : ${SERVICE_USER}"
echo "    Install dir  : ${INSTALL_DIR}"

# Copy service file, substituting the actual install dir and user
sed \
    -e "s|/home/pi/dev/5250_usb_converter|${INSTALL_DIR}|g" \
    -e "s|User=pi|User=${SERVICE_USER}|g" \
    "${SCRIPT_DIR}/${SERVICE_FILE}" \
    > "/lib/systemd/system/${SERVICE_FILE}"

echo "==> Copied ${SERVICE_FILE} to /lib/systemd/system/"

# Grant the service user passwordless systemctl access for this service
cat > "${SUDOERS_FILE}" << EOF
${SERVICE_USER} ALL=(ALL) NOPASSWD: /bin/systemctl start ${SERVICE_FILE}
${SERVICE_USER} ALL=(ALL) NOPASSWD: /bin/systemctl stop ${SERVICE_FILE}
${SERVICE_USER} ALL=(ALL) NOPASSWD: /bin/systemctl restart ${SERVICE_FILE}
${SERVICE_USER} ALL=(ALL) NOPASSWD: /bin/systemctl status ${SERVICE_FILE}
${SERVICE_USER} ALL=(ALL) NOPASSWD: /bin/systemctl daemon-reload
${SERVICE_USER} ALL=(ALL) NOPASSWD: /usr/bin/journalctl -u ${SERVICE_FILE}
${SERVICE_USER} ALL=(ALL) NOPASSWD: /usr/bin/journalctl -u ${SERVICE_FILE} -f
${SERVICE_USER} ALL=(ALL) NOPASSWD: /usr/bin/journalctl -u ${SERVICE_FILE} -n *
EOF
chmod 440 "${SUDOERS_FILE}"
visudo -c -f "${SUDOERS_FILE}"
echo "==> Created ${SUDOERS_FILE} (passwordless systemctl for ${SERVICE_USER})"

install -m 755 "${REPO_DIR}/etc/kbdhelp" /usr/local/bin/kbdhelp
echo "==> Installed kbdhelp to /usr/local/bin/"

systemctl daemon-reload
systemctl enable "${SERVICE_FILE}"
systemctl start "${SERVICE_FILE}"

echo ""
echo "==> Done. Service status:"
systemctl status "${SERVICE_FILE}" --no-pager || true
echo ""
echo "Useful commands:"
echo "  journalctl -u ibm5250.service -f        # follow live logs"
echo "  sudo systemctl restart ibm5250.service  # restart the service"
