<div align="center">

<a href="https://www.aidinrobotics.co.kr/"><img height="56" src="docs/assets/aidin_logo.png" alt="AIDIN AFT150-D50 — AIDIN Robotics"></a>

<h1>AIDIN AFT150-D50 ROS 2</h1>

AIDIN AFT150-D50 6축 힘·토크 센서를 SocketCAN으로 읽는 ROS 2 driver입니다. 센서가 제공하는 모든
업데이트 레이트를 지원하며, 힘은 N, 토크는 Nm 단위로 발행합니다. 독립 node로
실행하거나, 기존 `ros2_control` 시스템에 합류하는 `ros2_control` sensor interface로 실행할 수
있습니다.

[![version](https://img.shields.io/badge/version-0.1.0-blue)](CHANGELOG.md) [![ROS 2](https://img.shields.io/badge/ROS%202-Humble-brightgreen)](#1-system-requirements)

[Install](#2-installation) | [Changelog](CHANGELOG.md) | [Official Site](https://www.aidinrobotics.co.kr/) | [English](README.md) | 한국어

</div>

## Contents

&nbsp;&nbsp;[**1. System requirements**](#1-system-requirements)<br>
&nbsp;&nbsp;[**2. Installation**](#2-installation)<br>
&nbsp;&nbsp;[**3. Setting up the CAN interface**](#3-setting-up-the-can-interface)<br>
&nbsp;&nbsp;[**4. Bringup**](#4-bringup)<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[4.1 Parameters](#41-parameters)<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[4.2 Standalone node](#42-standalone-node)<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[4.3 ros2_control](#43-ros2_control)<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[4.4 RViz view](#44-rviz-view)<br>
&nbsp;&nbsp;[**5. Topics**](#5-topics)<br>
&nbsp;&nbsp;[**6. Services**](#6-services)<br>
&nbsp;&nbsp;[**7. Integration**](#7-integration)<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[7.1 Adding the sensor to a ros2_control system](#71-adding-the-sensor-to-a-ros2_control-system)<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;[7.2 Sharing a CAN channel with the AIDIN Hand Gen2](#72-sharing-a-can-channel-with-the-aidin-hand-gen2)<br>
&nbsp;&nbsp;[**8. Troubleshooting**](#8-troubleshooting)

## 1. System requirements

아래 구성에서 빌드와 실행을 확인했습니다.

| Component | Requirement |
|---|---|
| Operating System | Ubuntu 22.04 |
| ROS 2 | Humble |
| CAN interface | USB CAN-FD 어댑터(SocketCAN), nominal 1 Mbit/s, data 구간 5 Mbit/s |

candleLight 펌웨어의 CANable도 사용할 수 있습니다.

## 2. Installation

```bash
sudo apt install can-utils
colcon build --packages-up-to aidin_aft150_d50_bringup
```

`can-utils`는 [8. Troubleshooting](#8-troubleshooting)에서 사용하는 `candump`를 제공합니다.

어댑터의 커널 드라이버가 있어야 합니다. 사용하는 어댑터의 드라이버를 확인합니다.

```bash
modinfo peak_usb | head -2       # PEAK PCAN-USB FD
modinfo gs_usb   | head -2       # candleLight 펌웨어의 CANable
```

`filename` 줄이 나오면 드라이버가 있는 것입니다. `Module ... not found`가 나오면 커널에 드라이버가
없는 것입니다. 기본 Ubuntu 커널이면 `sudo apt install linux-modules-extra-$(uname -r)`을 실행하고,
직접 빌드한 커널이나 Jetson 같은 vendor 커널이면 `CONFIG_CAN_PEAK_USB` 또는 `CONFIG_CAN_GS_USB`를
켜고 커널을 다시 빌드합니다.

저장소는 아래 package로 구성됩니다.

| Package | Contents |
|---|---|
| [`aidin_aft150_d50_driver`](aidin_aft150_d50_driver/README.ko.md) | 통신 계층과 독립 node |
| [`aidin_aft150_d50_hardware`](aidin_aft150_d50_hardware/README.ko.md) | ros2_control sensor interface |
| [`aidin_aft150_d50_description`](aidin_aft150_d50_description/README.ko.md) | 센서 모델과 ros2_control xacro 매크로 |
| [`aidin_aft150_d50_bringup`](aidin_aft150_d50_bringup/README.ko.md) | launch 파일과 parameter 파일 |

네 package는 버전 번호를 하나로 관리하며 함께 릴리스합니다.

## 3. Setting up the CAN interface

driver를 실행하기 전에 interface를 준비합니다. 이 설정은 재부팅하거나 어댑터를 다시 연결하면
사라지므로, 그때마다 다시 준비해야 합니다. `can0`은 `ip -br link show type can`에 표시되는
어댑터의 이름으로 바꾸십시오.

```bash
sudo ip link set can0 down 2>/dev/null || true
sudo ip link set can0 type can \
  bitrate 1000000 sample-point 0.875 sjw 10 \
  dbitrate 5000000 dsample-point 0.875 dsjw 2 \
  fd on
sudo ip link set can0 up
sudo ip link set can0 txqueuelen 1000
```

interface가 CAN FD로 준비되었는지 확인합니다.

```bash
ip -details link show can0
```

```text
can <FD> state ERROR-ACTIVE (berr-counter tx 0 rx 0)
```

이 줄에 `<FD>`가 표시되면 interface가 CAN FD 프레임을 전달합니다.

driver는 이미 준비된 interface를 열기만 합니다. interface를 직접 설정하지 않으며, interface가
없거나 내려가 있으면 실행할 명령을 알려 줍니다.

센서와 driver는 아래 CAN ID를 사용합니다. 센서는 항상 이 ID로 보내며, 다른 ID로 설정된 센서는
driver가 기동할 때 이 값으로 되돌립니다.

| Frame | `classic` | `fd`, `fd_brs` |
|---|---|---|
| driver가 보내는 명령 | `0x420` | `0x320` |
| 힘, `int6` | `0x430` | `0x330` |
| 토크, `int6` | `0x431` | `0x331` |
| 여섯 축, `int12_combined`·`float_combined` | — | `0x332` |

driver가 기동할 때 센서의 ID를 확인하면, 센서는 `0x430`과 `0x330`으로 응답합니다.

## 4. Bringup

### 4.1 Parameters

| Launch file | Parameter file | 설명 |
|---|---|---|
| `aft150_d50.launch.py` | `aft150_d50_standalone.yaml` | [4.2 Standalone node](#42-standalone-node) |
| `aft150_d50_ros2_control.launch.py` | `aft150_d50_ros2_control.yaml` | [4.3 ros2_control](#43-ros2_control) |
| `aft150_d50_view.launch.py` | `aft150_d50_standalone.yaml` | [4.4 RViz view](#44-rviz-view) |

parameter 파일은 `aidin_aft150_d50_bringup`의 `config/`에 있습니다. 기본 파일은 센서 하나,
`left_wrist_ft`를 설정합니다. `aft150_d50_standalone_dual.yaml`과 `aft150_d50_ros2_control_dual.yaml`은
`left_wrist_ft`와 `right_wrist_ft` 두 개를 설정합니다. 다른 파일을 쓰려면 `params_file` 인자로
넘깁니다. 모든 launch 파일이 이 인자를 받으며, `--show-args`로 기본값을 확인할 수 있습니다.

독립 node와 `ros2_control`은 같은 센서 parameter를 읽습니다. 센서마다 센서 이름을 키로 하는 블록을
하나씩 두며, 이 블록을 센서 설정 블록이라고 부릅니다. 센서 이름은 node 이름도 되고, parameter는
`ros__parameters` 아래에 적습니다.

```yaml
left_wrist_ft:
  ros__parameters:
    can_interface: can0
    can_mode:      fd_brs
    data_type:     float_combined
    rate_hz:       250
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `can_interface` | `string` | `can0` | 센서가 연결된 CAN interface 이름입니다. [3. Setting up the CAN interface](#3-setting-up-the-can-interface)에서 올린 interface를 지정합니다 |
| `can_mode` | `string` | `fd_brs` | 버스에서 쓰는 프레임 형식입니다. 아래 값 중 하나입니다 |
| `data_type` | `string` | `float_combined` | 센서가 샘플을 보내는 형식입니다. 아래 값 중 하나입니다 |
| `rate_hz` | `int` | `250` | 센서가 샘플을 보내는 주기이며 단위는 Hz입니다. 센서는 `100`·`250`·`500`·`1000`을 지원하며, 그 밖의 값은 그 값 이하에서 가장 큰 지원 값으로 적용합니다. `100`보다 작은 값을 넣으면 driver가 시작을 거부합니다 |
| `frame_id` | `string` | `<센서 이름>_link` | 독립 node가 발행하는 wrench의 `header.frame_id`입니다. `ros2_control`에서는 broadcaster의 `frame_id`가 정합니다 |

`can_mode`에는 다음 값 중 하나를 씁니다.

- `classic`: 클래식 CAN 2.0입니다. 프레임에 `int6` 데이터 타입만 담을 수 있습니다.
- `fd`: CAN FD입니다.
- `fd_brs`: BRS를 켠 CAN FD이며, 데이터를 5 Mbit/s로 보냅니다. 1000 Hz로 쓰려면 이 값이 필요합니다.

`data_type`에는 다음 값 중 하나를 씁니다. 어느 값이든 driver는 힘을 N, 토크를 Nm 단위로 발행합니다.

- `int6`: 정수 형식입니다. 모든 `can_mode`에서 쓸 수 있습니다.
- `int12_combined`: 정수 형식입니다. `can_mode`가 `fd` 또는 `fd_brs`여야 합니다.
- `float_combined`: 32비트 부동소수점 형식입니다. `can_mode`가 `fd` 또는 `fd_brs`여야 합니다.

> [!IMPORTANT]
> 센서 두 개가 CAN interface 하나를 함께 쓸 수는 없습니다. driver 인스턴스 하나는 센서 하나를
> 담당하며, 다른 인스턴스가 이미 사용 중인 interface는 열지 않고 거부합니다. 두 driver가 같은
> 버스에 명령을 섞어 보내는 상황을 막기 위해서입니다.

### 4.2 Standalone node

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py \
  params_file:=~/my_aft150.yaml
```

launch 파일은 `aft150_d50_standalone.yaml`의 블록마다 블록 이름으로 node를 하나씩 실행합니다. 기본
파일은 `/left_wrist_ft`를, `aft150_d50_standalone_dual.yaml`은 `/left_wrist_ft`와
`/right_wrist_ft`를 실행합니다. 센서를 추가하려면 블록을 하나 더 추가합니다.

센서마다 프로세스가 따로 실행됩니다. interface가 없는 센서는 그 interface 이름을 알리는 message를
남기고 종료하며, 나머지 센서는 계속 동작합니다.

### 4.3 ros2_control

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py \
  params_file:=~/my_aft150_ros2_control.yaml
```

launch 파일은 센서마다 hardware 컴포넌트를 하나씩 둔 `controller_manager`와
`robot_state_publisher`를 실행하고, `controller_manager` 아래에 선언된 controller를 모두 실행합니다.
그래서 `aft150_d50_ros2_control.yaml`은 세 종류의 블록으로 이루어집니다. `controller_manager`,
센서마다 하나씩인 `force_torque_sensor_broadcaster`, 그리고
[4.1 Parameters](#41-parameters)의 센서 설정 블록입니다.

```yaml
controller_manager:
  ros__parameters:
    update_rate: 1000
    left_wrist_ft_broadcaster:
      type: force_torque_sensor_broadcaster/ForceTorqueSensorBroadcaster

left_wrist_ft_broadcaster:
  ros__parameters:
    sensor_name: left_wrist_ft
    frame_id:    left_wrist_ft_link

left_wrist_ft:
  ros__parameters:
    can_interface: can0
    can_mode:      fd_brs
```

최상위 블록 가운데 `controller_manager`도 아니고 그 아래에 선언된 controller도 아닌 블록이 센서 설정
블록입니다.
따라서 센서를 하나 추가하려면 세 곳을 적습니다. `controller_manager` 아래의 broadcaster 선언,
`sensor_name`을 그 센서로 지정한 broadcaster 블록, 그리고 센서 설정 블록입니다.

`update_rate`는 `controller_manager`가 hardware를 읽는 주기입니다. 센서의 전송 주기와는 다르지만,
센서가 보내는 것보다 느리게 읽으면 샘플을 건너뛰므로 사용하는 `rate_hz` 중 가장 큰 값 이상으로
둡니다.

> [!IMPORTANT]
> `controller_manager`는 모든 센서를 한 프로세스에서 실행합니다. 기동할 때 interface가 없는 센서가
> 하나라도 있으면 프로세스 전체가 종료되어 나머지 센서도 함께 멈춥니다.

### 4.4 RViz view

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50_view.launch.py
```

launch 파일은 hardware 없이 `robot_state_publisher`와 RViz를 실행하고, parameter 파일에 있는 센서를
모두 frame과 함께 표시합니다. frame 구성은
[aidin_aft150_d50_description](aidin_aft150_d50_description/README.ko.md#frames)에 있습니다.

힘을 함께 보려면 같은 `params_file`로 독립 node launch를 실행해 둔 상태에서 `/<센서 이름>/wrench`에
대한 Wrench display를 추가합니다. driver는 sensor data QoS로 발행하므로 display의 Reliability
Policy를 Best Effort로 바꾸어야 화살표가 표시됩니다. `ros2_control` launch는 이미
`robot_state_publisher`를 실행하므로, 그 launch와 함께 쓸 때는 `rviz2`만 실행합니다.

`left_wrist_ft`는 `world` 원점에서 왼쪽으로 10 cm, `right_wrist_ft`는 오른쪽으로 10 cm 떨어진 곳에
놓입니다. 그 밖의 이름을 가진 센서는 `world` 원점에 놓입니다. 위치를 정하려면 두 센서처럼
[aft150_d50.urdf.xacro](aidin_aft150_d50_description/xacro/aft150_d50.urdf.xacro)에 그 센서의 블록을
추가하고, 같은 파일의 `listed`에도 이름을 넣습니다.

## 5. Topics

독립 node와 `ros2_control` 모두 샘플 하나마다 `geometry_msgs/msg/WrenchStamped` message를 하나씩
발행하지만 topic 이름은 서로 다릅니다. 독립 node는 자신의 node 이름 아래에서 해석되는 `~/wrench`로
발행합니다. `ros2_control`에서는 broadcaster가 topic을 소유합니다.

| Bringup | Topic | 발행하는 주체 |
|---|---|---|
| [4.2 Standalone node](#42-standalone-node) | `/<센서 이름>/wrench` | `aft150_d50_node` |
| [4.3 ros2_control](#43-ros2_control) | `/<센서 이름>_broadcaster/wrench` | `force_torque_sensor_broadcaster` |

`left_wrist_ft`라면 각각 `/left_wrist_ft/wrench`와 `/left_wrist_ft_broadcaster/wrench`입니다.

```bash
ros2 topic echo /left_wrist_ft/wrench
```

service 이름은 독립 node와 `ros2_control`에서 동일하며 topic 이름만 다릅니다. `ros2_control`의
controller는 자신의 node 이름 아래에 발행하는데, 그 이름은 hardware component의 이름과 달라야 하기
때문입니다.

독립 node는 커널이 프레임을 수신한 시각을 `CLOCK_REALTIME` 기준으로 각 message에 기록합니다.

> [!NOTE]
> `ros2_control`에서는 `force_torque_sensor_broadcaster`가 그 message를 발행한 제어 사이클의 시각을
> 기록합니다. 샘플 시각 자체가 중요하다면 독립 node를 사용하십시오.

## 6. Services

독립 node와 `ros2_control`은 같은 service 두 개를 제공하며, 둘 다 `std_srvs/srv/Trigger`입니다.

| Service | 동작 |
|---|---|
| `~/set_bias` | 현재 센서에 걸린 하중을 영점으로 지정합니다 |
| `~/restore_defaults` | transmit ID를 포함해 센서 설정을 공장 기본값으로 되돌립니다 |

```bash
ros2 service call /left_wrist_ft/set_bias std_srvs/srv/Trigger
```

## 7. Integration

이 절은 기존 `ros2_control` 시스템에 센서를 추가해, 그 시스템의 `controller_manager`가 센서를 읽게
하는 방법을 설명합니다. 이 방법에는 [4. Bringup](#4-bringup)의 launch 파일이 필요하지 않습니다.

### 7.1 Adding the sensor to a ros2_control system

시스템의 description xacro에서 센서의 parameter 파일을 xacro 인자로 받고,
`aidin_aft150_d50_description`의 두 매크로를 호출합니다. `aft150_d50_unit`은 센서 모델을 작성하고,
고정 joint `<name>_base_joint`는 센서를 장착할 link에 센서를 붙입니다. `aft150_d50_ros2_control`은
parameter 파일의 센서 설정 블록을 읽어 센서의 `<ros2_control>` 블록을 작성합니다.

```xml
<!-- 시스템의 description xacro -->
<xacro:arg name="aft150_d50_params_file"
           default="$(find aidin_aft150_d50_bringup)/config/aft150_d50_ros2_control.yaml"/>

<xacro:include filename="$(find aidin_aft150_d50_description)/xacro/aft150_d50_unit.urdf.xacro"/>
<xacro:include filename="$(find aidin_aft150_d50_description)/ros2_control/aft150_d50.ros2_control.xacro"/>

<xacro:aft150_d50_unit name="left_wrist_ft"/>
<joint name="left_wrist_ft_base_joint" type="fixed">
  <parent link="tool0"/>
  <child link="left_wrist_ft_base_link"/>
  <origin xyz="0 0 0" rpy="0 0 0"/>
</joint>

<xacro:aft150_d50_ros2_control name="left_wrist_ft"
                               params_file="$(arg aft150_d50_params_file)"/>
```

description을 만드는 launch 파일은 parameter 파일의 경로를 이 인자로 넘깁니다. 인자를 넘기지 않으면
`aidin_aft150_d50_bringup`의 `aft150_d50_ros2_control.yaml`을 읽습니다.

```python
# 시스템의 launch 파일
robot_description = ParameterValue(
    Command([
        'xacro ', xacro_file,
        ' aft150_d50_params_file:=',
        PathJoinSubstitution([FindPackageShare('my_bringup'), 'config', 'aft150_d50.yaml']),
    ]),
    value_type=str,
)
```

wrench는 `force_torque_sensor_broadcaster`가 발행하며, 시스템의 다른 controller와 같은 방법으로
선언하고 spawn합니다. broadcaster에 필요한 두 블록은 [4.3 ros2_control](#43-ros2_control)에 있습니다.

> [!IMPORTANT]
> 기존 시스템과 함께 `aft150_d50_ros2_control.launch.py`를 실행하지 마십시오. 이 launch는 별도의
> `controller_manager`와 `robot_state_publisher`를 실행합니다. 그 hardware 인스턴스는 기존 시스템의
> 인스턴스가 이미 점유한 CAN interface를 열지 못하고, `/robot_description`과 변환은 두 프로세스에서
> 중복으로 publish됩니다.

### 7.2 Sharing a CAN channel with the AIDIN Hand Gen2

센서는 AIDIN Hand Gen2와 같은 CAN 설정
([3. Setting up the CAN interface](#3-setting-up-the-can-interface))을 사용하므로, 어댑터 하나의 같은
채널을 AIDIN Hand Gen2와 함께 쓸 수 있습니다. `can_interface`에는 AIDIN Hand Gen2가 연결된
interface를 지정합니다.

> [!IMPORTANT]
> 채널을 함께 쓰려면 CAN FD 어댑터와 `can_mode: fd_brs`가 필요합니다. AIDIN Hand Gen2가 BRS를 켠
> CAN FD로 통신하기 때문입니다.

```yaml
left_wrist_ft:
  ros__parameters:
    can_interface: can0   # 왼쪽 AIDIN Hand Gen2가 연결된 interface
    can_mode:      fd_brs
```

[3. Setting up the CAN interface](#3-setting-up-the-can-interface)의 센서 CAN ID는 AIDIN Hand Gen2의
ID 범위인 `0x111`~`0x138`, `0x211`~`0x238`과 겹치지 않습니다. 버스를 함께 쓸 때는 `0x420`, `0x320`,
`0x430`~`0x432`, `0x330`~`0x332`를 센서용으로 비워 두십시오.

센서 두 개가 interface 하나를 함께 쓸 수 없다는 규칙은 그대로입니다. 이 규칙은 센서 사이에만
적용되므로, AIDIN Hand Gen2와는 interface를 함께 써도 됩니다.

## 8. Troubleshooting

interface에 문제가 있으면 driver가 실행할 명령을 함께 알려 줍니다.

| Message | 원인 | 조치 |
|---|---|---|
| `there is no interface called can0` | 어댑터가 연결되지 않았거나 커널 드라이버가 없습니다 | `ip -br link show type can`으로 확인하고, [2. Installation](#2-installation)에 따라 드라이버를 확인합니다 |
| `can0 is down` | interface는 있지만 준비되지 않았습니다 | [3. Setting up the CAN interface](#3-setting-up-the-can-interface)의 명령을 실행합니다 |
| `can0 is not set up for CAN FD (MTU 16)` | `can_mode`는 FD를 요구하는데 interface가 클래식으로 준비되어 있습니다 | message에 표시된 `ip link` 명령을 실행하거나 `can_mode`를 `classic`으로 바꿉니다 |
| `another instance already holds can0` | 같은 interface에서 다른 driver가 작동 중입니다 | 먼저 실행한 쪽을 종료하거나, 이 센서에 별도 interface를 지정합니다 |
| `this data type puts six axes in one frame and needs CAN FD` | combined 계열 `data_type`을 `can_mode: classic`과 함께 설정했습니다 | `int6`를 사용하거나 `can_mode`를 `fd_brs`로 바꿉니다 |
| `parameter 'rate_hz' cannot be set because it is read-only` | 기동할 때만 읽는 parameter에 `ros2 param set`을 실행했습니다 | parameter 파일을 고치고 다시 실행합니다 |
| `the sensor reports 2.0=... instead of the defaults ...` | 센서가 기본 transmit ID로 바뀌지 않았습니다 | `~/restore_defaults`를 호출한 뒤 다시 실행합니다. driver는 센서가 응답한 ID로 계속 읽습니다 |

node는 시작되었는데 message가 오지 않으면, 센서가 프레임을 보내고 있는지 확인합니다.

```bash
candump can0
```

센서에서 오는 프레임이 없으면 센서 전원이 꺼져 있거나 이 interface에 연결되어 있지 않은 것입니다.
