#!/usr/bin/env bash
# IXXAT 드라이버(ix_usb_can) 소스를 대상 커널의 API 에 맞춰 고친다.
#
#   ixxat_kernel_compat.sh <소스_최상위> [커널버전]
#
# HMS 2.0.520 은 커널 6.13 이전 API 기준이라 최신 커널에서 그대로 빌드되지 않는다.
# 커널 버전 숫자가 아니라 헤더를 직접 확인해 필요한 경우에만 고친다.
# (배포판이 변경을 백포트한 경우까지 맞고, 구버전 커널에서는 아무것도 하지 않는다)
#
# DKMS 가 커널이 바뀔 때마다 PRE_BUILD 로 이 스크립트를 다시 부르므로,
# 여러 번 실행해도 결과가 같도록(멱등) 작성한다.
set -u
ROOT="${1:?소스 최상위 경로가 필요합니다}"
KVER="${2:-$(uname -r)}"
KHDR="/lib/modules/$KVER/build/include/linux/can"
SRC="$ROOT/kernel/drivers/net/can/usb/ixxat_usb"

[ -d "$SRC" ] || { echo "  [실패] 드라이버 소스가 없습니다: $SRC" >&2; exit 1; }

APPLIED=""

# (1) 커널 6.13~ : can_priv 의 FD 비트타이밍이 can_priv.fd 하위 구조체로 옮겨졌다.
#     이미 고쳐진 자리(can.fd.data_bittiming)는 패턴에 걸리지 않아 다시 실행해도 안전하다.
if grep -qs "struct data_bittiming_params" "$KHDR/bittiming.h"; then
    sed -i -e 's/can\.data_bittiming_const/can.fd.data_bittiming_const/g' \
           -e 's/can\.data_bittiming\([^_]\)/can.fd.data_bittiming\1/g' "$SRC"/*.c "$SRC"/*.h
    APPLIED="$APPLIED can_priv.fd"
fi

# (2) CAN XL 도입 후 : can_change_mtu 가 없어지고 MTU 를 CAN 코어가 직접 관리한다.
#     드라이버가 .ndo_change_mtu 를 채우지 않아야 한다.
if ! grep -qs "can_change_mtu" "$KHDR/dev.h"; then
    sed -i '/\.ndo_change_mtu[[:space:]]*=[[:space:]]*can_change_mtu,/d' "$SRC"/*.c
    APPLIED="$APPLIED ndo_change_mtu"
fi

if [ -n "$APPLIED" ]; then
    echo "  커널 $KVER 호환 패치:$APPLIED"
else
    echo "  커널 $KVER — 호환 패치 불필요"
fi
