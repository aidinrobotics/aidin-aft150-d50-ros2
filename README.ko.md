<div align="center">

<a href="https://www.aidinrobotics.co.kr/"><img height="56" src="docs/assets/aidin_logo.png" alt="AIDIN AFT150-D50 — AIDIN Robotics"></a>

<h1>AIDIN AFT150-D50 ROS 2</h1>

AIDIN AFT150-D50 6축 힘·토크 센서를 SocketCAN으로 읽는 ROS 2 driver입니다. 센서가 지원하는 모든
업데이트 레이트를 사용할 수 있으며, 힘은 N, 토크는 Nm 단위로 발행합니다. standalone node로
실행하거나, 기존 `ros2_control` 시스템에 sensor interface로 추가할 수 있습니다.

![version](https://img.shields.io/badge/version-0.1.0-blue) [![ROS 2](https://img.shields.io/badge/ROS%202-Humble-brightgreen)](#1-system-requirements)

[Install](#2-installation) | [Official Site](https://www.aidinrobotics.co.kr/) | [English](README.md) | 한국어

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

| Component | Requirement |
|---|---|
| Operating System | Ubuntu 22.04 |
| ROS 2 | Humble |
| CAN interface | USB CAN-FD 어댑터(SocketCAN), nominal 1 Mbit/s, data 구간 5 Mbit/s |

## 2. Installation

```bash
sudo apt install can-utils
colcon build --packages-up-to aidin_aft150_d50_bringup
```

`can-utils`는 [8. Troubleshooting](#8-troubleshooting)에서 사용하는 `candump`를 제공합니다.

어댑터의 커널 드라이버가 있어야 합니다. 사용하는 어댑터의 드라이버를 확인하십시오.

```bash
modinfo peak_usb | head -2       # PEAK PCAN-USB FD
modinfo gs_usb   | head -2       # candleLight 펌웨어의 CANable
```

`filename` 줄이 나오면 드라이버가 있는 것입니다. `Module ... not found`가 나오면 커널에 드라이버가
없는 것입니다. 기본 Ubuntu 커널이면 `sudo apt install linux-modules-extra-$(uname -r)`을
실행하십시오. 직접 빌드한 커널이나 Jetson 같은 vendor 커널이면 `CONFIG_CAN_PEAK_USB` 또는
`CONFIG_CAN_GS_USB`를 켜고 커널을 다시 빌드하십시오.

저장소는 아래 package로 구성됩니다.

| Package | Contents |
|---|---|
| [`aidin_aft150_d50_driver`](aidin_aft150_d50_driver/README.ko.md) | 센서 통신 라이브러리와 standalone node `aft150_d50_node` |
| [`aidin_aft150_d50_hardware`](aidin_aft150_d50_hardware/README.ko.md) | ros2_control sensor interface |
| [`aidin_aft150_d50_description`](aidin_aft150_d50_description/README.ko.md) | 센서 모델과 ros2_control xacro 매크로 |
| [`aidin_aft150_d50_bringup`](aidin_aft150_d50_bringup/README.ko.md) | launch 파일과 parameter 파일 |

## 3. Setting up the CAN interface

driver를 실행하기 전에 아래 명령으로 interface를 준비하십시오. 재부팅하거나 어댑터를 다시 연결한
뒤에도 같은 명령을 다시 실행해야 합니다. `can0`은 `ip -br link show type can`에 표시되는 어댑터의
이름으로 바꾸십시오.

```bash
sudo ip link set can0 down 2>/dev/null || true
sudo ip link set can0 type can \
  bitrate 1000000 sample-point 0.875 sjw 10 \
  dbitrate 5000000 dsample-point 0.875 dsjw 2 \
  fd on
sudo ip link set can0 up
sudo ip link set can0 txqueuelen 1000
```

interface가 CAN FD로 준비되었는지 확인하십시오.

```bash
ip -details link show can0
```

```text
can <FD> state ERROR-ACTIVE (berr-counter tx 0 rx 0)
```

이 줄에 `<FD>`가 표시되면 interface가 CAN FD 프레임을 전달합니다.

센서와 driver는 아래 CAN ID를 사용합니다.

| Frame | `classic` | `fd`, `fd_brs` |
|---|---|---|
| driver가 보내는 명령 | `0x420` | `0x320` |
| 힘, `int6` | `0x430` | `0x330` |
| 토크, `int6` | `0x431` | `0x331` |
| 여섯 축, `int12_combined`·`float_combined` | — | `0x332` |

## 4. Bringup

### 4.1 Parameters

| Launch file | Parameter file | 설명 |
|---|---|---|
| `aft150_d50.launch.py` | `aft150_d50_standalone.yaml` | [4.2 Standalone node](#42-standalone-node) |
| `aft150_d50_ros2_control.launch.py` | `aft150_d50_ros2_control.yaml` | [4.3 ros2_control](#43-ros2_control) |
| `aft150_d50_view.launch.py` | `aft150_d50_standalone.yaml` | [4.4 RViz view](#44-rviz-view) |

parameter 파일은 `aidin_aft150_d50_bringup`의 `config/`에 있습니다. 기본 파일은 센서 하나
(`left_wrist_ft`)를 설정하고, `aft150_d50_standalone_dual.yaml`과 `aft150_d50_ros2_control_dual.yaml`은
센서 두 개(`left_wrist_ft`, `right_wrist_ft`)를 설정합니다. 다른 파일을 쓰려면 `params_file` 인자로
넘기십시오. 모든 launch 파일이 이 인자를 받으며, `--show-args`로 기본값을 확인할 수 있습니다.

parameter 파일에는 센서마다 블록을 하나씩 적습니다. 블록 이름이 센서 이름이며, standalone node와
`ros2_control`이 같은 형식의 블록을 읽습니다.

```yaml
left_wrist_ft:                # 센서 블록
  ros__parameters:
    can_interface: can0
    can_mode:      fd_brs
    data_type:     float_combined
    rate_hz:       250
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `can_interface` | `string` | `can0` | 센서가 연결된 CAN interface입니다. [3. Setting up the CAN interface](#3-setting-up-the-can-interface)에서 준비한 interface를 지정합니다 |
| `can_mode` | `string` | `fd_brs` | 버스에서 쓰는 프레임 형식입니다. 아래 값 중 하나입니다 |
| `data_type` | `string` | `float_combined` | 센서가 샘플을 보내는 형식입니다. 아래 값 중 하나입니다 |
| `rate_hz` | `int` | `250` | 센서가 샘플을 보내는 주기(Hz)입니다. `100`·`250`·`500`·`1000`을 지원합니다 |
| `frame_id` | `string` | `<sensor_name>_link` | standalone node가 발행하는 wrench message의 `header.frame_id`입니다. `ros2_control`에서는 broadcaster 블록의 `frame_id`를 사용합니다 |

`can_mode`에는 다음 값 중 하나를 씁니다.

- `classic`: 클래식 CAN 2.0입니다. 프레임에 `int6` 데이터 타입만 담을 수 있습니다.
- `fd`: CAN FD입니다.
- `fd_brs`: BRS를 켠 CAN FD이며, 데이터를 5 Mbit/s로 보냅니다. 1000 Hz로 쓰려면 이 값이 필요합니다.

`data_type`에는 다음 값 중 하나를 씁니다. 어느 값이든 driver는 힘을 N, 토크를 Nm 단위로 발행합니다.

- `int6`: 정수 형식입니다. 모든 `can_mode`에서 쓸 수 있습니다.
- `int12_combined`: 정수 형식입니다. `can_mode`가 `fd` 또는 `fd_brs`여야 합니다.
- `float_combined`: 32비트 부동소수점 형식입니다. `can_mode`가 `fd` 또는 `fd_brs`여야 합니다.

`rate_hz`에 지원하지 않는 값을 넣으면, 넣은 값보다 작거나 같은 지원 값 가운데 가장 큰 값으로
동작합니다. 예를 들어 `200`을 넣으면 100 Hz로 동작합니다. `100`보다 작은 값을 넣으면 driver가 시작하지
않습니다.

> [!IMPORTANT]
> 센서마다 다른 CAN interface를 지정하십시오. driver는 다른 센서가 이미 사용 중인 interface를 열지
> 않습니다.

### 4.2 Standalone node

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py
```

기본으로 `aft150_d50_standalone.yaml`을 읽습니다.

launch 파일은 parameter 파일의 센서 블록마다 같은 이름의 node를 하나씩 실행합니다. 기본 파일로는
`/left_wrist_ft`가, `aft150_d50_standalone_dual.yaml`로는 `/left_wrist_ft`와 `/right_wrist_ft`가
실행됩니다. 센서를 추가하려면 parameter 파일에 블록을 하나 더 적으십시오.

센서마다 별도의 프로세스로 실행되므로, interface가 없는 센서의 node만 종료되고 나머지 센서는 계속
동작합니다.

### 4.3 ros2_control

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py
```

기본으로 `aft150_d50_ros2_control.yaml`을 읽습니다.

launch 파일은 `controller_manager`와 `robot_state_publisher`를 실행하고, 센서마다 hardware
컴포넌트와 `force_torque_sensor_broadcaster`를 하나씩 실행합니다. parameter 파일에는 센서마다
broadcaster 블록과 센서 블록을 하나씩 적습니다.

```yaml
controller_manager:           # controller_manager 블록
  ros__parameters:
    update_rate: 1000

left_wrist_ft_broadcaster:    # broadcaster 블록
  ros__parameters:
    type:        force_torque_sensor_broadcaster/ForceTorqueSensorBroadcaster
    sensor_name: left_wrist_ft
    frame_id:    left_wrist_ft_link

left_wrist_ft:                # 센서 블록
  ros__parameters:
    can_interface: can0
    can_mode:      fd_brs
```

broadcaster 블록에는 `type`, 읽을 센서의 이름인 `sensor_name`, wrench message의 `frame_id`를 적습니다.
launch 파일은 `type`이 있는 블록을 broadcaster로 실행하고, `controller_manager`를 제외한 나머지 블록을
센서로 읽습니다. 센서 블록의 형식은 [4.1 Parameters](#41-parameters)와 같습니다. 센서를 추가하려면
broadcaster 블록과 센서 블록을 하나씩 더 적으십시오.

> [!IMPORTANT]
> `controller_manager`는 모든 센서를 한 프로세스에서 실행합니다. 기동할 때 interface가 없는 센서가
> 하나라도 있으면 프로세스 전체가 종료되어 나머지 센서도 함께 멈춥니다.

### 4.4 RViz view

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50_view.launch.py
```

launch 파일은 parameter 파일의 센서를 RViz에 표시합니다. `left_wrist_ft`는 `world` 원점의 왼쪽에,
`right_wrist_ft`는 오른쪽에 놓이며, 다른 이름의 센서는 원점에 놓입니다.
[4.2 Standalone node](#42-standalone-node)를 함께 실행하면 `left_wrist_ft`와 `right_wrist_ft`에
가해지는 힘도 화살표로 표시됩니다.

## 5. Topics

standalone node와 `ros2_control`은 모두 샘플마다 `geometry_msgs/msg/WrenchStamped` message를 하나씩
발행합니다. topic 이름은 아래와 같습니다.

| Bringup | Topic | 발행하는 주체 |
|---|---|---|
| [4.2 Standalone node](#42-standalone-node) | `/<sensor_name>/wrench` | `aft150_d50_node` |
| [4.3 ros2_control](#43-ros2_control) | `/<sensor_name>_broadcaster/wrench` | `force_torque_sensor_broadcaster` |

`left_wrist_ft`라면 각각 `/left_wrist_ft/wrench`와 `/left_wrist_ft_broadcaster/wrench`입니다.

```bash
ros2 topic echo /left_wrist_ft/wrench
```

standalone node는 커널이 프레임을 수신한 시각(`CLOCK_REALTIME`)을 message의 `header.stamp`에
기록합니다.

> [!NOTE]
> `ros2_control`에서는 broadcaster가 message를 발행한 제어 사이클의 시각을 기록합니다. 샘플 시각이
> 중요하다면 standalone node를 사용하십시오.

## 6. Services

standalone node와 `ros2_control`은 같은 service 두 개를 제공하며, 둘 다 `std_srvs/srv/Trigger`
타입입니다.

| Service | 동작 |
|---|---|
| `~/set_bias` | 현재 센서의 값을 영점으로 지정합니다 |
| `~/restore_defaults` | 센서 설정을 공장 기본값으로 초기화합니다 |

`left_wrist_ft`의 현재 값을 영점으로 지정합니다.

```bash
ros2 service call /left_wrist_ft/set_bias std_srvs/srv/Trigger
```

`left_wrist_ft`의 설정을 초기화합니다.

```bash
ros2 service call /left_wrist_ft/restore_defaults std_srvs/srv/Trigger
```

## 7. Integration

기존 `ros2_control` 시스템에 센서를 추가하면, 시스템의 `controller_manager`가 센서를 함께 읽습니다.
이때는 [4. Bringup](#4-bringup)의 launch 파일을 사용하지 않습니다.

### 7.1 Adding the sensor to a ros2_control system

시스템의 description xacro에서 센서의 parameter 파일 경로를 xacro 인자로 받고,
`aidin_aft150_d50_description`의 두 매크로를 호출하십시오. `aft150_d50_unit`은 센서 모델을 작성하고,
`aft150_d50_ros2_control`은 parameter 파일의 센서 블록으로 `<ros2_control>` 블록을 작성합니다. 센서를
장착하는 고정 joint `<name>_base_joint`는 직접 작성하십시오.

```xml
<!-- 시스템의 description xacro -->
<xacro:arg name="aft150_d50_params_file"
           default="$(find aidin_aft150_d50_bringup)/config/aft150_d50_ros2_control.yaml"/>

<xacro:include filename="$(find aidin_aft150_d50_description)/xacro/aft150_d50_unit.urdf.xacro"/>
<xacro:include filename="$(find aidin_aft150_d50_description)/ros2_control/aft150_d50.ros2_control.xacro"/>

<xacro:aft150_d50_unit name="left_wrist_ft"/>
<joint name="left_wrist_ft_base_joint" type="fixed">
  <parent link="your_left_arm_link"/>
  <child link="left_wrist_ft_base_link"/>
  <origin xyz="0 0 0" rpy="0 0 0"/>
</joint>

<xacro:aft150_d50_ros2_control name="left_wrist_ft"
                               params_file="$(arg aft150_d50_params_file)"/>
```

시스템의 launch 파일에서 parameter 파일의 경로를 이 인자로 넘기십시오. 인자를 넘기지 않으면
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

wrench message는 `force_torque_sensor_broadcaster`가 `/<sensor_name>_broadcaster/wrench`로
발행합니다. 시스템의 다른 controller와 같은 방법으로 broadcaster를 spawn하십시오. broadcaster 블록은
[4.3 ros2_control](#43-ros2_control)과 같습니다.

> [!IMPORTANT]
> 기존 시스템과 함께 `aft150_d50_ros2_control.launch.py`를 실행하지 마십시오. 이 launch는 별도의
> `controller_manager`와 `robot_state_publisher`를 실행하므로, 기존 시스템이 이미 사용 중인 CAN
> interface를 열지 못하고 `/robot_description`과 TF가 중복으로 발행됩니다.

### 7.2 Sharing a CAN channel with the AIDIN Hand Gen2

센서는 AIDIN Hand Gen2와 같은 CAN 설정
([3. Setting up the CAN interface](#3-setting-up-the-can-interface))을 사용하므로, 어댑터의 한 채널을
AIDIN Hand Gen2와 함께 쓸 수 있습니다. `can_interface`에는 AIDIN Hand Gen2가 연결된 interface를
지정하십시오.

> [!IMPORTANT]
> 채널을 함께 쓰려면 CAN FD 어댑터와 `can_mode: fd_brs`가 필요합니다. AIDIN Hand Gen2가 BRS를 켠
> CAN FD로 통신하기 때문입니다.

```yaml
left_wrist_ft:                # 센서 블록
  ros__parameters:
    can_interface: can0       # 왼쪽 AIDIN Hand Gen2가 연결된 interface
    can_mode:      fd_brs
```

## 8. Troubleshooting

interface에 문제가 있으면 driver가 실행할 명령을 message에 함께 표시합니다.

| Message | 원인 | 조치 |
|---|---|---|
| `there is no interface called can0` | 어댑터가 연결되지 않았거나 커널 드라이버가 없습니다 | `ip -br link show type can`으로 확인하고, [2. Installation](#2-installation)에 따라 드라이버를 확인합니다 |
| `can0 is down` | interface는 있지만 준비되지 않았습니다 | [3. Setting up the CAN interface](#3-setting-up-the-can-interface)의 명령을 실행합니다 |
| `can0 is not set up for CAN FD (MTU 16)` | `can_mode`는 FD를 요구하는데 interface가 클래식으로 준비되어 있습니다 | message에 표시된 `ip link` 명령을 실행하거나 `can_mode`를 `classic`으로 바꿉니다 |
| `another instance already holds can0` | 같은 interface에서 다른 driver가 작동 중입니다 | 먼저 실행한 쪽을 종료하거나, 이 센서에 별도 interface를 지정합니다 |
| `this data type puts six axes in one frame and needs CAN FD` | combined 계열 `data_type`을 `can_mode: classic`과 함께 설정했습니다 | `int6`를 사용하거나 `can_mode`를 `fd_brs`로 바꿉니다 |
| `parameter 'rate_hz' cannot be set because it is read-only` | 기동할 때만 읽는 parameter에 `ros2 param set`을 실행했습니다 | parameter 파일을 고치고 다시 실행합니다 |
| `the sensor reports 2.0=... instead of the defaults ...` | 센서가 기본 transmit ID로 바뀌지 않았습니다 | `~/restore_defaults`를 호출한 뒤 다시 실행합니다. driver는 센서가 응답한 ID로 계속 읽습니다 |

node는 시작되었는데 message가 오지 않으면, 아래 명령을 실행해 둔 상태에서 node를 다시 시작하십시오.
센서는 driver가 설정 명령을 보낸 뒤부터 데이터를 보냅니다.

```bash
candump can0
```

driver의 명령(`0x320` 또는 `0x420`)만 보이고 센서의 데이터(`0x330`~`0x332` 또는 `0x430`~`0x431`)가
없으면, 센서 전원이 꺼져 있거나 센서가 이 interface에 연결되어 있지 않은 것입니다.
