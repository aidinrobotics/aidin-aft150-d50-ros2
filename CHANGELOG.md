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
  and the sensor joins an existing robot's resource manager, which means an arm and a wrist sensor
  share one `controller_manager` and one update cycle. The wrench then comes from the broadcaster
  on `/<sensor name>_broadcaster/wrench` rather than from the component itself.

  > [!NOTE]
  > Humble's broadcaster stamps with the control cycle and has no way to carry a sensor timestamp.
  > Use the standalone node when the sample time itself matters.

- **Seven parameters cover every setting the sensor exposes, and all of them are read once at
  startup.** `can_interface`, `can_mode`, `data_type`, `rate_hz`, `set_id_can20`, `set_id_canfd`
  and `frame_id`. They are declared read-only, because changing the mode, the data type or the
  rate makes the sensor stop transmitting for roughly 100 ms while the driver restores the stream,
  and in the `ros2_control` path `read()` hands out the last sample for that whole time. A
  controller holding a force target would act on a stale reading for a hundred cycles. Edit the
  parameter file and launch again to change a setting.
- **The driver writes a transmit ID only when the sensor is not already using it.** At startup it
  asks the sensor for its current IDs, compares them with `set_id_can20` and `set_id_canfd`, and
  sends a change only on a difference, so an unchanged parameter file puts no flash write in the
  boot path. When the sensor does not adopt the new ID, the driver warns and keeps reading on the
  ID the sensor reported instead of refusing to start.
- **The sensor can share a CAN channel with an AIDIN Hand Gen2.** It uses the robot hand's bit
  timing, and `set_id_can20` defaults to `0x430` rather than the factory `0x230`, because the
  factory range `0x230`–`0x232` overlaps the tactile IDs of the left hand. The first launch
  therefore moves a new sensor to `0x430` once. Keep `can_mode` at `fd_brs` on a shared channel,
  because the robot hand runs CAN FD with the bitrate switch.
- **Three services cover the actions that carry no value: `~/set_bias`, `~/confirm_id` and
  `~/restore_defaults`.** All three are `std_srvs/srv/Trigger`, so the driver defines no service
  types of its own and `rosidl` stays out of the build. Anything that carries a value is a
  parameter instead.
- **The `int6`, `int12_combined` and `float_combined` data types and all four update rates are
  supported.** The two combined types need CAN FD, and the driver rejects them when `can_mode` is
  `classic` rather than failing later on the wire.
- **One parameter file describes any number of sensors.** Each top-level block is one sensor and
  the key is its node name, so adding a sensor means adding a block. Both launch files read the
  same file, and neither imposes a fixed left and right.
- **`scripts/can_up.sh` and `scripts/slcan_up.sh` bring an interface up by hand, as the AIDIN
  Hand Gen2's is.** `can_up.sh` asks for the robot hand's timing, CAN FD at 1 Mbit/s nominal and
  5 Mbit/s data phase with both sample points at 87.5%, and falls back to classic CAN 2.0 when the
  adapter refuses it, because not every adapter or firmware reaches 5 Mbit/s. `slcan_up.sh`
  attaches a CANable on slcan firmware through `slcand`. Nothing brings an interface up on its
  own, so run the script again after a reboot or a re-plug. The adapter needs only the kernel's
  own driver, `peak_usb` for a PEAK PCAN-USB FD or `gs_usb` for a CANable on candleLight firmware.
- **The driver refuses to open an interface another instance already holds.** Starting the
  standalone node and the `ros2_control` component on the same sensor would interleave their
  commands, and the second one now fails to start with a message that says so.

[Unreleased]: https://github.com/aidinrobotics/aidin-aft150-d50-ros2/commits/develop
