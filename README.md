<div align="center">

<a href="https://www.aidinrobotics.co.kr/"><img height="56" src="docs/assets/aidin_logo.png" alt="AIDIN AFT150-D50 — AIDIN Robotics"></a>

<h1>AIDIN AFT150-D50 ROS 2</h1>

A ROS 2 driver for the AIDIN AFT150-D50 six-axis force/torque sensor over SocketCAN. It supports
every update rate the sensor offers, and it publishes force in newtons and torque in
newton-metres. Run it as a standalone node, or as a `ros2_control` sensor interface that joins an
existing `ros2_control` system.

[![version](https://img.shields.io/badge/version-0.1.0-blue)](CHANGELOG.md) [![ROS 2](https://img.shields.io/badge/ROS%202-Humble-brightgreen)](#1-system-requirements)

[Install](#2-installation) | [Changelog](CHANGELOG.md) | [Official Site](https://www.aidinrobotics.co.kr/) | English | [한국어](README.ko.md)

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

We verify that the driver builds and runs on the configuration below.

| Component | Requirement |
|---|---|
| Operating System | Ubuntu 22.04 |
| ROS 2 | Humble |
| CAN interface | USB CAN-FD adapter (SocketCAN), 1 Mbit/s nominal, 5 Mbit/s data phase |

A CANable on candleLight firmware works as well.

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

A `filename` line means the driver is present. `Module ... not found` means the kernel lacks it:
on a stock Ubuntu kernel run `sudo apt install linux-modules-extra-$(uname -r)`, and on a kernel
you built yourself or a vendor kernel such as a Jetson's, enable `CONFIG_CAN_PEAK_USB` or
`CONFIG_CAN_GS_USB` and rebuild it.

The repository consists of the packages below.

| Package | Contents |
|---|---|
| [`aidin_aft150_d50_driver`](aidin_aft150_d50_driver/README.md) | Communication layer and the standalone node |
| [`aidin_aft150_d50_hardware`](aidin_aft150_d50_hardware/README.md) | ros2_control sensor interface |
| [`aidin_aft150_d50_description`](aidin_aft150_d50_description/README.md) | Sensor model and ros2_control xacro macros |
| [`aidin_aft150_d50_bringup`](aidin_aft150_d50_bringup/README.md) | Launch files and parameter files |

All four packages share one version number and are released together.

## 3. Setting up the CAN interface

Bring the interface up before starting the driver. The setting does not survive a reboot or a
re-plug, so bring it up again after either. Replace `can0` with the name that
`ip -br link show type can` lists for the adapter.

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

The driver opens an interface that is already up. It does not configure the link itself, and it
reports the command to run when the interface is missing or down.

The sensor and the driver use the CAN IDs below. The sensor always transmits on these, and the
driver moves a sensor set to other IDs back to them at startup.

| Frame | `classic` | `fd`, `fd_brs` |
|---|---|---|
| Commands from the driver | `0x420` | `0x320` |
| Force, `int6` | `0x430` | `0x330` |
| Torque, `int6` | `0x431` | `0x331` |
| Six axes, `int12_combined` and `float_combined` | — | `0x332` |

`0x430` and `0x330` also carry the sensor's answer when the driver checks its IDs at startup.

## 4. Bringup

### 4.1 Parameters

| Launch file | Parameter file | Section |
|---|---|---|
| `aft150_d50.launch.py` | `aft150_d50_standalone.yaml` | [4.2 Standalone node](#42-standalone-node) |
| `aft150_d50_ros2_control.launch.py` | `aft150_d50_ros2_control.yaml` | [4.3 ros2_control](#43-ros2_control) |
| `aft150_d50_view.launch.py` | `aft150_d50_standalone.yaml` | [4.4 RViz view](#44-rviz-view) |

The parameter files are in `config/` of `aidin_aft150_d50_bringup`. The default files set up one
sensor, `left_wrist_ft`. `aft150_d50_standalone_dual.yaml` and `aft150_d50_ros2_control_dual.yaml`
set up two, `left_wrist_ft` and `right_wrist_ft`. To use another file, pass it with `params_file`.
Every launch file takes it, and `--show-args` lists its default.

The standalone node and `ros2_control` read the same sensor parameters. Each sensor has a settings
block keyed by its name, which also becomes its node name, with the parameters under
`ros__parameters`.

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
| `can_interface` | `string` | `can0` | Name of the CAN interface the sensor is on, brought up as in [3. Setting up the CAN interface](#3-setting-up-the-can-interface) |
| `can_mode` | `string` | `fd_brs` | Frame format on the bus. One of the values below |
| `data_type` | `string` | `float_combined` | Format the sensor sends a sample in. One of the values below |
| `rate_hz` | `int` | `250` | How often the sensor sends a sample, in Hz. The sensor offers `100`, `250`, `500` and `1000`, and any other value runs at the highest of these that does not exceed it. Below `100`, the driver refuses to start |
| `frame_id` | `string` | `<sensor name>_link` | `header.frame_id` of the wrench the standalone node publishes. Under `ros2_control` the broadcaster's own `frame_id` sets it |

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

> [!IMPORTANT]
> Two sensors must not share a CAN interface. One driver instance drives one sensor, and it
> refuses to open an interface another instance already holds rather than letting the two
> interleave commands on the same bus.

### 4.2 Standalone node

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py \
  params_file:=~/my_aft150.yaml
```

The launch file starts one node per block in `aft150_d50_standalone.yaml`, named after the block, so
the default file starts `/left_wrist_ft` and `aft150_d50_standalone_dual.yaml` starts
`/left_wrist_ft` and `/right_wrist_ft`. Adding a sensor means adding a block.

Each sensor runs in its own process. A sensor whose interface is missing stops with a message
naming the interface, and the others carry on.

### 4.3 ros2_control

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py \
  params_file:=~/my_aft150_ros2_control.yaml
```

The launch file starts `controller_manager` with one hardware component per sensor, starts
`robot_state_publisher`, and spawns every controller declared under `controller_manager`.
`aft150_d50_ros2_control.yaml` therefore holds three kinds of block: `controller_manager`, one
`force_torque_sensor_broadcaster` per sensor, and the sensor settings blocks of
[4.1 Parameters](#41-parameters).

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

A top-level block that is neither `controller_manager` nor a controller declared under it is a
sensor settings block. Adding a sensor therefore takes three entries: its broadcaster under
`controller_manager`, the broadcaster's block with `sensor_name` set to the sensor, and the
sensor's settings block.

`update_rate` is how often `controller_manager` reads the hardware. It is not the sensor rate, but
reading slower than the sensor sends skips samples, so keep it at or above the highest `rate_hz`.

> [!IMPORTANT]
> `controller_manager` runs every sensor in one process. A sensor whose interface is missing at
> startup stops the whole process, and the other sensors with it.

### 4.4 RViz view

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50_view.launch.py
```

The launch file starts `robot_state_publisher` and RViz, with no hardware, and shows every sensor
in the parameter file with its frames. The frames are described in
[aidin_aft150_d50_description](aidin_aft150_d50_description/README.md#frames).

To see the force, keep the standalone launch running with the same `params_file` and add a Wrench
display on `/<sensor name>/wrench`. The driver publishes with the sensor data QoS, so set the
display's Reliability Policy to Best Effort, or it shows nothing. The `ros2_control` launch already
starts `robot_state_publisher`, so run only `rviz2` alongside it.

`left_wrist_ft` sits 10 cm to the left of the `world` origin and `right_wrist_ft` 10 cm to the
right. A sensor under any other name sits on the `world` origin. To place it, give it a block of
its own in [aft150_d50.urdf.xacro](aidin_aft150_d50_description/xacro/aft150_d50.urdf.xacro), as
the two sensors above have, and add its name to `listed` there.

## 5. Topics

The standalone node and `ros2_control` both publish `geometry_msgs/msg/WrenchStamped`, one message
per sample, but not under the same name. The standalone node publishes on `~/wrench`, which
resolves under its own node name. Under `ros2_control` the topic belongs to the broadcaster
instead.

| Bringup | Topic | Published by |
|---|---|---|
| [4.2 Standalone node](#42-standalone-node) | `/<sensor name>/wrench` | `aft150_d50_node` |
| [4.3 ros2_control](#43-ros2_control) | `/<sensor name>_broadcaster/wrench` | `force_torque_sensor_broadcaster` |

For `left_wrist_ft`, those names are `/left_wrist_ft/wrench` and
`/left_wrist_ft_broadcaster/wrench`.

```bash
ros2 topic echo /left_wrist_ft/wrench
```

The service names are the same under the standalone node and `ros2_control`, and only the topic
differs, because a `ros2_control` controller publishes under its own node name and that name has
to differ from the hardware component's.

The standalone node stamps each message with the time the kernel received the frame, on
`CLOCK_REALTIME`.

> [!NOTE]
> Under `ros2_control`, `force_torque_sensor_broadcaster` stamps each message with the time of the
> control cycle that published it. Use the standalone node when the sample time itself matters.

## 6. Services

The standalone node and `ros2_control` provide the same two services, both
`std_srvs/srv/Trigger`.

| Service | Effect |
|---|---|
| `~/set_bias` | Takes the load on the sensor at this moment as zero |
| `~/restore_defaults` | Returns the sensor to its factory settings, including its transmit IDs |

```bash
ros2 service call /left_wrist_ft/set_bias std_srvs/srv/Trigger
```

## 7. Integration

This section adds the sensor to an existing `ros2_control` system, so that the system's own
`controller_manager` reads it. This needs none of the launch files of [4. Bringup](#4-bringup).

### 7.1 Adding the sensor to a ros2_control system

In the system's description xacro, take the sensor's parameter file as an argument and call the two
macros of `aidin_aft150_d50_description`. `aft150_d50_unit` writes the sensor's model, the fixed
joint `<name>_base_joint` mounts it on the link the sensor sits on, and `aft150_d50_ros2_control`
writes the sensor's `<ros2_control>` block from its settings block in the parameter file.

```xml
<!-- the system's description xacro -->
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

The launch file that builds the description passes the parameter file's path as that argument.
Without it, the description reads `aft150_d50_ros2_control.yaml` of `aidin_aft150_d50_bringup`.

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

The wrench comes from a `force_torque_sensor_broadcaster`, which the system declares and spawns like
its other controllers. [4.3 ros2_control](#43-ros2_control) shows its two blocks.

> [!IMPORTANT]
> Do not start `aft150_d50_ros2_control.launch.py` alongside the system. It runs a separate
> `controller_manager` and `robot_state_publisher`: its hardware instance cannot claim the CAN
> interface the system's instance already holds, and `/robot_description` and the transforms are
> published by two processes.

### 7.2 Sharing a CAN channel with the AIDIN Hand Gen2

The sensor uses the same CAN setup as the AIDIN Hand Gen2,
[3. Setting up the CAN interface](#3-setting-up-the-can-interface), so it can share a channel of
one adapter with the AIDIN Hand Gen2. Set `can_interface` to the interface the AIDIN Hand Gen2 is
on.

> [!IMPORTANT]
> A shared channel needs a CAN FD adapter and `can_mode: fd_brs`, because the AIDIN Hand Gen2
> communicates in CAN FD with the bitrate switch.

```yaml
left_wrist_ft:
  ros__parameters:
    can_interface: can0   # the interface the left AIDIN Hand Gen2 is on
    can_mode:      fd_brs
```

None of the sensor's CAN IDs in [3. Setting up the CAN interface](#3-setting-up-the-can-interface)
overlaps the AIDIN Hand Gen2, whose IDs lie in `0x111`–`0x138` and `0x211`–`0x238`. Keep `0x420`,
`0x320`, `0x430`–`0x432` and `0x330`–`0x332` free for the sensor on a shared bus.

Two sensors still cannot share an interface. That rule applies between sensors only, so the AIDIN
Hand Gen2 can share one with a sensor.

## 8. Troubleshooting

The driver reports the command to run whenever the interface is at fault.

| Message | Cause | What to do |
|---|---|---|
| `there is no interface called can0` | The adapter is not plugged in, or its kernel driver is missing | `ip -br link show type can`, then check the driver as [2. Installation](#2-installation) describes |
| `can0 is down` | The interface exists but is not up | Run the commands in [3. Setting up the CAN interface](#3-setting-up-the-can-interface) |
| `can0 is not set up for CAN FD (MTU 16)` | The interface is up in classic mode while `can_mode` asks for FD | Run the `ip link` command the message prints, or set `can_mode` to `classic` |
| `another instance already holds can0` | A second driver is running on the same interface | Stop the first one, or give this sensor its own interface |
| `this data type puts six axes in one frame and needs CAN FD` | A combined `data_type` with `can_mode: classic` | Use the `int6` data type, or switch `can_mode` to `fd_brs` |
| `parameter 'rate_hz' cannot be set because it is read-only` | A `ros2 param set` on a parameter that is read at startup | Edit the parameter file and launch again |
| `the sensor reports 2.0=... instead of the defaults ...` | The sensor did not move to its default transmit IDs | Call `~/restore_defaults` and launch again. The driver keeps reading on the IDs the sensor reported |

If the node starts but no messages arrive, check whether the sensor is transmitting at all.

```bash
candump can0
```

No frames from the sensor means it is not powered, or not connected to this interface.
