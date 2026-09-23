# Third-Party Notices

This distribution includes, or downloads during installation, the third-party software listed
below. Each is covered by its own author's licence.

---

## Sources included in `scripts/drivers/`

### PEAK-System Linux Driver (`peak-linux-driver-9.2.0.tar.gz`)

- Copyright: PEAK-System Technik GmbH
- Licence: **GPL-2.0** (kernel driver), LGPL (user-space library)
  - See `LICENSE.gpl` and `LICENSE.lgpl` inside the archive
- Source: https://www.peak-system.com/quick/PCAN-Linux-Driver
- Modifications: `scripts/drivers/peak-fd-compat.py` patches `driver/src/pcan_netdev.c` at
  install time. On Linux kernels older than 5.15.194 `data_bittiming_const` is left unset, which
  makes CAN FD unusable; the patch sets it. The full text of the change is in that script.
  (Notice of modification under section 2 of the GPL-2.0.)

### HMS IXXAT SocketCAN Driver (`ix_usb_can_2.0.520-REL.tgz`)

- Copyright: HMS Technology Center Ravensburg GmbH
- Licence: **GPL-2.0** (`SPDX-License-Identifier: GPL-2.0`)
- Source: https://hmsnetworks.blob.core.windows.net/nlw/docs/default-source/products/ixxat/monitored/pc-interface-cards/socketcan-linux.gz
- Modifications: the archive here is **unmodified**. `scripts/ixxat_kernel_compat.sh` patches it
  locally just before the build, because a kernel API change breaks the build on Linux 6.13 and
  later. The full text of the change is in that script.
  - `can_priv.data_bittiming` → `can_priv.fd.data_bittiming` (kernel 6.13 and later)
  - `.ndo_change_mtu = can_change_mtu` removed (the symbol went away with CAN XL)
  - The script inspects the target kernel's headers and only patches when it has to, so an older
    kernel builds the original source.
  (Notice of modification under section 2 of the GPL-2.0.)

> The complete source of both drivers is included verbatim in `scripts/drivers/`.
