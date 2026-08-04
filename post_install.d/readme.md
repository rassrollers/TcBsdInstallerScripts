# post_install.d

**The scripts are run in order of the numbering.**

* post_install.d/*.installer → runs in installer’s live environment, works on /mnt.
* post_install.d/*.chroot → runs inside the newly installed system (chroot /mnt), affects the final OS directly.

Default script on the TC/BSD installer:

* 009-update-resolvconf.installer
* 010-init-base-system.chroot
* 050-create-restore-boot-environment.chroot
* 100_copy_ssh_keys.installer
* 101_install_ssh_keys.chroot
* 110_copy_runonce_d.installer