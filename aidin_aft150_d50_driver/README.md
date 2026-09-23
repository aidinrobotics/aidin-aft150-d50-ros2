# aidin_aft150_d50_driver

Communication layer for the AIDIN AFT150-D50 and the standalone ROS 2 node.

- `aft150_d50_node` opens the CAN interface, publishes `geometry_msgs/msg/WrenchStamped` on
  `~/wrench`, which resolves to `/<sensor name>/wrench`, and provides the three services. Start
  it through [`aidin_aft150_d50_bringup`](../aidin_aft150_d50_bringup/README.md).
- `include/aidin_aft150_d50_driver/aft150_d50_comms.hpp` is the boundary to the communication
  layer. `Comms::open_bus` returns a handle that owns the socket and the receive thread, and
  releasing the handle closes both.
- `include/aidin_aft150_d50_driver/aft150_d50_services.hpp` holds parameter validation and the
  service implementations. The standalone node and the `ros2_control` component both link this, so
  the two paths answer the same service names with the same behaviour.
- `prebuilt/<arch>/libaft150_d50_comms.a` is the communication layer, absorbed into this package's
  shared library rather than installed on its own. `BUILD-INFO` beside it records the version, the
  commit and the toolchain that produced it. The build stops with a message naming the
  architectures it ships when the current one is absent.

Parameters, services and topics are in the [repository README](../README.md). The Korean guide is
in [README.ko.md](README.ko.md).
