#!/usr/bin/env python3
"""PEAK 드라이버 CAN FD 호환 패치 (install_pcan_driver.sh 에서 호출).

문제:
  peak-linux-driver 는 priv->can.data_bittiming_const 를
  `#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 194)` 안에서만 설정한다.
  그보다 낮은 5.15.x 커널(예: Jetson 의 5.15.185)에서는 이 값이 비어 있어
  커널 CAN 코어가 `ip link set ... dbitrate` 를 EINVAL 로 거부한다.
  그 결과 `fd on` 은 통과하는데 data 비트레이트가 없어 인터페이스가 뜨지 않는다.

해결:
  data_bittiming_const 는 3.18.5 부터 struct can_priv 에 존재하므로,
  5.15.194 미만 커널용 #elif 분기를 추가해 그 값만 설정한다.
  TDC(CAN_CTRLMODE_TDC_AUTO / tdc_const)는 구커널에 없으므로 건드리지 않는다.

사용: peak-fd-compat.py <드라이버소스루트>
반환: 0=패치함, 1=패치 불필요/불가(빌드는 그대로 진행하면 된다)
"""
import sys, os

ANCHOR = '''			pcan_netdev_convert_tdc_caps(&priv->tdc_const);
#endif /* 5.15.194 */

		can_type = "CAN-FD";'''

PATCHED = '''			pcan_netdev_convert_tdc_caps(&priv->tdc_const);
#elif LINUX_VERSION_CODE >= KERNEL_VERSION(3, 18, 5)
		/* AFT150 compat: 5.15.194 미만 커널에도 data_bittiming_const 는 존재한다.
		 * 설정하지 않으면 ip link 의 dbitrate 가 EINVAL 로 거부되어 CAN FD 를 못 쓴다. */
		priv->can.data_bittiming_const =
			pcan_netdev_convert_bt_caps(&priv->fd_bt_const,
						    pdev->fd_bittiming_caps);
#endif /* 5.15.194 */

		can_type = "CAN-FD";'''


def main():
    if len(sys.argv) < 2:
        print("사용법: peak-fd-compat.py <드라이버소스루트>", file=sys.stderr)
        return 1
    path = os.path.join(sys.argv[1], 'driver', 'src', 'pcan_netdev.c')
    if not os.path.isfile(path):
        print(f"  패치 건너뜀: {path} 없음")
        return 1
    src = open(path, encoding='utf-8', errors='surrogateescape').read()
    if 'AFT150 compat' in src:
        print("  이미 패치됨")
        return 0
    n = src.count(ANCHOR)
    if n != 1:
        # 드라이버 버전이 바뀌어 코드 모양이 달라진 경우 — 패치 없이 진행한다.
        print(f"  패치 건너뜀: 대상 코드 형태가 다름 (매칭 {n}건)")
        return 1
    open(path, 'w', encoding='utf-8', errors='surrogateescape').write(src.replace(ANCHOR, PATCHED))
    print("  CAN FD 호환 패치 적용")
    return 0


if __name__ == '__main__':
    sys.exit(main())
