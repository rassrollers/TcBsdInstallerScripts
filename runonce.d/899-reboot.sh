#!/bin/sh

set -e
set -u

echo "[899-reboot] INFO: Preparing stage 2 for after the reboot of the system"
if [ -f /var/runonce-stage2/900-create-factoryreset.sh ]; then
    mv /var/runonce-stage2/900-create-factoryreset.sh /var/runonce/
    chmod +x /var/runonce/900-create-factoryreset.sh
    echo "[899-reboot] DEBUG: Restorepoint script moved into runonce."
fi

echo "[899-reboot] INFO: Rebooting the system"
reboot
