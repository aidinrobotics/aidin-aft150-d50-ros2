# aidin_aft150_d50_description

URDF and `ros2_control` description of the AIDIN AFT150-D50.

- `urdf/aft150_d50.ros2_control.xacro` holds two macros. `aft150_d50_ros2_control` writes the
  `<ros2_control>` block with the hardware plugin, its parameters and the six state interfaces.
  `aft150_d50_link` writes the sensor link and, given a `parent`, the fixed joint to it.
- `urdf/aft150_d50.urdf.xacro` is a standalone description holding one sensor, for bringing the
  driver up on its own. A real robot includes the macro file and calls the macros from its own
  description instead, so the sensor lands on the right link.

Call the macros with the sensor name, which becomes the `ros2_control` component name, the node
name and the prefix of every state interface.

```xml
<xacro:include filename="$(find aidin_aft150_d50_description)/urdf/aft150_d50.ros2_control.xacro"/>

<xacro:aft150_d50_link name="right_wrist_ft" parent="tool0"/>
<xacro:aft150_d50_ros2_control name="right_wrist_ft" can_interface="can0"/>
```

`can_mode`, `data_type`, `rate_hz`, `set_id_can20` and `set_id_canfd` are optional and default to
the same values the standalone node uses. The Korean guide is in [README.ko.md](README.ko.md).
