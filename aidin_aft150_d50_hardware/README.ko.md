# aidin_aft150_d50_hardware

AIDIN AFT150-D50의 `ros2_control` sensor interface입니다.

- plugin 이름은 `aidin_aft150_d50_hardware/Aft150D50SensorInterface`이며,
  `<ros2_control type="sensor">`로 선언합니다. state interface만 제공하고 command는 받지 않습니다.
- state interface는 `<sensor_name>/force.{x,y,z}`와 `<sensor_name>/torque.{x,y,z}` 여섯 개입니다.
  `force_torque_sensor_broadcaster`는 `sensor_name`으로 이 여섯 개를 읽습니다.
- wrench message는 이 컴포넌트가 아니라 broadcaster가 `/<sensor_name>_broadcaster/wrench`로 발행합니다.
- 설정은 `<hardware>` 블록의 `<param>`으로 전달합니다.
  [`aidin_aft150_d50_description`](../aidin_aft150_d50_description/README.ko.md)의 xacro 매크로가
  parameter 파일을 읽어 `<param>`을 작성합니다.
- service는 standalone node와 같은 이름(`/<sensor_name>/set_bias`,
  `/<sensor_name>/restore_defaults`)으로 제공됩니다.
- 센서 프레임이 잠시 들어오지 않아도 broadcaster는 멈추지 않고 직전 값을 발행합니다.

parameter와 service는 [저장소 README](../README.ko.md)에 있습니다.
