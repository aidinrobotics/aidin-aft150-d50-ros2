#!/usr/bin/env bash
# Attach an slcan serial adapter as a CAN interface, or detach it again.
# aft-slcan@.service calls this; it installs as /usr/local/bin/aft-slcan-up and -down.
#
#   sudo scripts/slcan_up.sh ttyACM0          attach, giving slcan0
#   sudo scripts/slcan_up.sh ttyACM0 down     detach
#
# slcan carries classic CAN 2.0 only. The frame is 8 bytes at most, so an AFT150-D50 on this path
# can use the int6 data type and not the combined ones, which need CAN FD.
set -u

CAN_BITRATE=1000000
[ -r /etc/default/aft-can ] && . /etc/default/aft-can

TTY="${1:-}"
ACTION="${2:-up}"

if [ -z "$TTY" ]; then
    echo "usage: $0 <tty name, e.g. ttyACM0> [up|down]" >&2
    exit 2
fi
if [ "$(id -u)" -ne 0 ]; then
    echo "this needs root:  sudo $0 $*" >&2
    exit 1
fi

# slcan0 for ttyACM0, slcan1 for ttyACM1. Keeping the number ties the interface to the port it
# came from, so two adapters do not race for the same name.
INDEX="$(printf '%s' "$TTY" | tr -dc '0-9')"
[ -n "$INDEX" ] || INDEX=0
IFACE="slcan${INDEX}"

if [ "$ACTION" = "down" ]; then
    ip link set "$IFACE" down 2>/dev/null || true
    pkill -f "slcand .*${TTY}" 2>/dev/null || true
    echo "[OK] ${IFACE} detached"
    exit 0
fi

command -v slcand >/dev/null 2>&1 || {
    echo "[FAIL] slcand is missing. Install can-utils:  sudo apt install can-utils" >&2
    exit 1; }
[ -e "/dev/$TTY" ] || { echo "[FAIL] /dev/$TTY does not exist" >&2; exit 1; }

# slcand takes a speed code rather than a bitrate. These are the codes the LAWICEL protocol
# defines, and the sensor ships at 1 Mbps.
case "$CAN_BITRATE" in
    10000)   SPEED=0 ;;
    20000)   SPEED=1 ;;
    50000)   SPEED=2 ;;
    100000)  SPEED=3 ;;
    125000)  SPEED=4 ;;
    250000)  SPEED=5 ;;
    500000)  SPEED=6 ;;
    800000)  SPEED=7 ;;
    1000000) SPEED=8 ;;
    *) echo "[FAIL] slcan has no speed code for CAN_BITRATE=$CAN_BITRATE" >&2; exit 1 ;;
esac

# Already attached, for instance because udev fired twice.
if ip link show "$IFACE" >/dev/null 2>&1; then
    ip link set "$IFACE" up 2>/dev/null || true
    echo "[OK] ${IFACE} was already attached"
    exit 0
fi

slcand -o -c -f "-s${SPEED}" "/dev/$TTY" "$IFACE" \
    || { echo "[FAIL] slcand could not attach /dev/$TTY" >&2; exit 1; }

# slcand forks, so the interface appears a moment later.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    ip link show "$IFACE" >/dev/null 2>&1 && break
    sleep 0.1
done
ip link show "$IFACE" >/dev/null 2>&1 || {
    echo "[FAIL] ${IFACE} did not appear after slcand started" >&2; exit 1; }

ip link set "$IFACE" up || { echo "[FAIL] could not bring ${IFACE} up" >&2; exit 1; }
echo "[OK] ${IFACE} attached from /dev/${TTY} at ${CAN_BITRATE} bps (classic CAN 2.0 only)"
