#!/usr/bin/env bash
# Prepares this machine for the AFT150-D50 ROS 2 driver: CAN drivers, automatic interface setup
# and the permissions that go with them.
#
#   sudo ./install.sh                install, picking the CAN drivers this kernel is missing
#   sudo ./install.sh --no-drivers   install without building any CAN driver
#   sudo ./install.sh --uninstall    remove
#
# The driver itself is a set of ROS 2 packages, so it is built with colcon rather than installed
# here. This script covers what colcon cannot: kernel modules, udev and systemd.
set -u
cd "$(dirname "$(readlink -f "$0")")"
DIR="$(pwd)"
S="$DIR/scripts"

if [ "$(id -u)" -ne 0 ]; then
    echo "this needs root:  sudo ./install.sh" >&2
    exit 1
fi
RUSER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"

# ─────────────────────────────── uninstall ───────────────────────────────
if [ "${1:-}" = "--uninstall" ]; then
    echo "Removing."
    for pattern in 'aft-can@*' 'aft-slcan@*'; do
        systemctl list-units "$pattern" --all --no-legend 2>/dev/null | awk '{print $1}' |
            while read -r u; do [ -n "$u" ] && systemctl stop "$u" 2>/dev/null; done
    done
    rm -f /etc/systemd/system/aft-can@.service /etc/systemd/system/aft-slcan@.service \
          /etc/udev/rules.d/50-aft150-can.rules \
          /usr/local/bin/aft-can-up /usr/local/bin/aft-slcan-up
    systemctl daemon-reload 2>/dev/null || true
    udevadm control --reload-rules 2>/dev/null || true
    [ -x "$S/install_pcan_driver.sh" ]  && "$S/install_pcan_driver.sh" uninstall
    [ -x "$S/install_ixxat_driver.sh" ] && "$S/install_ixxat_driver.sh" uninstall
    echo
    echo "Done."
    echo "  Left in place: /etc/default/aft-can (settings), dialout group membership,"
    echo "                 and this checkout with whatever colcon built."
    exit 0
fi

echo "AFT150-D50 ROS 2 driver — machine setup"
echo "  location: $DIR   user: $RUSER"

echo
echo "[1/4] system packages"
# Every distribution names these differently, so work out the package manager first. The kernel
# headers and the build tools are what the CAN drivers need to compile, and dkms is what rebuilds
# them after a kernel update.
KVER="$(uname -r)"
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq || true
    apt-get install -y -qq can-utils build-essential curl dkms "linux-headers-$KVER" \
        || echo "  (some failed — continuing)"
    [ -d /lib/modules/"$KVER"/build ] || apt-get install -y -qq linux-headers-generic >/dev/null 2>&1 || true
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q can-utils gcc make curl dkms "kernel-devel-$KVER" \
        || echo "  (some failed — continuing)"
    [ -d /lib/modules/"$KVER"/build ] || dnf install -y -q kernel-devel >/dev/null 2>&1 || true
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q can-utils gcc make curl dkms "kernel-devel-$KVER" \
        || echo "  (some failed — continuing)"
    [ -d /lib/modules/"$KVER"/build ] || yum install -y -q kernel-devel >/dev/null 2>&1 || true
elif command -v pacman >/dev/null 2>&1; then
    # Arch needs the header package that matches the running kernel.
    case "$KVER" in
        *-lts)  KHDRPKG=linux-lts-headers ;;
        *-zen)  KHDRPKG=linux-zen-headers ;;
        *)      KHDRPKG=linux-headers ;;
    esac
    pacman -Sy --noconfirm --needed can-utils base-devel curl dkms "$KHDRPKG" >/dev/null 2>&1 \
        || echo "  (some failed — continuing)"
elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install -y canutils gcc make curl dkms \
                                        kernel-devel kernel-default-devel >/dev/null 2>&1 \
        || echo "  (some failed — continuing)"
else
    echo "  unknown distribution — install these by hand and run this again:"
    echo "    can-utils, gcc, make, curl, dkms, kernel headers ($KVER)"
fi

if [ -d /lib/modules/"$KVER"/build ]; then
    echo "  kernel headers found"
else
    echo "  [warning] no kernel headers — building a CAN driver will fail"
fi
if command -v dkms >/dev/null 2>&1; then
    echo "  DKMS available — CAN drivers survive a kernel update"
else
    echo "  [note] no DKMS — run sudo ./install.sh again after a kernel update"
fi

echo
echo "[2/4] CAN drivers"
if [ "${1:-}" = "--no-drivers" ]; then
    echo "  skipped (--no-drivers)"
else
    # A pipe through sed would hand back sed's exit status and hide a failed install.
    set -o pipefail

    if modinfo pcan >/dev/null 2>&1 || modinfo peak_usb >/dev/null 2>&1; then
        echo "  PCAN   : already available"
    else
        echo "  PCAN   : missing from this kernel, installing"
        "$S/install_pcan_driver.sh" 2>&1 | sed 's/^/    /' \
            || echo "    [warning] PCAN driver install failed (other adapters still work)"
    fi

    # IXXAT ships with no distribution, so it is always built here. If DKMS is available but the
    # module is not registered with it, the module would vanish on the next kernel update, so it
    # is installed again to register it.
    IXXAT_OK=0
    if modinfo ix_usb_can >/dev/null 2>&1; then
        if command -v dkms >/dev/null 2>&1; then
            dkms status ix_usb_can 2>/dev/null | grep -q . && IXXAT_OK=1
        else
            IXXAT_OK=1
        fi
    fi
    if [ "$IXXAT_OK" = 1 ]; then
        echo "  IXXAT  : already available"
    else
        echo "  IXXAT  : installing"
        "$S/install_ixxat_driver.sh" 2>&1 | sed 's/^/    /' \
            || echo "    [warning] IXXAT driver install failed (other adapters still work)"
    fi

    echo "  CANable: no kernel driver needed, slcand attaches it"
    set +o pipefail
fi

echo
echo "[3/4] automatic setup and permissions"
install -m 755 "$S/can_up.sh" /usr/local/bin/aft-can-up
install -m 755 "$S/slcan_up.sh" /usr/local/bin/aft-slcan-up
install -m 644 "$S/50-aft150-can.rules" /etc/udev/rules.d/50-aft150-can.rules
install -m 644 "$S/aft-can@.service" /etc/systemd/system/aft-can@.service
install -m 644 "$S/aft-slcan@.service" /etc/systemd/system/aft-slcan@.service
[ -e /etc/default/aft-can ] || install -m 644 "$S/aft-can.default" /etc/default/aft-can
systemctl daemon-reload 2>/dev/null || true
udevadm control --reload-rules 2>/dev/null || true
usermod -aG dialout "$RUSER"
echo "  plugging in a USB adapter now sets it up automatically, across reboots too"
echo "  added $RUSER to the dialout group"

echo
echo "[4/4] adapters that are plugged in right now"
FOUND=0
for i in $(ip -br link show type can 2>/dev/null | awk '{print $1}'); do
    # Only USB adapters. A CAN controller built into the board may have nothing wired to it.
    if [ -e "/sys/class/net/$i/device/driver" ] &&
       readlink -f "/sys/class/net/$i/device" | grep -q usb; then
        "$S/can_up.sh" "$i" 2>&1 | sed 's/^/  /'
        FOUND=1
    fi
done
for t in /dev/ttyACM*; do
    [ -e "$t" ] || continue
    "$S/slcan_up.sh" "$(basename "$t")" 2>&1 | sed 's/^/  /' && FOUND=1
done
[ "$FOUND" = "1" ] || echo "  (no CAN adapter is connected)"

echo
echo "════════════════════════════════════════════════════"
echo " Setup complete"
echo "════════════════════════════════════════════════════"
echo "  Build the driver:  colcon build --packages-up-to aidin_aft150_d50_bringup"
echo "  Run it:            ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py"
echo "  Remove this setup: sudo ./install.sh --uninstall"
echo
echo "  Log out and back in once so the dialout group takes effect."
