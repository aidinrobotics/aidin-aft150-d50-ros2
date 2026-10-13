<div align="center">

<a href="https://www.aidinrobotics.co.kr/"><img height="56" src="docs/assets/aidin_logo.png" alt="AIDIN AFT150-D50 — AIDIN Robotics"></a>

<h1>AIDIN AFT150-D50 ROS 2</h1>

A ROS 2 driver for the AIDIN AFT150-D50 six-axis force/torque sensor over SocketCAN. It supports
every update rate the sensor offers, and it publishes force in newtons and torque in
newton-metres. Run it as a standalone node, or add it to an existing `ros2_control` system as a
sensor interface.

![version](https://img.shields.io/badge/version-0.1.0-blue) [![ROS 2](https://img.shields.io/badge/ROS%202-Humble-brightgreen)](#1-system-requirements)

[Install](#2-installation) | [Official Site](https://www.aidinrobotics.co.kr/) | English | [한국어](README.ko.md)

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
| CAN interface | USB CAN-FD adapter (SocketCAN), 1 Mbit/s nominal, 5 Mbit/s data phase |

## 2. Installation

```bash
sudo apt install can-utils
colcon build --packages-up-to aidin_aft150_d50_bringup
```

`can-utils` provides `candump`, which [8. Troubleshooting](#8-troubleshooting) uses.

The adapter's kernel driver has to be present. Check the one for your adapter.

```bash
modinfo peak_usb | head -2       # PEAK PCAN-USB FD
modinfo gs_usb   | head -2       # CANable on candleLight firmware
```

A `filename` line means the driver is present. `Module ... not found` means the kernel lacks it.
On a stock Ubuntu kernel, run `sudo apt install linux-modules-extra-$(uname -r)`. On a kernel you
built yourself or a vendor kernel such as a Jetson's, enable `CONFIG_CAN_PEAK_USB` or
`CONFIG_CAN_GS_USB` and rebuild the kernel.

The repository consists of the packages below.

| Package | Contents |
|---|---|
| [`aidin_aft150_d50_driver`](aidin_aft150_d50_driver/README.md) | Sensor communication library and the standalone node `aft150_d50_node` |
| [`aidin_aft150_d50_hardware`](aidin_aft150_d50_hardware/README.md) | ros2_control sensor interface |
| [`aidin_aft150_d50_description`](aidin_aft150_d50_description/README.md) | Sensor model and ros2_control xacro macros |
| [`aidin_aft150_d50_bringup`](aidin_aft150_d50_bringup/README.md) | Launch files and parameter files |

## 3. Setting up the CAN interface

Bring the interface up with the commands below before starting the driver. Run the same commands
again after a reboot or a re-plug. Replace `can0` with the name that `ip -br link show type can`
lists for the adapter.

```bash
sudo ip link set can0 down 2>/dev/null || true
sudo ip link set can0 type can \
  bitrate 1000000 sample-point 0.875 sjw 10 \
  dbitrate 5000000 dsample-point 0.875 dsjw 2 \
  fd on
sudo ip link set can0 up
sudo ip link set can0 txqueuelen 1000
```

Check that the interface is up in CAN FD.

```bash
ip -details link show can0
```

```text
can <FD> state ERROR-ACTIVE (berr-counter tx 0 rx 0)
```

`<FD>` in this line means the interface carries CAN FD frames.

The sensor and the driver use the CAN IDs below.

| Frame | `classic` | `fd`, `fd_brs` |
|---|---|---|
| Commands from the driver | `0x420` | `0x320` |
| Force, `int6` | `0x430` | `0x330` |
| Torque, `int6` | `0x431` | `0x331` |
| Six axes, `int12_combined` and `float_combined` | — | `0x332` |

## 4. Bringup

### 4.1 Parameters

| Launch file | Parameter file | Section |
|---|---|---|
| `aft150_d50.launch.py` | `aft150_d50_standalone.yaml` | [4.2 Standalone node](#42-standalone-node) |
| `aft150_d50_ros2_control.launch.py` | `aft150_d50_ros2_control.yaml` | [4.3 ros2_control](#43-ros2_control) |
| `aft150_d50_view.launch.py` | `aft150_d50_standalone.yaml` | [4.4 RViz view](#44-rviz-view) |

The parameter files are in `config/` of `aidin_aft150_d50_bringup`. The default files set up one
sensor (`left_wrist_ft`), and `aft150_d50_standalone_dual.yaml` and
`aft150_d50_ros2_control_dual.yaml` set up two (`left_wrist_ft`, `right_wrist_ft`). To use another
file, pass it with `params_file`. Every launch file takes this argument, and `--show-args` lists
its default.

A parameter file holds one block per sensor. The block's name is the sensor name, and the
standalone node and `ros2_control` read blocks of the same format.

```yaml
left_wrist_ft:                # sensor block
  ros__parameters:
    can_interface: can0
    can_mode:      fd_brs
    data_type:     float_combined
    rate_hz:       250
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `can_interface` | `string` | `can0` | Name of the CAN interface the sensor is on, brought up as in [3. Setting up the CAN interface](#3-setting-up-the-can-interface) |
| `can_mode` | `string` | `fd_brs` | Frame format on the bus. One of the values below |
| `data_type` | `string` | `float_combined` | Format the sensor sends a sample in. One of the values below |
| `rate_hz` | `int` | `250` | How often the sensor sends a sample, in Hz. The sensor supports `100`, `250`, `500` and `1000` |
| `frame_id` | `string` | `<sensor_name>_link` | `header.frame_id` of the wrench message the standalone node publishes. Under `ros2_control` the `frame_id` of the broadcaster block applies |

`can_mode` takes one of these values.

- `classic`: classic CAN 2.0. Its frames hold only the `int6` data type.
- `fd`: CAN FD.
- `fd_brs`: CAN FD with the bitrate switch, which sends the data at 5 Mbit/s. A rate of 1000 Hz
  needs it.

`data_type` takes one of these values. Whichever it is, the driver publishes the force in newtons
and the torque in newton-metres.

- `int6`: integers. Works with every `can_mode`.
- `int12_combined`: integers. Needs `fd` or `fd_brs`.
- `float_combined`: 32-bit floats. Needs `fd` or `fd_brs`.

A `rate_hz` the sensor does not support runs at the highest supported rate that does not exceed
it. For example, `200` runs at 100 Hz. Below `100`, the driver does not start.

> [!IMPORTANT]
> Give each sensor its own CAN interface. The driver does not open an interface that another sensor
> already holds.

### 4.2 Standalone node

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py
```

By default it reads `aft150_d50_standalone.yaml`.

The launch file starts one node per sensor block in the parameter file, named after the block. The
default file starts `/left_wrist_ft`, and `aft150_d50_standalone_dual.yaml` starts `/left_wrist_ft`
and `/right_wrist_ft`. To add a sensor, write one more block in the parameter file.

Each sensor runs in its own process, so only the node of a sensor whose interface is missing stops,
and the other sensors carry on.

### 4.3 ros2_control

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py
```

By default it reads `aft150_d50_ros2_control.yaml`.

The launch file starts `controller_manager` and `robot_state_publisher`, and runs one hardware
component and one `force_torque_sensor_broadcaster` for each sensor. The parameter file holds one
broadcaster block and one sensor block for each sensor.

```yaml
controller_manager:           # controller_manager block
  ros__parameters:
    update_rate: 1000

left_wrist_ft_broadcaster:    # broadcaster block
  ros__parameters:
    type:        force_torque_sensor_broadcaster/ForceTorqueSensorBroadcaster
    sensor_name: left_wrist_ft
    frame_id:    left_wrist_ft_link

left_wrist_ft:                # sensor block
  ros__parameters:
    can_interface: can0
    can_mode:      fd_brs
```

A broadcaster block holds the `type`, the name of the sensor to read as `sensor_name`, and the
`frame_id` of the wrench message. The launch file spawns every block with a `type` as a
broadcaster, and reads every other block except `controller_manager` as a sensor. A sensor block
has the format of [4.1 Parameters](#41-parameters). To add a sensor, write one more broadcaster
block and one more sensor block.

> [!IMPORTANT]
> `controller_manager` runs every sensor in one process. A sensor whose interface is missing at
> startup stops the whole process, and the other sensors with it.

### 4.4 RViz view

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50_view.launch.py
```

The launch file shows the sensors in the parameter file in RViz. `left_wrist_ft` sits to the left
of the `world` origin, `right_wrist_ft` to the right, and a sensor under any other name on the
origin. With [4.2 Standalone node](#42-standalone-node) running, the force on `left_wrist_ft` and
`right_wrist_ft` shows as arrows too.

## 5. Topics

The standalone node and `ros2_control` both publish one `geometry_msgs/msg/WrenchStamped` message
per sample, on the topics below.

| Bringup | Topic | Published by |
|---|---|---|
| [4.2 Standalone node](#42-standalone-node) | `/<sensor_name>/wrench` | `aft150_d50_node` |
| [4.3 ros2_control](#43-ros2_control) | `/<sensor_name>_broadcaster/wrench` | `force_torque_sensor_broadcaster` |

For `left_wrist_ft`, those names are `/left_wrist_ft/wrench` and
`/left_wrist_ft_broadcaster/wrench`.

```bash
ros2 topic echo /left_wrist_ft/wrench
```

The standalone node writes the time the kernel received the frame, on `CLOCK_REALTIME`, into each
message's `header.stamp`.

> [!NOTE]
> Under `ros2_control`, the broadcaster stamps each message with the time of the control cycle that
> published it. Use the standalone node when the sample time matters.

## 6. Services

The standalone node and `ros2_control` provide the same two services, both of type
`std_srvs/srv/Trigger`.

| Service | Effect |
|---|---|
| `~/set_bias` | Takes the sensor's present reading as zero |
| `~/restore_defaults` | Resets the sensor's settings to the factory defaults |

To take the present reading of `left_wrist_ft` as zero:

```bash
ros2 service call /left_wrist_ft/set_bias std_srvs/srv/Trigger
```

To reset the settings of `left_wrist_ft`:

```bash
ros2 service call /left_wrist_ft/restore_defaults std_srvs/srv/Trigger
```

## 7. Integration

When you add the sensor to an existing `ros2_control` system, the system's `controller_manager`
reads the sensor as well. You then use none of the launch files of [4. Bringup](#4-bringup).

### 7.1 Adding the sensor to a ros2_control system

In the system's description xacro, take the path of the sensor's parameter file as an xacro argument
and call the two macros of `aidin_aft150_d50_description`. `aft150_d50_unit` writes the sensor
model, and `aft150_d50_ros2_control` writes the `<ros2_control>` block from the sensor block in the
parameter file. Write the fixed joint `<name>_base_joint` that mounts the sensor yourself.

```xml
<!-- the system's description xacro -->
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

In the system's launch file, pass the parameter file's path as that argument. Without it, the
description reads `aft150_d50_ros2_control.yaml` of `aidin_aft150_d50_bringup`.

```python
# the system's launch file
robot_description = ParameterValue(
    Command([
        'xacro ', xacro_file,
        ' aft150_d50_params_file:=',
        PathJoinSubstitution([FindPackageShare('my_bringup'), 'config', 'aft150_d50.yaml']),
    ]),
    value_type=str,
)
```

`force_torque_sensor_broadcaster` publishes the wrench message on
`/<sensor_name>_broadcaster/wrench`. Spawn the broadcaster the same way as the system's other
controllers. Its block is the same as in [4.3 ros2_control](#43-ros2_control).

> [!IMPORTANT]
> Do not start `aft150_d50_ros2_control.launch.py` alongside the system. That launch file runs a
> separate `controller_manager` and `robot_state_publisher`, so it cannot open the CAN interface
> the system already holds, and `/robot_description` and TF are published twice.

### 7.2 Sharing a CAN channel with the AIDIN Hand Gen2

The sensor uses the same CAN setup as the AIDIN Hand Gen2
([3. Setting up the CAN interface](#3-setting-up-the-can-interface)), so it can share one channel of
an adapter with the AIDIN Hand Gen2. Set `can_interface` to the interface the AIDIN Hand Gen2 is
on.

> [!IMPORTANT]
> A shared channel needs a CAN FD adapter and `can_mode: fd_brs`, because the AIDIN Hand Gen2
> communicates in CAN FD with the bitrate switch.

```yaml
left_wrist_ft:                # sensor block
  ros__parameters:
    can_interface: can0       # the interface the left AIDIN Hand Gen2 is on
    can_mode:      fd_brs
```

## 8. Troubleshooting

When the interface is at fault, the driver prints the command to run in its message.

| Message | Cause | What to do |
|---|---|---|
| `there is no interface called can0` | The adapter is not plugged in, or its kernel driver is missing | `ip -br link show type can`, then check the driver as [2. Installation](#2-installation) describes |
| `can0 is down` | The interface exists but is not up | Run the commands in [3. Setting up the CAN interface](#3-setting-up-the-can-interface) |
| `can0 is not set up for CAN FD (MTU 16)` | The interface is up in classic mode while `can_mode` asks for FD | Run the `ip link` command the message prints, or set `can_mode` to `classic` |
| `another instance already holds can0` | A second driver is running on the same interface | Stop the first one, or give this sensor its own interface |
| `this data type puts six axes in one frame and needs CAN FD` | A combined `data_type` with `can_mode: classic` | Use the `int6` data type, or switch `can_mode` to `fd_brs` |
| `parameter 'rate_hz' cannot be set because it is read-only` | A `ros2 param set` on a parameter that is read at startup | Edit the parameter file and launch again |
| `the sensor reports 2.0=... instead of the defaults ...` | The sensor did not move to its default transmit IDs | Call `~/restore_defaults` and launch again. The driver keeps reading on the IDs the sensor reported |

If the node starts but no messages arrive, start the node again with the command below running.
The sensor sends data only after the driver has sent its setup commands.

```bash
candump can0
```

If only the driver's commands (`0x320` or `0x420`) appear and no sensor data (`0x330`–`0x332` or
`0x430`–`0x431`) follows, the sensor is not powered, or not connected to this interface.
