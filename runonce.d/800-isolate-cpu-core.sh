#!/bin/sh

set -e
set -u

# Number of CPU cores to be shared (non-realtime). Remaining cores are isolated for TwinCAT.
# Check your target PLC's CPU core count and adjust this value accordingly.
# Requires a reboot to take effect.
SHARED_CORES=2

echo "[800-isolate-cpu-core] INFO: Sharing ${SHARED_CORES} CPU core(s)"
TcCoreConf -s ${SHARED_CORES}
