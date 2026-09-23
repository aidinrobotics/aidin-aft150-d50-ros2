#!/usr/bin/env bash
# PEAK PCAN 드라이버 설치 (커널에 peak_usb 가 없는 장비용 — 예: NVIDIA Jetson)
#
#   sudo scripts/install_pcan_driver.sh              설치
#   sudo scripts/install_pcan_driver.sh uninstall    제거
#
# 일반 Ubuntu PC 는 커널에 peak_usb 가 이미 있으므로 이 스크립트가 필요 없다.
# (./run.sh --check 의 [어댑터 지원 현황] 항목에 PCAN '있음' 이면 실행하지 마세요.)
#
# PEAK 공식 소스를 SocketCAN(netdev) 모드로 빌드한다 → 인터페이스가 canN 으로 잡힌다.
set -u
cd "$(dirname "$(readlink -f "$0")")"
HERE="$(pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "root 권한이 필요합니다:  sudo scripts/install_pcan_driver.sh" >&2
    exit 1
fi

BUILD=/usr/src/aft150-pcan

if [ "${1:-}" = "uninstall" ]; then
    SRC="$(find "$BUILD" -maxdepth 1 -name 'peak-linux-driver-*' -type d 2>/dev/null | head -1)"
    modprobe -r pcan 2>/dev/null || true
    [ -n "$SRC" ] && make -C "$SRC/driver" uninstall >/dev/null 2>&1
    # 빌드 폴더가 이미 없어 make uninstall 을 못 돌린 경우에도 모듈은 지운다.
    find /lib/modules/"$(uname -r)" -name 'pcan.ko*' -delete 2>/dev/null || true
    rm -rf "$BUILD"
    depmod -a
    echo "[OK] PCAN 드라이버 제거 완료"
    exit 0
fi

echo "[1/4] 소스 준비"
if [ ! -d /lib/modules/"$(uname -r)"/build ]; then
    echo "  [실패] 커널 헤더가 없습니다 — sudo apt install linux-headers-\$(uname -r)" >&2
    exit 1
fi
command -v gcc >/dev/null && command -v make >/dev/null || {
    echo "  [실패] 빌드 도구가 없습니다 — sudo apt install build-essential" >&2; exit 1; }

TARBALL="$(ls "$HERE"/drivers/peak-linux-driver-*.tar.gz 2>/dev/null | head -1)"
if [ -z "$TARBALL" ]; then
    echo "  동봉된 소스가 없어 PEAK 사이트에서 내려받습니다"
    TARBALL=/tmp/peak-linux-driver.tar.gz
    curl -fsSL -o "$TARBALL" "https://www.peak-system.com/quick/PCAN-Linux-Driver" || {
        echo "  [실패] 다운로드 실패 — 인터넷 연결을 확인하세요" >&2; exit 1; }
fi
rm -rf "$BUILD"; mkdir -p "$BUILD"
tar xzf "$TARBALL" -C "$BUILD"
SRC="$(find "$BUILD" -maxdepth 1 -name 'peak-linux-driver-*' -type d | head -1)"
echo "  $(basename "$SRC")"

echo "[2/4] 빌드 (SocketCAN netdev 모드)"
# CAN FD 호환 패치: 커널 5.15.194 미만에서 dbitrate 가 거부되는 문제를 고친다.
PATCHED=0
CFILE="$SRC/driver/src/pcan_netdev.c"
if command -v python3 >/dev/null 2>&1 && [ -f "$HERE/drivers/peak-fd-compat.py" ]; then
    cp -f "$CFILE" "$CFILE.orig"
    if python3 "$HERE/drivers/peak-fd-compat.py" "$SRC"; then
        PATCHED=1
    fi
fi

# USB 어댑터만 쓰므로 PC카드/PCI/ISA/동글은 제외해 빌드 시간을 줄인다.
BUILD_ARGS="NET=NETDEV_SUPPORT PCC=NO PCI=NO ISA=NO DNG=NO"
if ! make -C "$SRC/driver" $BUILD_ARGS >/tmp/pcan_build.log 2>&1; then
    if [ "$PATCHED" = "1" ]; then
        # 패치 때문일 수 있으니 원본으로 되돌려 한 번 더 시도한다(FD 없이라도 동작하게).
        echo "  패치 빌드 실패 → 원본으로 재시도 (CAN FD 는 사용 불가해집니다)"
        mv -f "$CFILE.orig" "$CFILE"
        make -C "$SRC/driver" clean >/dev/null 2>&1
        if ! make -C "$SRC/driver" $BUILD_ARGS >/tmp/pcan_build.log 2>&1; then
            echo "  [실패] 빌드 실패 — 로그: /tmp/pcan_build.log" >&2
            tail -20 /tmp/pcan_build.log >&2
            exit 1
        fi
        PATCHED=0
    else
        echo "  [실패] 빌드 실패 — 로그: /tmp/pcan_build.log" >&2
        tail -20 /tmp/pcan_build.log >&2
        exit 1
    fi
fi
rm -f "$CFILE.orig"
echo "  $(modinfo "$SRC/driver/pcan.ko" | awk '/^vermagic/{$1="";print "vermagic:"$0}')"
[ "$PATCHED" = "1" ] && echo "  CAN FD 지원 포함" || echo "  CAN FD 미포함 (클래식 CAN 2.0 만)"

echo "[3/4] 설치"
make -C "$SRC/driver" install >/dev/null 2>&1 || { echo "  [실패] 설치 실패" >&2; exit 1; }
depmod -a

echo "[4/4] 모듈 적재"
modprobe -r pcan 2>/dev/null || true
modprobe pcan || { echo "  [실패] modprobe pcan 실패" >&2; exit 1; }

echo
echo "설치 완료. 현재 CAN 인터페이스:"
ip -br link show type can 2>/dev/null | sed 's/^/  /'
echo
echo "다음 단계:  sudo scripts/can_up.sh <인터페이스>   예) sudo scripts/can_up.sh can1"
