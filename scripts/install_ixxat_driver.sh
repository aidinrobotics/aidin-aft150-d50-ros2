#!/usr/bin/env bash
# IXXAT SocketCAN 드라이버 설치 (커널에 ix_usb_can 이 없는 장비용)
#
#   sudo scripts/install_ixxat_driver.sh              설치
#   sudo scripts/install_ixxat_driver.sh uninstall    제거
#
# HMS 공식 SocketCAN 드라이버(ix_usb_can)를 빌드해 설치한다.
# USB-to-CAN V2 / USB-to-CAN FD 제품군을 지원하며 CAN FD 도 지원한다.
# 설치하면 어댑터가 canN 인터페이스로 잡히고, PCAN 과 동일하게 can_up.sh 로 기동한다.
#
# DKMS 가 있으면 DKMS 로 등록한다 — 커널이 업데이트돼도 자동으로 다시 빌드되므로
# 사용자가 이 스크립트를 다시 실행할 필요가 없다. DKMS 가 없으면 수동 빌드로 넘어간다.
set -u
cd "$(dirname "$(readlink -f "$0")")"
HERE="$(pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "root 권한이 필요합니다:  sudo scripts/install_ixxat_driver.sh" >&2
    exit 1
fi

MOD=ix_usb_can
BUILD=/usr/src/aft150-ixxat          # 수동 빌드용 작업 디렉터리

# ─────────────────────────────── 제거 ───────────────────────────────
if [ "${1:-}" = "uninstall" ]; then
    modprobe -r "$MOD" 2>/dev/null || true
    # DKMS 로 등록된 버전이 있으면 모두 제거한다.
    # dkms status 의 출력 형식은 DKMS 버전마다 다르다("mod, ver" / "mod/ver").
    # 형식을 파싱하는 대신, 우리가 직접 만든 /usr/src/<mod>-<ver> 에서 버전을 얻는다.
    if command -v dkms >/dev/null 2>&1; then
        for d in /usr/src/"$MOD"-*/; do
            [ -d "$d" ] || continue
            v="$(basename "$d")"; v="${v#"$MOD"-}"
            [ -n "$v" ] && dkms remove "$MOD/$v" --all >/dev/null 2>&1 || true
        done
        rm -rf /usr/src/"$MOD"-*
    fi
    # make modules_install 이 넣는 위치(updates/)와 수동 설치 위치가 다를 수 있으므로
    # 경로를 가정하지 않고 찾아서 지운다.
    find /lib/modules -name "$MOD.ko*" -delete 2>/dev/null || true
    rm -rf "$BUILD"
    depmod -a
    echo "[OK] IXXAT 드라이버 제거 완료"
    exit 0
fi

# ────────────────────────── 1. 소스 준비 ──────────────────────────
echo "[1/4] 소스 준비"
if [ ! -d /lib/modules/"$(uname -r)"/build ]; then
    echo "  [실패] 커널 헤더가 없습니다 — sudo apt install linux-headers-\$(uname -r)" >&2
    exit 1
fi
command -v gcc >/dev/null && command -v make >/dev/null || {
    echo "  [실패] 빌드 도구가 없습니다 — sudo apt install build-essential" >&2; exit 1; }

TARBALL="$(ls "$HERE"/drivers/ix_usb_can_*.tgz 2>/dev/null | head -1)"
if [ -z "$TARBALL" ]; then
    echo "  동봉된 소스가 없어 HMS 사이트에서 내려받습니다"
    TMPGZ=/tmp/ixxat-socketcan.gz
    curl -fsSL -o "$TMPGZ" \
      "https://hmsnetworks.blob.core.windows.net/nlw/docs/default-source/products/ixxat/monitored/pc-interface-cards/socketcan-linux.gz" || {
        echo "  [실패] 다운로드 실패 — 인터넷 연결을 확인하세요" >&2; exit 1; }
    rm -rf /tmp/ixxat-pkg && mkdir -p /tmp/ixxat-pkg
    tar xzf "$TMPGZ" -C /tmp/ixxat-pkg
    TARBALL="$(ls /tmp/ixxat-pkg/ix_usb_can_*.tgz 2>/dev/null | head -1)"
    [ -n "$TARBALL" ] || { echo "  [실패] 패키지 안에서 ix_usb_can 을 못 찾음" >&2; exit 1; }
fi
echo "  $(basename "$TARBALL")"

# 파일명에서 버전을 뽑는다: ix_usb_can_2.0.520-REL.tgz -> 2.0.520
VER="$(basename "$TARBALL" | sed -e 's/^ix_usb_can_//' -e 's/\.tgz$//' -e 's/-REL$//')"
[ -n "$VER" ] || VER=0.0.0

# ────────────────── 2. DKMS 경로 (커널 업데이트에도 유지) ──────────────────
if command -v dkms >/dev/null 2>&1; then
    echo "[2/4] DKMS 등록 (커널 업데이트 시 자동 재빌드)"
    SRCDIR=/usr/src/"$MOD"-"$VER"
    MODPATH=kernel/drivers/net/can/usb/ixxat_usb

    dkms remove "$MOD/$VER" --all >/dev/null 2>&1 || true
    rm -rf "$SRCDIR"; mkdir -p "$SRCDIR"
    tar xzf "$TARBALL" -C "$SRCDIR"
    install -m 755 "$HERE/ixxat_kernel_compat.sh" "$SRCDIR/ixxat_kernel_compat.sh"

    # PRE_BUILD 는 커널마다 빌드 직전에 호출된다. 그래서 새 커널로 올라가도
    # 그 커널의 헤더를 보고 필요한 패치만 다시 적용된다.
    cat > "$SRCDIR/dkms.conf" <<CONF
PACKAGE_NAME="$MOD"
PACKAGE_VERSION="$VER"
AUTOINSTALL="yes"
PRE_BUILD="ixxat_kernel_compat.sh . \${kernelver}"
MAKE[0]="make -C /lib/modules/\${kernelver}/build M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build/$MODPATH CONFIG_CAN_IXXAT_USB=m modules"
CLEAN="make -C /lib/modules/\${kernelver}/build M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build/$MODPATH CONFIG_CAN_IXXAT_USB=m clean"
BUILT_MODULE_NAME[0]="$MOD"
BUILT_MODULE_LOCATION[0]="$MODPATH"
DEST_MODULE_LOCATION[0]="/$MODPATH"
CONF

    if dkms add -m "$MOD" -v "$VER" >/tmp/ixxat_build.log 2>&1 &&
       dkms build -m "$MOD" -v "$VER" >>/tmp/ixxat_build.log 2>&1 &&
       dkms install -m "$MOD" -v "$VER" --force >>/tmp/ixxat_build.log 2>&1; then
        echo "  DKMS 등록 완료: $MOD/$VER"
        grep -h "호환 패치" /tmp/ixxat_build.log | tail -1
        DKMS_OK=1
    else
        echo "  [경고] DKMS 설치 실패 — 수동 빌드로 전환합니다 (로그: /tmp/ixxat_build.log)"
        tail -15 /tmp/ixxat_build.log >&2
        dkms remove "$MOD/$VER" --all >/dev/null 2>&1 || true
        DKMS_OK=0
    fi
else
    echo "[2/4] DKMS 없음 — 수동 빌드로 진행합니다"
    echo "       (커널 업데이트 후에는 이 스크립트를 다시 실행해야 합니다)"
    DKMS_OK=0
fi

# ────────────────── 3. 수동 빌드 (DKMS 를 못 쓸 때) ──────────────────
if [ "$DKMS_OK" != "1" ]; then
    echo "[3/4] 빌드"
    rm -rf "$BUILD"; mkdir -p "$BUILD"
    tar xzf "$TARBALL" -C "$BUILD"
    "$HERE/ixxat_kernel_compat.sh" "$BUILD" "$(uname -r)" || exit 1
    if ! make -C "$BUILD" >/tmp/ixxat_build.log 2>&1; then
        echo "  [실패] 빌드 실패 — 로그: /tmp/ixxat_build.log" >&2
        tail -20 /tmp/ixxat_build.log >&2
        exit 1
    fi
    KO="$(find "$BUILD" -name "$MOD.ko" | head -1)"
    echo "  $(modinfo "$KO" | awk '/^vermagic/{$1="";print "vermagic:"$0}')"

    make -C "$BUILD" modules_install >/dev/null 2>&1 || {
        DEST=/lib/modules/"$(uname -r)"/kernel/drivers/net/can/usb/ixxat_usb
        install -d "$DEST" && install "$KO" "$DEST"; }
fi

depmod -a

# ────────────────────────── 4. 모듈 적재 ──────────────────────────
echo "[4/4] 모듈 적재"
modprobe -r "$MOD" 2>/dev/null || true
modprobe "$MOD" || { echo "  [실패] modprobe $MOD 실패" >&2; exit 1; }

echo
echo "설치 완료. 현재 CAN 인터페이스:"
ip -br link show type can 2>/dev/null | sed 's/^/  /'
echo
echo "다음 단계:  sudo scripts/can_up.sh <인터페이스>"
