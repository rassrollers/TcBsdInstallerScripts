#!/bin/sh

set -e
set -u

echo "[820-install-packages] INFO: Starting TwinCAT system service to ensure package installation can proceed"
if ! service TcSystemService status > /dev/null 2>&1; then
    echo "[820-install-packages] DEBUG: Starting TwinCAT system service"
    service TcSystemService start
else
    echo "[820-install-packages] DEBUG: TwinCAT system service is already running"
fi

echo "[820-install-packages] INFO: Install packages"
pkgs=$(ls /tmp/*.pkg 2>/dev/null)
if [ -n "$pkgs" ]; then
    echo "[820-install-packages] DEBUG: Installing packages from /tmp..."
    if pkg add $pkgs; then
        echo "[820-install-packages] INFO: Successfully installed all packages"
    else
        echo "[820-install-packages] ERROR: One or more packages failed to install"
    fi
else
    echo "[820-install-packages] INFO: No packages to install in /tmp"
fi
