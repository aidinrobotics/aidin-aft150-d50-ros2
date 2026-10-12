<div align="center">

<a href="https://www.aidinrobotics.co.kr/"><img height="56" src="docs/assets/aidin_logo.png" alt="AIDIN AFT150-D50 — AIDIN Robotics"></a>

<h1>AIDIN AFT150-D50 ROS 2</h1>

AIDIN AFT150-D50 6축 힘·토크 센서를 SocketCAN으로 읽는 ROS 2 driver입니다. 센서가 제공하는 모든
업데이트 레이트를 지원하며, 힘은 N, 토크는 Nm 단위로 발행합니다. 독립 node로
실행하거나, 기존 로봇의 resource manager에 합류하는 `ros2_control` sensor interface로 실행할 수
있습니다.

[![version](https://img.shields.io/badge/version-0.1.0-blue)](CHANGELOG.md) [![ROS 2](https://img.shields.io/badge/ROS%202-Humble-brightgreen)](#system-requirements)

[Install](#installation) | [Changelog](CHANGELOG.md) | [Official Site](https://www.aidinrobotics.co.kr/) | [English](README.md) | 한국어

</div>

## System requirements

아래 구성에서 빌드와 실행을 확인했습니다.

| Component | Requirement |
|---|---|
| Operating System | Ubuntu 22.04 |
| ROS 2 | Humble |
| CAN interface | USB CAN-FD 어댑터(SocketCAN), nominal 1 Mbit/s, data 구간 5 Mbit/s |

CANable도 사용할 수 있습니다. 펌웨어에 따라 연결 경로가 다르며,
[Setting up the CAN interface](#setting-up-the-can-interface)에서 설명합니다.

## Installation

```bash
sudo apt install can-utils
colcon build --packages-up-to aidin_aft150_d50_bringup
```

`can-utils`에는 `slcan_up.sh`가 사용하는 `slcand`와 [Troubleshooting](#troubleshooting)에서 사용하는
`candump`가 들어 있습니다.

어댑터의 커널 드라이버가 있어야 합니다. 사용하는 어댑터의 드라이버를 확인합니다.

```bash
modinfo peak_usb | head -2       # PEAK PCAN-USB FD
modinfo gs_usb   | head -2       # candleLight 펌웨어의 CANable
```

`filename` 줄이 나오면 드라이버가 있는 것입니다. `Module ... not found`가 나오면 커널에 드라이버가
없는 것입니다. 기본 Ubuntu 커널이면 `sudo apt install linux-modules-extra-$(uname -r)`을 실행하고,
직접 빌드한 커널이나 Jetson 같은 vendor 커널이면 `CONFIG_CAN_PEAK_USB` 또는 `CONFIG_CAN_GS_USB`를
켜고 커널을 다시 빌드합니다. slcan 펌웨어의 CANable은 두 드라이버가 모두 필요 없습니다.

driver 자체는 ROS 2 package이므로 `colcon`으로 빌드합니다.

| Package | Contents |
|---|---|
| [`aidin_aft150_d50_driver`](aidin_aft150_d50_driver/README.ko.md) | 통신 계층과 독립 node |
| [`aidin_aft150_d50_hardware`](aidin_aft150_d50_hardware/README.ko.md) | ros2_control sensor interface |
| [`aidin_aft150_d50_description`](aidin_aft150_d50_description/README.ko.md) | URDF와 ros2_control xacro 매크로 |
| [`aidin_aft150_d50_bringup`](aidin_aft150_d50_bringup/README.ko.md) | launch 파일과 parameter 파일 |

네 package는 버전 번호를 하나로 관리하며 함께 릴리스합니다.

## Setting up the CAN interface

driver를 실행하기 전에 인터페이스를 준비합니다. 이 설정은 재부팅하거나 어댑터를 다시 연결하면
사라지므로, 그때마다 다시 준비해야 합니다. 어댑터가 나타나는 형태에 맞는 스크립트를 실행합니다.

| Adapter | Appears as | Script |
|---|---|---|
| PEAK PCAN-USB FD, candleLight 펌웨어의 CANable | `ip -br link show type can`의 `can0` | `can_up.sh` |
| slcan 펌웨어의 CANable | `/dev/ttyACM0` | `slcan_up.sh`가 `slcan0`으로 연결합니다 |

```bash
sudo scripts/can_up.sh can0        # can0 으로 나타나는 어댑터
sudo scripts/slcan_up.sh ttyACM0   # slcan 펌웨어의 CANable, slcan0 으로 연결됩니다
sudo scripts/can_up.sh vcan0       # 하드웨어 없이 사용하는 가상 CAN
```

`can_up.sh`는 센서의 공장 설정인 CAN FD(nominal 1 Mbit/s, data 구간 5 Mbit/s)를 먼저 요청하고,
어댑터가 거부하면 클래식 CAN 2.0으로 설정합니다. 5 Mbit/s를 낼 수 있는지는 어댑터와 펌웨어에 따라
다르므로, 스크립트가 출력하는 줄을 확인하십시오.

```text
[OK] can0 is ready — CAN FD  nominal=1000000@0.875 sjw=10  data=5000000@0.875 dsjw=2
```

이 줄에 `CAN 2.0`이 표시되면 어댑터가 클래식 CAN만 받아들인 것입니다. 이때 센서는
`can_mode: classic`과 `int6` 데이터 타입을 사용해야 합니다.

driver는 이미 준비된 인터페이스를 열기만 합니다. 인터페이스를 직접 설정하지 않으며, 인터페이스가
없거나 내려가 있으면 실행할 명령을 알려 줍니다.

> [!IMPORTANT]
> slcan 펌웨어의 CANable은 클래식 CAN 2.0만 전달합니다. 프레임이 8바이트까지이므로 이 경로로
> 연결한 센서는 `int6` 데이터 타입을 사용해야 합니다. combined 타입은 CAN FD가 필요합니다.

## Running the driver

두 launch 파일은 같은 parameter 파일을 읽습니다.

```bash
# 독립 node
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py

# ros2_control, 센서마다 broadcaster 를 하나씩 실행
ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py
```

### Launch arguments

| Argument | 사용할 수 있는 launch 파일 | Default |
|---|---|---|
| `params_file` | 두 파일 모두 | `config/aft150_d50_params.yaml` |
| `controllers_file` | `aft150_d50_ros2_control.launch.py` | `config/aft150_d50_controllers.yaml` |

어느 센서가 어느 CAN 인터페이스에 연결되어 있는지는 장비마다 다릅니다. 추적 중인 파일을 고치지
말고 사본을 만들어 `params_file` 인자로 전달하십시오. 두 launch 파일 모두 이 인자를 받습니다.

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py \
  params_file:=~/my_aft150.yaml

ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py \
  params_file:=~/my_aft150.yaml
```

`ros2 launch aidin_aft150_d50_bringup <launch 파일> --show-args`로 인자와 기본값을 확인할 수
있습니다.

## Topics

두 경로 모두 샘플 하나마다 `geometry_msgs/msg/WrenchStamped` message를 하나씩 발행하지만 topic
이름은 서로 다릅니다. 독립 node는 자신의 node 이름 아래에서 해석되는 `~/wrench`로 발행합니다.
`ros2_control` 경로에서는 broadcaster가 topic을 소유하며, launch 파일이 센서 이름 뒤에
`_broadcaster`를 붙인 이름으로 broadcaster를 센서마다 하나씩 실행합니다.

| 경로 | Topic | 발행하는 주체 |
|---|---|---|
| 독립 node | `/<센서 이름>/wrench` | `aft150_d50_node` |
| `ros2_control` | `/<센서 이름>_broadcaster/wrench` | `force_torque_sensor_broadcaster` |

기본 parameter 파일에 들어 있는 `right_wrist_ft` 블록이라면 각각 `/right_wrist_ft/wrench`와
`/right_wrist_ft_broadcaster/wrench`입니다.

```bash
ros2 topic echo /right_wrist_ft/wrench
ros2 topic hz /right_wrist_ft/wrench
```

스트림이 정상적으로 흐르고 있다면 `ros2 topic hz`의 값은 `rate_hz`에 수렴합니다. service 이름은
두 경로에서 동일하며 topic 이름만 다릅니다. `ros2_control`의 controller는 자신의 node 이름 아래에
발행하는데, 그 이름은 hardware component의 이름과 달라야 하기 때문입니다.

독립 node는 커널이 프레임을 수신한 시각을 `CLOCK_REALTIME` 기준으로 각 message에 기록합니다. 이
시각은 `rosbag2` 및 같은 장비의 다른 센서와 같은 시간축입니다.

> [!NOTE]
> `ros2_control` 경로에서는 `force_torque_sensor_broadcaster`가 제어 주기 시각을 대신 기록합니다.
> Humble의 broadcaster에는 센서 시각을 전달할 통로가 없으므로, 샘플 시각 자체가 중요하다면 독립
> node를 사용하십시오.

## Parameters

parameter 파일은 일반적인 ROS 2 parameter 파일이므로 최상위 키가 곧 node 이름이고, 블록 하나가
그 node가 담당하는 센서의 설정입니다. `config/aft150_d50_params.yaml`에는 블록 두 개가 들어
있으며, 양쪽 손목에 센서를 하나씩 단 로봇의 구성입니다.

```yaml
right_wrist_ft:
  ros__parameters:
    can_interface: can0
    can_mode:      fd_brs
    data_type:     float_combined
    rate_hz:       1000
    set_id_can20:  0x430
    set_id_canfd:  0x330

left_wrist_ft:
  ros__parameters:
    can_interface: can1
    can_mode:      fd_brs
    data_type:     float_combined
    rate_hz:       1000
    set_id_can20:  0x430
    set_id_canfd:  0x330
```

이 파일로 실행하면 `/right_wrist_ft`와 `/left_wrist_ft` 두 node가 시작됩니다. 센서를 하나 더
붙이려면 블록을 하나 더 추가하십시오. 블록 사이에서 공유할 수 있는 설정과 그럴 수 없는 설정은
[Configuring more than one sensor](#configuring-more-than-one-sensor)에 있습니다.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `can_interface` | `string` | `can0` | 열 SocketCAN 인터페이스 이름이며 `ip link`가 표시하는 이름과 같습니다. 이미 준비된 상태여야 합니다 |
| `can_mode` | `string` | `fd_brs` | driver가 주고받을 프레임 형식입니다. `classic`·`fd`·`fd_brs` 중 하나이며, `fd_brs`는 BRS를 켜서 1 kHz를 낼 수 있습니다 |
| `data_type` | `string` | `float_combined` | 센서가 보낼 형식입니다. 아래 표의 세 값 중 하나입니다 |
| `rate_hz` | `int` | `1000` | 센서가 샘플을 보내는 주기입니다. `100`·`250`·`500`·`1000` 중 하나이며 단위는 Hz입니다 |
| `set_id_can20` | `int` | `0x430` | 센서가 데이터를 보낼 때 사용할 CAN 2.0 ID이며 `0x000`~`0x7FF`입니다. [Changing the transmit ID](#changing-the-transmit-id)를 참고하십시오 |
| `set_id_canfd` | `int` | `0x330` | 센서가 데이터를 보낼 때 사용할 CAN FD ID이며 `0x000`~`0x7FF`입니다 |
| `frame_id` | `string` | `<node 이름>_link` | 발행하는 wrench의 `header.frame_id`입니다. 센서를 장착한 URDF link 이름을 지정하십시오 |

모든 parameter는 기동할 때 한 번만 읽으며 실행 중에는 바꿀 수 없습니다. 설정을 바꾸려면
parameter 파일을 고치고 다시 실행하십시오.

> [!IMPORTANT]
> parameter를 읽기 전용으로 선언한 데에는 이유가 있습니다. 모드나 데이터 타입, 레이트를 바꾸면
> driver가 스트림을 되살리는 동안 센서의 전송이 약 100 ms 멈추고, `ros2_control` 경로에서는 그
> 시간 내내 `read()`가 직전 샘플을 그대로 돌려줍니다. 힘 목표를 유지하던 controller는 100 cycle
> 동안 낡은 값으로 동작하게 되며 ROS 그래프에는 그 사실이 드러나지 않습니다. 그래서
> `ros2 param set`은 거부됩니다.

`ros2 param get`으로 현재 driver가 사용 중인 값은 확인할 수 있습니다.

### Data types

| Value | Frames per sample | Needs CAN FD | Description |
|---|---|---|---|
| `int6` | 2 | 아니오 | 힘과 토크를 정수로 변환해 프레임 두 개로 나누어 보냅니다 |
| `int12_combined` | 1 | 예 | 여섯 축을 정수로 변환해 한 프레임에 담습니다 |
| `float_combined` | 1 | 예 | 여섯 축을 32비트 부동소수점으로 한 프레임에 담습니다 |

combined 타입 두 가지는 여섯 축을 한 프레임에 담으므로 클래식 CAN 프레임에 들어가지 않습니다.
`can_mode`가 `fd` 또는 `fd_brs`가 아니면 driver가 거부합니다.

`int6`는 프레임 두 개가 모두 있어야 샘플 하나가 됩니다. 힘 프레임을 놓친 토크 프레임은 이전 힘과
짝짓지 않고 버립니다.

### Changing the transmit ID

`set_id_can20`과 `set_id_canfd`는 센서가 사용할 ID이며, 센서가 현재 사용하는 값을 나타내지
않습니다. driver는 기동할 때 센서에 현재 ID를 질의하고 파일의 값과 다를 때만 변경을 전송합니다.
센서는 이 값을 비휘발성 메모리에 보관하므로 전원을 껐다 켜도 유지되고, 값을 바꾸지 않은 채로 다시
실행하면 센서에 아무것도 쓰지 않습니다.

출고 상태의 센서는 CAN 2.0 ID로 `0x430`, CAN FD ID로 `0x330`을 사용하며, 두 값은
`set_id_can20`과 `set_id_canfd`의 기본값과 같습니다. 따라서 기본 파일로 실행하면 driver는 새 센서에
ID를 쓰지 않고, `~/restore_defaults`를 호출해도 센서는 같은 두 ID로 돌아갑니다.

센서가 새 ID를 받아들이지 않으면 driver는 두 ID를 모두 적은 경고를 남기고, 기동을 실패로 처리하는
대신 센서가 응답한 ID로 계속 읽습니다.

> [!WARNING]
> 기준 ID는 연속된 주소 세 개를 사용하며, driver는 값이 범위 안인지만 검사합니다. 다른 버스와
> 겹치거나 명령 주소와 충돌하는 값을 넣으면 센서에 접근할 수 없게 됩니다. 이때는
> `~/restore_defaults`를 호출해 복구하십시오.

센서가 실제로 사용하는 ID는 `~/confirm_id`로 확인합니다.

## Services

service는 세 개이며 모두 `std_srvs/srv/Trigger`입니다. 값을 전달하는 설정은 parameter로 두었기
때문에 별도의 service 타입을 정의하지 않습니다.

| Service | 동작 |
|---|---|
| `~/set_bias` | 현재 센서에 걸린 하중을 영점으로 지정합니다 |
| `~/confirm_id` | 센서에 transmit ID를 질의하고 응답에 담아 돌려줍니다 |
| `~/restore_defaults` | transmit ID를 포함해 센서 설정을 공장 기본값으로 되돌립니다 |

```bash
ros2 service call /right_wrist_ft/set_bias std_srvs/srv/Trigger
```

> [!WARNING]
> driver는 `~/set_bias`를 자동으로 전송하지 않습니다. 기동 시점에 센서에 실려 있던 하중이 영점이
> 되면 로봇에서는 안전 문제가 됩니다. 센서에 하중이 없는 것을 확인한 뒤에만 호출하십시오.

`~/restore_defaults`는 호출 즉시 실행되며 확인 단계가 없습니다.

## Configuring more than one sensor

좌우가 미리 정해져 있지 않고 개수 제한도 없습니다. 센서를 장착한 위치로 블록 이름을 정하고,
센서마다 CAN 인터페이스를 따로 지정하십시오.

각 node는 자기 블록의 키를 이름으로 사용합니다. 따라서 topic과 parameter, service가 모두 그
이름을 달고 있어서, 센서 하나에만 적용되고 다른 센서에는 영향을 주지 않습니다. 아래 블록 세 개를
사용하면 `/right_wrist_ft/wrench`와 `/left_wrist_ft/wrench`, `/tool_flange_ft/wrench`를
발행합니다.

모든 센서에 공통인 설정은 `/**:` 블록에 둘 수 있습니다. 이 블록은 파일 안의 모든 node에
적용되므로, 센서마다 다른 값만 개별 블록에 남습니다.

```yaml
/**:
  ros__parameters:
    can_mode:  fd_brs
    data_type: float_combined
    rate_hz:   1000

right_wrist_ft:
  ros__parameters:
    can_interface: can0

left_wrist_ft:
  ros__parameters:
    can_interface: can1

tool_flange_ft:
  ros__parameters:
    can_interface: can2
```

> [!IMPORTANT]
> 센서 두 개가 CAN 인터페이스 하나를 함께 쓸 수는 없습니다. 한 프로세스는 센서 하나를 담당하며,
> 다른 인스턴스가 이미 사용 중인 인터페이스는 열지 않고 거부합니다. 두 driver가 같은 버스에
> 명령을 섞어 보내는 상황을 막기 위해서입니다.

## Sharing a channel with the AIDIN Hand Gen2

센서는 AIDIN Hand Gen2와 같은 비트 타이밍을 사용하므로, CAN 어댑터 하나의 같은 채널을 로봇 핸드와
함께 쓸 수 있습니다. `can_interface`에 로봇 핸드의 인터페이스를 지정하고 `can_mode`는 `fd_brs`로
둡니다. 로봇 핸드는 BRS를 켠 CAN FD로 통신하며, `fd_brs`는 센서 데이터도 같은 5 Mbit/s data 구간으로
보내므로 로봇 핸드가 이미 사용하는 버스에서 센서 프레임이 차지하는 시간이 짧아집니다.

```yaml
right_wrist_ft:
  ros__parameters:
    can_interface: can0   # 오른손이 연결된 인터페이스
    can_mode:      fd_brs
```

기본 transmit ID는 로봇 핸드의 ID와 겹치지 않습니다. 로봇 핸드는 `0x111`~`0x138`과
`0x211`~`0x238` 범위의 ID를 사용하고, 센서는 두 ID 각각과 그 뒤의 두 ID로 보내므로 기본값에서는
`0x430`~`0x432`와 `0x330`~`0x332`를 사용합니다. `set_id_can20`이나 `set_id_canfd`를 바꿀 때는 두
범위가 모두 로봇 핸드의 범위를 벗어나게 하십시오.

센서 두 개가 인터페이스 하나를 함께 쓸 수 없다는 규칙은 그대로입니다. 이 규칙은 센서 사이에만
적용되므로, 로봇 핸드와는 인터페이스를 함께 써도 됩니다.

## Troubleshooting

인터페이스에 문제가 있으면 driver가 실행할 명령을 함께 알려 줍니다.

| Message | 원인 | 조치 |
|---|---|---|
| `there is no interface called can0` | 어댑터가 연결되지 않았거나 커널 드라이버가 없습니다 | `ip -br link show type can`으로 확인하고, [Installation](#installation)에 따라 드라이버를 확인합니다 |
| `can0 is down` | 인터페이스는 있지만 준비되지 않았습니다 | `sudo scripts/can_up.sh can0` |
| `can0 is not set up for CAN FD (MTU 16)` | `can_mode`는 FD를 요구하는데 인터페이스가 클래식으로 준비되어 있습니다 | message에 표시된 `ip link` 명령을 실행하거나 `can_mode`를 `classic`으로 바꿉니다 |
| `another instance already holds can0` | 같은 인터페이스에서 다른 driver가 작동 중입니다 | 먼저 실행한 쪽을 종료하거나, 이 센서에 별도 인터페이스를 지정합니다 |
| `this data type puts six axes in one frame and needs CAN FD` | combined 계열 `data_type`을 `can_mode: classic`과 함께 설정했습니다 | `int6`를 사용하거나 `can_mode`를 `fd_brs`로 바꿉니다 |
| `parameter 'rate_hz' cannot be set because it is read-only` | 기동할 때만 읽는 parameter에 `ros2 param set`을 실행했습니다 | parameter 파일을 고치고 다시 실행합니다 |
| `the sensor reports 2.0=... but the parameters ask for ...` | 센서가 파일에 지정한 transmit ID를 받아들이지 않았습니다 | `set_id_can20`과 `set_id_canfd` 값이 의도한 것인지 확인합니다. driver는 센서가 응답한 ID로 계속 읽습니다 |

node는 시작되었는데 message가 오지 않으면, 센서의 transmit ID가 driver가 기대하는 값과 같은지
확인합니다.

```bash
ros2 service call /right_wrist_ft/confirm_id std_srvs/srv/Trigger
```

응답에 센서가 답한 ID가 들어 있습니다. 센서가 응답하지 않으면 `candump can0`으로 센서가 프레임을
보내고 있는지 확인합니다.
