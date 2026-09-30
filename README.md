<div align="center">

<a href="https://www.aidinrobotics.co.kr/"><img height="56" src="docs/assets/aidin_logo.png" alt="AIDIN AFT150-D50 — AIDIN Robotics"></a>

<h1>AIDIN AFT150-D50 ROS 2</h1>

A ROS 2 driver for the AIDIN AFT150-D50 six-axis force/torque sensor over SocketCAN. It supports
every update rate the sensor offers, and it publishes force in newtons and torque in
newton-metres. Run it as a standalone node, or as a `ros2_control` sensor interface that joins an
existing robot's resource manager.

[![version](https://img.shields.io/badge/version-0.1.0-blue)](CHANGELOG.md) [![ROS 2](https://img.shields.io/badge/ROS%202-Humble-brightgreen)](#system-requirements)

[Install](#installation) | [Changelog](CHANGELOG.md) | [Official Site](https://www.aidinrobotics.co.kr/) | English | [한국어](README.ko.md)

</div>

## System requirements

We verify that the driver builds and runs on the configuration below.

| Component | Requirement |
|---|---|
| Operating System | Ubuntu 22.04 |
| ROS 2 | Humble |
| CAN interface | USB CAN-FD adapter (SocketCAN), 1 Mbit/s nominal, 4 Mbit/s data phase |

An slcan serial adapter such as a CANable works as well, with the limits described in
[Setting up the CAN interface](#setting-up-the-can-interface).

## Installation

```bash
sudo ./install.sh
colcon build --packages-up-to aidin_aft150_d50_bringup
```

`install.sh` prepares the machine: it builds the CAN kernel drivers this distribution does not
ship, installs a udev rule that sets an interface up when an adapter is plugged in, and adds you
to the `dialout` group. Log out and back in once so the group membership takes effect.

The driver itself is a set of ROS 2 packages, so `colcon` builds it.

| Package | Contents |
|---|---|
| [`aidin_aft150_d50_driver`](aidin_aft150_d50_driver/README.md) | Communication layer and the standalone node |
| [`aidin_aft150_d50_hardware`](aidin_aft150_d50_hardware/README.md) | ros2_control sensor interface |
| [`aidin_aft150_d50_description`](aidin_aft150_d50_description/README.md) | URDF and ros2_control xacro macros |
| [`aidin_aft150_d50_bringup`](aidin_aft150_d50_bringup/README.md) | Launch files and parameter files |

All four packages share one version number and are released together.

## Setting up the CAN interface

With the udev rule installed, plugging an adapter in is enough. To set an interface up by hand:

```bash
sudo scripts/can_up.sh can0        # USB adapter, CAN FD at 1M/4M
sudo scripts/slcan_up.sh ttyACM0   # CANable, which appears as slcan0
sudo scripts/can_up.sh vcan0       # virtual CAN, with no hardware
```

The bit timing must match the sensor. `can_up.sh` uses the sensor's factory values, and
`/etc/default/aft-can` holds them if a sensor is configured differently.

The driver opens an interface that is already up. It does not configure the link itself, and it
reports the command to run when the interface is missing or down.

> [!IMPORTANT]
> An slcan adapter carries classic CAN 2.0 only. Its frames hold eight bytes, so a sensor reached
> through one must use the `int6` data type. The combined types need CAN FD.

## Running the driver

Both launch files read the same parameter file.

```bash
# Standalone node
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py

# ros2_control, with a broadcaster per sensor
ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py
```

### Launch arguments

| Argument | Accepted by | Default |
|---|---|---|
| `params_file` | both launch files | `config/aft150_d50_params.yaml` |
| `controllers_file` | `aft150_d50_ros2_control.launch.py` | `config/aft150_d50_controllers.yaml` |

Which CAN interface a sensor is on differs between machines, so copy the parameter file and pass
the copy rather than editing the tracked one. Either launch file accepts it:

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py \
  params_file:=~/my_aft150.yaml

ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py \
  params_file:=~/my_aft150.yaml
```

`ros2 launch aidin_aft150_d50_bringup <launch file> --show-args` lists the arguments and their
defaults.

## Topics

Both paths publish `geometry_msgs/msg/WrenchStamped`, one message per sample, but not under the
same name. The standalone node publishes on `~/wrench`, which resolves under its own node name. In
the ros2_control path the topic belongs to the broadcaster instead, and the launch file gives each
sensor a broadcaster named after it with `_broadcaster` appended.

| Path | Topic | Published by |
|---|---|---|
| Standalone node | `/<sensor name>/wrench` | `aft150_d50_node` |
| ros2_control | `/<sensor name>_broadcaster/wrench` | `force_torque_sensor_broadcaster` |

For the `right_wrist_ft` block that ships in the parameter file, those names are
`/right_wrist_ft/wrench` and `/right_wrist_ft_broadcaster/wrench`.

```bash
ros2 topic echo /right_wrist_ft/wrench
ros2 topic hz /right_wrist_ft/wrench
```

`ros2 topic hz` settles at `rate_hz` once the stream is running. The service names are the same on
both paths, and only the topic differs, because a ros2_control controller publishes under its own
node name and that name has to differ from the hardware component's.

The standalone node stamps each message with the time the kernel received the frame, on
`CLOCK_REALTIME`. That timestamp lines up with `rosbag2` and with other sensors.

> [!NOTE]
> In the ros2_control path, `force_torque_sensor_broadcaster` stamps with the control cycle
> instead. Humble's broadcaster has no way to carry a sensor timestamp, so use the standalone
> node when the sample time itself matters.

## Parameters

The parameter file is an ordinary ROS 2 parameter file, so each top-level key is a node name and
each block configures the sensor that node drives. `config/aft150_d50_params.yaml` ships with two
blocks, which is what a robot with a sensor on each wrist looks like.

```yaml
right_wrist_ft:
  ros__parameters:
    can_interface: can0
    can_mode:      fd_brs
    data_type:     float_combined
    rate_hz:       1000
    set_id_can20:  0x230
    set_id_canfd:  0x330

left_wrist_ft:
  ros__parameters:
    can_interface: can1
    can_mode:      fd_brs
    data_type:     float_combined
    rate_hz:       1000
    set_id_can20:  0x230
    set_id_canfd:  0x330
```

Launching this file starts two nodes, `/right_wrist_ft` and `/left_wrist_ft`. Adding a third
sensor means adding a third block; see
[Configuring more than one sensor](#configuring-more-than-one-sensor) for what the blocks share
and what they must not.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `can_interface` | `string` | `can0` | Name of the SocketCAN interface to open, as `ip link` lists it. The interface must already be up |
| `can_mode` | `string` | `fd_brs` | Frame format the driver sends and expects: `classic`, `fd` or `fd_brs`. `fd_brs` adds the bitrate switch, which is what reaches 1 kHz |
| `data_type` | `string` | `float_combined` | What the sensor transmits. One of the three values in the table below |
| `rate_hz` | `int` | `1000` | How often the sensor transmits a sample, in Hz: `100`, `250`, `500` or `1000` |
| `set_id_can20` | `int` | `0x230` | CAN 2.0 ID the sensor transmits on, `0x000`–`0x7FF`. See [Changing the transmit ID](#changing-the-transmit-id) |
| `set_id_canfd` | `int` | `0x330` | CAN FD ID the sensor transmits on, `0x000`–`0x7FF` |
| `frame_id` | `string` | `<node name>_link` | `header.frame_id` of the published wrench. Set it to the URDF link the sensor is mounted on |

Every parameter is read once at startup and none can be changed while the driver runs. To change a
setting, edit the parameter file and launch again.

> [!IMPORTANT]
> The parameters are declared read-only on purpose. Changing the mode, the data type or the rate
> makes the sensor stop transmitting for roughly 100 ms while the driver restores the stream, and
> in the `ros2_control` path `read()` hands out the last sample for that whole time. A controller
> holding a force target would act on a stale reading for a hundred cycles, with nothing in the
> graph to show it. `ros2 param set` on any of them is refused.

`ros2 param get` still reports what the driver is running with.

### Data types

| Value | Frames per sample | Needs CAN FD | Description |
|---|---|---|---|
| `int6` | 2 | no | Force and torque arrive in separate frames as scaled integers |
| `int12_combined` | 1 | yes | All six axes in one frame as scaled integers |
| `float_combined` | 1 | yes | All six axes in one frame as 32-bit floats |

The two combined types put all six axes in one frame, which does not fit a classic CAN frame. The
driver rejects them unless `can_mode` is `fd` or `fd_brs`.

An `int6` sample needs both frames, so the driver discards a torque frame whose force frame was
lost rather than pairing it with an older one.

### Changing the transmit ID

`set_id_can20` and `set_id_canfd` are the ID the sensor should use, not a report of what it uses
now. At startup the driver asks the sensor for its current IDs and sends a change only when they
differ, so launching with an unchanged file writes nothing to the sensor. The sensor keeps the
value in non-volatile memory, so it survives a power cycle.

When the sensor does not adopt the new ID, the driver logs a warning naming both IDs and carries
on reading with the one the sensor reported, rather than refusing to start.

> [!WARNING]
> The base ID occupies three consecutive addresses, and the driver checks only that the value is
> in range. A value that overlaps the other bus, or that collides with a command address, makes
> the sensor unreachable. Call `~/restore_defaults` to recover.

Use `~/confirm_id` to find out which IDs the sensor is actually using.

## Services

The driver provides three services, all `std_srvs/srv/Trigger`. Anything that carries a value is
a parameter instead, so there are no custom service definitions.

| Service | Effect |
|---|---|
| `~/set_bias` | Takes the load on the sensor at this moment as zero |
| `~/confirm_id` | Asks the sensor for its transmit IDs and returns them in the response |
| `~/restore_defaults` | Returns the sensor to its factory settings, including its transmit IDs |

```bash
ros2 service call /right_wrist_ft/set_bias std_srvs/srv/Trigger
```

> [!WARNING]
> The driver never sends `~/set_bias` on its own. Whatever rests on the sensor at startup would
> otherwise become its zero, which on a robot is a safety problem. Call it only when you know the
> sensor is unloaded.

`~/restore_defaults` runs as soon as you call it. There is no confirmation step.

## Configuring more than one sensor

There is no fixed left and right and no limit on the number of sensors. Name each block after the
place the sensor is mounted, and give each one its own CAN interface.

Each node takes its name from its block, so its topic, its parameters and its services all carry
that name and address one sensor while leaving the others alone. The three blocks below publish
`/right_wrist_ft/wrench`, `/left_wrist_ft/wrench` and `/tool_flange_ft/wrench`.

Settings that are the same everywhere can go in a `/**:` block, which applies to every node in the
file. Only what differs then stays in the individual blocks.

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
> Two sensors must not share a CAN interface. One process drives one sensor, and the driver
> refuses to open an interface another instance already holds rather than letting the two
> interleave commands on the same bus.

## Troubleshooting

The driver reports the command to run whenever the interface is at fault.

| Message | Cause | What to do |
|---|---|---|
| `there is no interface called can0` | The adapter is not plugged in, or its kernel driver is missing | `ip -br link show type can`, then `sudo ./install.sh` if the driver is missing |
| `can0 is down` | The interface exists but is not up | `sudo scripts/can_up.sh can0` |
| `can0 is not set up for CAN FD (MTU 16)` | The interface is up in classic mode while `can_mode` asks for FD | Run the `ip link` command the message prints, or set `can_mode` to `classic` |
| `another instance already holds can0` | A second driver is running on the same interface | Stop the first one, or give this sensor its own interface |
| `this data type puts six axes in one frame and needs CAN FD` | A combined `data_type` with `can_mode: classic` | Use the `int6` data type, or switch `can_mode` to `fd_brs` |
| `parameter 'rate_hz' cannot be set because it is read-only` | A `ros2 param set` on a parameter that is read at startup | Edit the parameter file and launch again |
| `the sensor reports 2.0=... but the parameters ask for ...` | The sensor did not adopt the transmit ID the file asks for | Check that `set_id_can20` and `set_id_canfd` are what you meant. The driver keeps reading on the reported IDs |

If the node starts but no messages arrive, check that the sensor's transmit IDs match what the
driver expects:

```bash
ros2 service call /right_wrist_ft/confirm_id std_srvs/srv/Trigger
```

The response reports the IDs the sensor answered with. When the sensor does not answer at all,
`candump can0` shows whether it is transmitting.

## Third-party software

`scripts/drivers/` contains the PEAK and IXXAT kernel driver sources, both under the GPL-2.0.
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) carries the notices and the modifications made to
them.
