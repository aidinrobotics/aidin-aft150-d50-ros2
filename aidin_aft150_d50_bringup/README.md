# aidin_aft150_d50_bringup

Launch files and parameter files for the AIDIN AFT150-D50.

- `launch/aft150_d50.launch.py` starts one standalone node per sensor, each publishing
  `/<sensor name>/wrench`.
- `launch/aft150_d50_ros2_control.launch.py` starts `controller_manager` with one hardware
  component and one `force_torque_sensor_broadcaster` per sensor. Each broadcaster is named
  `<sensor name>_broadcaster` and publishes `/<sensor name>_broadcaster/wrench`. It builds the
  robot description by expanding the description package's macros, so no URDF file has to be
  maintained by hand.
- `config/aft150_d50_params.yaml` lists the sensors. Each top-level block is one sensor and the key
  is its node name, so adding a sensor means adding a block.
- `config/aft150_d50_controllers.yaml` holds `update_rate` for `controller_manager`. The
  broadcasters are not listed there: the launch file derives one per sensor from the parameter
  file, which keeps the sensor list in one place.

Both launch files take `params_file`. Which CAN interface a sensor is on differs between machines,
so pass a copy rather than editing the tracked file.

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py params_file:=~/my_aft150.yaml
```

The Korean guide is in [README.ko.md](README.ko.md).
