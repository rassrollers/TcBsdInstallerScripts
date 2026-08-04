#!/bin/sh

set -e
set -u

# AMS NetID for target TwinCAT system.
# Is defined in HEX format. (e.g. C0A8010A0101 = 192.168.1.10.1.1)
AMSNETID=C0A8010A0101
# ADS router memory size in bytes (default: 32MB)
ROUTER_MEM=33554432
# Heap memory size in MB (default: 128MB)
HEAP_MEM_MB=128

echo "[810-tcRegistry-setup] INFO: Setting up TcRegistry.xml file"
if ! service TcSystemService status > /dev/null 2>&1; then
    echo "[810-tcRegistry-setup] DEBUG: Starting TwinCAT system service"
    service TcSystemService start
else
    echo "[810-tcRegistry-setup] DEBUG: TwinCAT system service is already running"
fi

if [ -f "/usr/local/etc/TwinCAT/3.1/TcRegistry.xml" ]; then
    echo "[810-tcRegistry-setup] DEBUG: File exists: /usr/local/etc/TwinCAT/3.1/TcRegistry.xml"
    insert_block="<Key Name=\"System\">\\
    <Value Name=\"AmsNetId\" Type=\"BIN\">${AMSNETID}</Value>\\
    <Value Name=\"LockedMemSize\" Type=\"DW\">${ROUTER_MEM}</Value>\\
    <Value Name=\"SysStartupState\" Type=\"DW\">5</Value>\\
    <Value Name=\"HeapMemSizeMB\" Type=\"DW\">${HEAP_MEM_MB}</Value>\\
    <Value Name=\"LogMessageType\" Type=\"DW\">4</Value>\\
</Key>"
    sed -i '' "/<Key Name=\"TwinCAT3\">/a\\
${insert_block}" "/usr/local/etc/TwinCAT/3.1/TcRegistry.xml"
else
    echo "[810-tcRegistry-setup] ERROR: File does not exist: /usr/local/etc/TwinCAT/3.1/TcRegistry.xml"
    exit 1
fi

echo "[810-tcRegistry-setup] INFO: Done setting up TcRegistry.xml"
