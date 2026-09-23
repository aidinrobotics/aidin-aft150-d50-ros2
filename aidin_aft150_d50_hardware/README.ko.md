# aidin_aft150_d50_hardware

AIDIN AFT150-D50의 `ros2_control` sensor interface입니다.

- `Aft150D50SensorInterface`는 `hardware_interface::SensorInterface`를 상속하므로 state
  interface만 내보내고 command는 받지 않습니다. `<ros2_control type="sensor">`로 선언합니다.
- state interface는 `<sensor_name>/force.{x,y,z}`와 `<sensor_name>/torque.{x,y,z}` 여섯 개입니다.
  `force_torque_sensor_broadcaster`가 sensor 이름으로 정확히 이 이름들을 만들기 때문에, 이름이
  다르면 broadcaster의 configure가 실패합니다.
- 이 컴포넌트는 topic을 직접 발행하지 않습니다. broadcaster가 위의 state interface 여섯 개를 읽어
  `/<센서 이름>_broadcaster/wrench`로 wrench를 발행하며, broadcaster는 센서마다 하나씩 있습니다.
- 설정값은 `<hardware>` 블록 안의 `<param>` 항목으로 전달합니다. 이 항목은
  [`aidin_aft150_d50_description`](../aidin_aft150_d50_description/README.ko.md)의 xacro 매크로가
  작성합니다.
- 컴포넌트는 `<ros2_control name="...">` 속성과 같은 이름의 node를 만들고 전용 스레드에서
  실행합니다. 그래서 service 이름이 독립 node와 같아집니다.
- 새 프레임이 없으면 `read()`가 `OK`를 돌려주고 직전 값을 유지합니다. 여기서 오류를 돌려주면
  `controller_manager`가 이 컴포넌트를 사용하는 controller를 모두 비활성화하므로, 케이블이 한
  주기 동안 흔들린 것만으로 broadcaster가 재시작 전까지 내려갑니다.

parameter와 service는 [저장소 README](../README.ko.md)에 있습니다.
