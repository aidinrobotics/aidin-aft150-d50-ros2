# aidin_aft150_d50_description

URDF, mesh and `ros2_control` description of the AIDIN AFT150-D50.

| File | Contents |
|---|---|
| [xacro/aft150_d50_unit.urdf.xacro](xacro/aft150_d50_unit.urdf.xacro) | `aft150_d50_unit` macro. Writes one sensor's body and frames, without mounting it anywhere |
| [ros2_control/aft150_d50.ros2_control.xacro](ros2_control/aft150_d50.ros2_control.xacro) | `aft150_d50_ros2_control` macro. Writes the `<ros2_control>` block of one sensor from the parameter file |
| [xacro/aft150_d50.urdf.xacro](xacro/aft150_d50.urdf.xacro) | The sensors of a parameter file on `world`, for the launch files in `aidin_aft150_d50_bringup`. `left_wrist_ft` and `right_wrist_ft` have places of their own, and a sensor under any other name sits on the origin |
| [meshes/aft150_d50.stl](meshes/aft150_d50.stl) | Sensor mesh |
| [rviz/view_sensor.rviz](rviz/view_sensor.rviz) | RViz configuration for `aft150_d50_view.launch.py` |

## Frames

`aft150_d50_unit` writes three frames, named after the sensor name given to it.

| Frame | Position |
|---|---|
| `<name>_base_link` | Centre of the mounting face. The mesh hangs here, and +Z points through the body to the tool face |
| `<name>_link` | Measurement frame, which the wrench message is stamped with. It sits at the tool face centre, 17.7 mm along +Z |
| `<name>_tool_link` | Centre of the tool face, 17.7 mm along +Z. Attach a tool or an AIDIN Hand Gen2 here |

Each joint is named after its child link with `_link` replaced by `_joint`. The xacro that calls
the macro writes the joint that mounts the sensor, and names it `<name>_base_joint` by the same
rule.

## Macros

| Macro | Arguments | What it writes |
|---|---|---|
| `aft150_d50_unit` | `name` | The three frames above, the mesh, and the two joints inside the sensor |
| `aft150_d50_ros2_control` | `name`, `params_file` | One `<ros2_control>` block with the hardware plugin, its parameters and the six state interfaces |

`aft150_d50_ros2_control` reads the `name` block and the `/**` block from `params_file`, merges
them, and writes a `<param>` for each setting. A setting the file leaves out keeps the driver's
default.

How to add the sensor to an existing `ros2_control` system with these two macros is in
[7. Integration](../README.md#7-integration).

The Korean guide is in [README.ko.md](README.ko.md).
