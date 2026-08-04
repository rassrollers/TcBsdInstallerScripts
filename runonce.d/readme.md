# runonce

**The scripts are run in order of the numbering.**

runonce is a boot-time service that guarantees one-time execution of scripts dropped in /var/runonce/, with automatic logging, result tracking, and safe continuation even if a reboot happens mid-sequence.

A newly flashed USB installer will contain the `900-create-factoryreset.sh` script that will create a restore point as the last part of the installation. This script must be the last script to run.

The reboot script `899-reboot.sh` will reboot the system after the TcCoreConf and packages installation for it to take effect.