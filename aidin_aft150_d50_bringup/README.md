# aidin_aft150_d50_bringup

Launch files and parameter files for the AIDIN AFT150-D50.

| Launch file | Parameter file | What it starts |
|---|---|---|
| `launch/aft150_d50.launch.py` | `config/aft150_d50_standalone.yaml` | One standalone node per sensor, each publishing `/<sensor name>/wrench` |
| `launch/aft150_d50_ros2_control.launch.py` | `config/aft150_d50_ros2_control.yaml` | `controller_manager` with one hardware component per sensor, `robot_state_publisher`, and every controller the file declares |
| `launch/aft150_d50_view.launch.py` | `config/aft150_d50_standalone.yaml` | `robot_state_publisher` and RViz, with no hardware |

- The default files set up one sensor, `left_wrist_ft`. `aft150_d50_standalone_dual.yaml` and
  `aft150_d50_ros2_control_dual.yaml` set up two, `left_wrist_ft` and `right_wrist_ft`; pass one as
  `params_file` to run both.
- `aft150_d50_standalone.yaml` holds one block per sensor, keyed by its node name, so adding a
  sensor means adding a block.
- `aft150_d50_ros2_control.yaml` holds the same sensor blocks, `controller_manager`, and one
  `force_torque_sensor_broadcaster` per sensor named `<sensor name>_broadcaster`, which publishes
  `/<sensor name>_broadcaster/wrench`. Adding a sensor means adding its block and its broadcaster.
- The `ros2_control` and view launches build the robot description by running the description
  package's `aft150_d50.urdf.xacro` on the parameter file, so no URDF file has to be maintained by
  hand.

Every launch file takes `params_file` to read another parameter file.

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py params_file:=~/my_aft150.yaml
```

The Korean guide is in [README.ko.md](README.ko.md).
