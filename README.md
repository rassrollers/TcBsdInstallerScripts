# TcBsdInstallerScripts

Template scripts for configuring TC/BSD during the install process with the USB installer.

**This works for TC/BSD 13.2.0.6 and newer.**

## Usage

Copy the desired template scripts to the `INSTALLER/` directory on the TC/BSD USB installer and modify them. The installer will pick them up and execute them automatically during installation.

Scripts are executed in ascending numerical order within each stage.

## Directory structure on the USB

```
INSTALLER/
├── .ssh/               ← place your public SSH key here to enable SSH access to the installer
├── autorun/            ← scripts run automatically before the installer main menu is shown (alphabetical order)
├── autorun_samples/    ← built-in sample scripts; copy a sample folder's contents to autorun/ to activate it
├── logs/               ← log output from autorun scripts
├── post_install.d/     ← scripts run during OS installation
│   ├── *.installer     → runs in the live installer environment (works on /mnt)
│   └── *.chroot        → runs inside the newly installed system (chroot /mnt)
├── runonce.d/          ← scripts run once on first boot of the installed system
│   └── *.sh
└── packages/           ← optional: .pkg files to install (required by 130/840)
```

## SSH access

Copy your public key to `INSTALLER/.ssh/authorized_keys` file on the USB.
The public key will be copied to the target PLC in the `/home/Administrator/.ssh` directory.
This also allows you to use SSH during installation process with the `start_ssh_server` sample

## autorun scripts

Scripts placed in `INSTALLER/autorun/` run automatically before the installer main menu appears, in alphabetical order. Use these for pre-installation tasks such as starting SSH or triggering an unattended install.

Built-in samples in `INSTALLER/autorun_samples/`:

| Sample | Description |
|---|---|
| `start_ssh_server` | Starts the SSH daemon so the installer is reachable over the network |
| `autoinstall_tcbsd` | Installs TC/BSD unattended onto the largest disk (disk and password configurable) |
| `auto_backup` | Backs up an existing TC/BSD system to the USB unattended |
| `auto_restore` | Restores a TC/BSD backup from the USB unattended |

## post_install.d template scripts

| Script | Type | Required | Description |
|---|---|---|---|
| `120-runonce-setup.chroot` | chroot | **Yes** | Makes runonce scripts executable so they run on first boot |
| `130-copy-packages.installer` | installer | No† | Copies `.pkg` files from `INSTALLER/packages/` to `/tmp` on the new system |
| `140-network-setup.chroot` | chroot | No | Configures static IP addresses and DHCP settings |
| `150-firewall-setup.chroot` | chroot | No | Enables/disables `pf` firewall and appends rules to `pf.conf` |
| `160-ntp-setup.chroot` | chroot | No | Configures NTP server |
| `170-login-template.chroot` | chroot | No | Configures login settings |
| `180-keyboard-layout.chroot` | chroot | No | Sets the keyboard layout in `rc.conf` |

† `130-copy-packages.installer` and `820-install-packages.sh` depend on each other — include both or neither.

## runonce.d template scripts

These run once on first boot via the `runonce` service. Results are logged and tracked so they do not re-run on subsequent boots.

The scripts logs into: `/var/log/messages`

| Script | Required | Description |
|---|---|---|
| `800-isolate-cpu-core.sh` | No | Isolates CPU cores for TwinCAT real-time |
| `810-tcRegistry-setup.sh` | No | Configures the TwinCAT registry |
| `820-install-packages.sh` | No† | Installs `.pkg` files from `/tmp` |
| `830-nginx-config.sh` | No | Configures the nginx web server |
| `840-opcua-server.sh` | No | Configures the TF6100 OPC UA server |
| `899-reboot.sh` | **Yes** | Reboots the system after first-boot configuration; must be the last script before `900` |

† `820-install-packages.sh` and `130-copy-packages.installer` depend on each other — include both or neither.

## Script numbering

The built-in TC/BSD installer scripts occupy numbers below `120`. Custom scripts should start at `120` or higher to avoid conflicts. The `900` range is reserved for the factory reset restore point created by the installer.
