# aidin_aft150_d50_driver

Sensor communication library for the AIDIN AFT150-D50 and the standalone node `aft150_d50_node`.

- `aft150_d50_node` opens the CAN interface, reads the sensor, and publishes
  `geometry_msgs/msg/WrenchStamped` on `/<sensor_name>/wrench`. It also provides the two services.
- Start the node with the launch files of
  [`aidin_aft150_d50_bringup`](../aidin_aft150_d50_bringup/README.md).
- The sensor communication library ships for x86_64 and aarch64. On any other architecture the
  build stops, and its message names the supported architectures.

Parameters, services and topics are in the [repository README](../README.md). The Korean guide is
in [README.ko.md](README.ko.md).
