# aidin_aft150_d50_hardware

`ros2_control` sensor interface for the AIDIN AFT150-D50.

- `Aft150D50SensorInterface` derives from `hardware_interface::SensorInterface`, so it exports
  state interfaces and takes no commands. Declare it with `<ros2_control type="sensor">`.
- The six state interfaces are `<sensor_name>/force.{x,y,z}` and `<sensor_name>/torque.{x,y,z}`.
  `force_torque_sensor_broadcaster` builds exactly these names from the sensor name and fails to
  configure when they differ.
- The component publishes no topic of its own. The broadcaster reads those six interfaces and
  publishes the wrench on `/<sensor name>_broadcaster/wrench`, one broadcaster per sensor.
- Settings arrive as `<param>` entries inside the `<hardware>` block. The xacro macro in
  [`aidin_aft150_d50_description`](../aidin_aft150_d50_description/README.md) writes them.
- The component creates a node named after the `<ros2_control name="...">` attribute and spins it
  on its own thread, which is what makes the services answer the same names as the standalone node.
- `read()` returns `OK` when no new frame has arrived and keeps the previous values. Returning an
  error would make `controller_manager` deactivate every controller using the component, so a
  cable disturbed for one cycle would take the broadcaster down until a restart.

The Korean guide is in [README.ko.md](README.ko.md).
