# aidin_aft150_d50_bringup

Launch files and parameter files for the AIDIN AFT150-D50.

| Launch file | Parameter file | What it starts |
|---|---|---|
| `launch/aft150_d50.launch.py` | `config/aft150_d50_standalone.yaml` | One standalone node per sensor, each publishing the wrench message on `/<sensor_name>/wrench` |
| `launch/aft150_d50_ros2_control.launch.py` | `config/aft150_d50_ros2_control.yaml` | `controller_manager` and `robot_state_publisher`, with one hardware component and one broadcaster per sensor |
| `launch/aft150_d50_view.launch.py` | `config/aft150_d50_standalone.yaml` | `robot_state_publisher` and RViz, with no hardware |

- The default files set up one sensor (`left_wrist_ft`). `aft150_d50_standalone_dual.yaml` and
  `aft150_d50_ros2_control_dual.yaml` set up two (`left_wrist_ft`, `right_wrist_ft`).
- `aft150_d50_standalone.yaml` holds one block per sensor, and the block's name becomes the node
  name. To add a sensor, write one more block.
- `aft150_d50_ros2_control.yaml` holds the `controller_manager` block and, for each sensor, one
  broadcaster block and one sensor block. A block with a `type` is a broadcaster block. To add a
  sensor, write one more of each.
- The `ros2_control` and RViz launch files pass the parameter file to the description package's
  `aft150_d50.urdf.xacro` to build the robot description, so no URDF file needs to be kept by hand.

To use another parameter file, pass it with `params_file`. Every launch file takes this argument.

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py params_file:=~/my_aft150.yaml
```

The parameters are listed in the [repository README](../README.md#41-parameters). The Korean guide
is in [README.ko.md](README.ko.md).
