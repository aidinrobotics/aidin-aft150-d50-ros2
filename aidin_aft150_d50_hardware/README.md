# aidin_aft150_d50_hardware

`ros2_control` sensor interface for the AIDIN AFT150-D50.

- The plugin is `aidin_aft150_d50_hardware/Aft150D50SensorInterface`. Declare it with
  `<ros2_control type="sensor">`. It provides state interfaces only and takes no commands.
- The six state interfaces are `<sensor_name>/force.{x,y,z}` and `<sensor_name>/torque.{x,y,z}`.
  `force_torque_sensor_broadcaster` reads these six through its `sensor_name`.
- The broadcaster, not this component, publishes the wrench message on
  `/<sensor_name>_broadcaster/wrench`.
- Settings arrive as `<param>` entries in the `<hardware>` block. The xacro macro in
  [`aidin_aft150_d50_description`](../aidin_aft150_d50_description/README.md) reads the parameter
  file and writes them.
- The services have the same names as under the standalone node (`/<sensor_name>/set_bias`,
  `/<sensor_name>/restore_defaults`).
- When sensor frames stop arriving for a moment, the broadcaster keeps running and publishes the
  last values.

The Korean guide is in [README.ko.md](README.ko.md).
