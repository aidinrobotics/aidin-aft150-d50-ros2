# Changelog

All notable changes to the AIDIN AFT150-D50 ROS 2 driver are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

The first release of the driver. It reads the AFT150-D50 over SocketCAN and publishes a wrench,
either as a standalone node or as a `ros2_control` sensor interface, with the same services and
parameters on both paths.

### Added

- **A standalone node publishes `geometry_msgs/msg/WrenchStamped` on `/<sensor name>/wrench`.** It
  takes its node name from its block in the parameter file, so the topic, the parameters and the
  services all carry the name of the sensor they belong to. It stamps each
  message with the time the kernel received the frame, on `CLOCK_REALTIME`, so the values line up
  with `rosbag2` and with other sensors on the same machine.
- **A `ros2_control` sensor interface exports the six state interfaces that
  `force_torque_sensor_broadcaster` reads.** Name the component in the ros2_control description
  and the sensor joins an existing `ros2_control` system, which means an arm and a wrist sensor
  share one `controller_manager` and one update cycle. The wrench then comes from the broadcaster
  on `/<sensor name>_broadcaster/wrench` rather than from the component itself.

  > [!NOTE]
  > The broadcaster stamps each message with the time of the control cycle that published it.
  > Use the standalone node when the sample time itself matters.

- **Five parameters cover the settings a user chooses, and all of them are read once at
  startup.** `can_interface`, `can_mode`, `data_type`, `rate_hz` and `frame_id`. They are declared
  read-only, because changing the mode, the data type or the rate makes the sensor stop
  transmitting for roughly 100 ms while the driver restores the stream, and under `ros2_control`
  `read()` hands out the last sample for that whole time. A controller holding a force target
  would act on a stale reading for a hundred cycles. Edit the parameter file and launch again to
  change a setting.
- **The sensor always transmits on its default IDs.** At startup the driver asks the sensor for its
  current IDs and moves it back to `0x430` and `0x330` only when they differ, so a sensor already
  on the defaults gets no flash write in the boot path. The IDs are not a parameter, so no value
  in the file can move the sensor onto an ID that collides with another and leave it unreachable.
  When the sensor does not move, the driver warns and keeps reading on the IDs it reported instead
  of refusing to start.
- **The sensor can share a CAN channel with an AIDIN Hand Gen2.** It uses the same CAN setup as
  the AIDIN Hand Gen2, and none of its IDs, `0x420` and `0x320` for commands and `0x430`–`0x432`
  and `0x330`–`0x332` for data, overlaps the AIDIN Hand Gen2's `0x111`–`0x138` and
  `0x211`–`0x238`. A shared channel needs a CAN FD adapter and `can_mode: fd_brs`, because the
  AIDIN Hand Gen2 communicates in CAN FD with the bitrate switch.
- **Two services cover the actions that carry no value: `~/set_bias` and
  `~/restore_defaults`.** Both are `std_srvs/srv/Trigger`, so the driver defines no service types
  of its own and `rosidl` stays out of the build. Anything that carries a value is a parameter
  instead.
- **The `int6`, `int12_combined` and `float_combined` data types and all four update rates are
  supported.** The two combined types need CAN FD, and the driver rejects them when `can_mode` is
  `classic` rather than failing later on the wire. A `rate_hz` the sensor does not offer runs at
  the highest offered rate below it, so a value like `200` starts at 100 Hz with a warning instead
  of refusing to start; only a value below 100 Hz is refused.
- **The description package ships a sensor model with three frames, and
  `aft150_d50_view.launch.py` shows it in RViz.** `<name>_base_link` carries the mesh at the
  mounting face, `<name>_link` is the measurement frame the wrench is stamped with, and
  `<name>_tool_link` is where a tool or an AIDIN Hand Gen2 attaches. The `aft150_d50_unit` macro writes
  only the sensor itself, and the description that uses it writes the joint that mounts it, so the
  macro never needs to know what it is attached to. The mesh is a placeholder of the outer size,
  and the measurement frame sits at the tool face until its datasheet position is in.
- **Each path has one parameter file that holds everything it needs, and it describes any number
  of sensors.** `aft150_d50_standalone.yaml` has one block per sensor, keyed by node name.
  `aft150_d50_ros2_control.yaml` has the same sensor blocks next to `controller_manager` and one
  broadcaster per sensor, and the `ros2_control` launch takes nothing else. A sensor runs on one
  path at a time, so neither file repeats a setting the other one needs. Both ship with one
  sensor, and a `_dual` copy of each shows two, because on the `ros2_control` path a sensor that
  fails to come up stops every other sensor in the same `controller_manager`.
- **The `<ros2_control>` macro reads the sensor's settings from the parameter file.**
  `aft150_d50_ros2_control` takes the sensor name and `params_file` and writes a `<param>` for
  each setting in the sensor's block, so no setting is written into the description or the launch
  file. The broadcasters take their `sensor_name` and `frame_id` from their own blocks in the same
  file.
- **The README brings the CAN interface up with the same `ip link` commands as the AIDIN Hand
  Gen2.** They set the AIDIN Hand Gen2's timing, CAN FD at 1 Mbit/s nominal and 5 Mbit/s data phase
  with both sample points at 87.5%, so one procedure serves both on a shared adapter. Nothing
  brings an interface up on its own, so run the commands again after a reboot or a re-plug. The
  adapter needs only the kernel's own driver, `peak_usb` for a PEAK PCAN-USB FD or `gs_usb` for a
  CANable on candleLight firmware.
- **The driver refuses to open an interface another instance already holds.** Starting the
  standalone node and the `ros2_control` component on the same sensor would interleave their
  commands, and the second one now fails to start with a message that says so.

[Unreleased]: https://github.com/aidinrobotics/aidin-aft150-d50-ros2/commits/develop
