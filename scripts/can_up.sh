#!/usr/bin/env bash
# Bring up a SocketCAN interface: CAN FD where the controller supports it, classic CAN 2.0
# otherwise. aft-can@.service calls this; it installs as /usr/local/bin/aft-can-up.
#
#   sudo scripts/can_up.sh                      can0 at 1M/5M FD
#   sudo scripts/can_up.sh can1                 can1 at 1M/5M FD
#   sudo scripts/can_up.sh can0 500000 2000000  bitrates given explicitly
#   sudo scripts/can_up.sh vcan0                virtual CAN, for testing without hardware
#   sudo scripts/can_up.sh slcan0               an slcan adapter that slcand already attached
set -u
# Defaults come from the config file when there is one. An argument wins over both.
CAN_BITRATE=1000000
CAN_DBITRATE=5000000
# The bit timing has to match the sensor, which uses the same timing as the AIDIN Hand Gen2:
#   nominal 1M @ 87.5%, SJW 10 / data 5M @ 87.5%, SJW 2
# The kernel defaults to a 75% sample point and an SJW of 1, so leaving these out changes them.
# A nominal sample point of 75% instead of 87.5% makes CAN FD BRS transmission fail.
CAN_SAMPLE_POINT=0.875
CAN_DSAMPLE_POINT=0.875
CAN_SJW=10
CAN_DSJW=2
[ -r /etc/default/aft-can ] && . /etc/default/aft-can

IFACE="${1:-can0}"
BITRATE="${2:-$CAN_BITRATE}"
DBITRATE="${3:-$CAN_DBITRATE}"
SP="$CAN_SAMPLE_POINT"
DSP="$CAN_DSAMPLE_POINT"
SJW="$CAN_SJW"
DSJW="$CAN_DSJW"

if [ "$(id -u)" -ne 0 ]; then
    echo "this needs root:  sudo $0 $*" >&2
    exit 1
fi

# ---- virtual CAN: exercising the driver with no sensor and no adapter ----
if [[ "$IFACE" == vcan* ]]; then
    modprobe vcan || { echo "the vcan kernel module is not available." >&2; exit 1; }
    ip link show "$IFACE" >/dev/null 2>&1 || ip link add dev "$IFACE" type vcan
    ip link set "$IFACE" mtu 72 2>/dev/null || true    # 72 lets CAN FD frames through
    ip link set "$IFACE" up
    echo "[OK] $IFACE (virtual CAN) is ready"
    exit 0
fi

# ---- slcan: slcand owns the bitrate, so ip link cannot set one ----
# The interface exists only while slcand is running, and aft-slcan@.service starts it from the
# udev rule. Asking for a bitrate here fails, so this only makes sure the link is up.
if [[ "$IFACE" == slcan* ]]; then
    if ! ip link show "$IFACE" >/dev/null 2>&1; then
        echo "[FAIL] '$IFACE' does not exist. slcand attaches it when the adapter is plugged in." >&2
        echo "       Attach it by hand with:  sudo scripts/slcan_up.sh ttyACM0" >&2
        exit 1
    fi
    ip link set "$IFACE" up 2>/dev/null || true
    ip link set "$IFACE" txqueuelen 1000 2>/dev/null || true
    echo "[OK] $IFACE is ready — classic CAN 2.0 only, so use the int6 data type"
    ip -br link show "$IFACE"
    exit 0
fi

if ! ip link show "$IFACE" >/dev/null 2>&1; then
    echo "[FAIL] there is no interface called '$IFACE'." >&2
    echo "       - Check that the USB adapter is plugged in." >&2
    echo "       - If the kernel driver is missing, run sudo ./install.sh." >&2
    echo "       - CAN interfaces present: $(ip -br link show type can 2>/dev/null | awk '{print $1}' | tr '\n' ' ')" >&2
    exit 1
fi

# Configure and bring up as one attempt. Configuring can succeed while bringing up fails — the
# kernel refuses 'up' when the FD flag is set but no data bitrate came with it — so an approach
# only counts once the interface is actually up.
try_cfg() {
    ip link set "$IFACE" down 2>/dev/null
    ip link set "$IFACE" type can "$@" 2>/dev/null || return 1
    ip link set "$IFACE" up 2>/dev/null || return 1
    return 0
}

# Rather than working out what the controller supports, try the richest setting first and fall
# back. PEAK's pcan driver reports no data_bittiming_const even on an adapter that has CAN FD.
# Falling back to classic has to clear the FD flag a previous attempt may have left set.
if   try_cfg bitrate "$BITRATE" sample-point "$SP" sjw "$SJW" \
             dbitrate "$DBITRATE" dsample-point "$DSP" dsjw "$DSJW" fd on; then
    MODE="CAN FD  nominal=${BITRATE}@${SP} sjw=${SJW}  data=${DBITRATE}@${DSP} dsjw=${DSJW}"
elif try_cfg bitrate "$BITRATE" sample-point "$SP" \
             dbitrate "$DBITRATE" dsample-point "$DSP" fd on; then
    MODE="CAN FD  nominal=${BITRATE}@${SP}  data=${DBITRATE}@${DSP}  (no SJW accepted, using defaults)"
elif try_cfg bitrate "$BITRATE" dbitrate "$DBITRATE" fd on; then
    MODE="CAN FD  nominal=${BITRATE}  data=${DBITRATE}  (no sample point accepted, kernel defaults, BRS may fail)"
elif try_cfg fd off bitrate "$BITRATE" sample-point "$SP" sjw "$SJW"; then
    MODE="CAN 2.0 ${BITRATE}@${SP} sjw=${SJW}  (this driver takes no FD settings over ip link)"
elif try_cfg fd off bitrate "$BITRATE" sample-point "$SP"; then
    MODE="CAN 2.0 ${BITRATE}@${SP}  (this driver takes no FD settings over ip link)"
elif try_cfg fd off bitrate "$BITRATE"; then
    MODE="CAN 2.0 ${BITRATE}  (no FD and no sample point accepted)"
else
    ip link set "$IFACE" down 2>/dev/null
    echo "[FAIL] could not bring $IFACE up — the adapter may be in use, or the driver may be at fault." >&2
    echo "       For detail: ip -details link show $IFACE" >&2
    exit 1
fi

ip link set "$IFACE" txqueuelen 1000 2>/dev/null || true
echo "[OK] $IFACE is ready — $MODE"
ip -br link show "$IFACE"
