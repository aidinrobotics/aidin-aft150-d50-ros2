# aidin_aft150_d50_bringup

AIDIN AFT150-D50의 launch 파일과 parameter 파일입니다.

- `launch/aft150_d50.launch.py`는 센서마다 독립 node를 하나씩 실행하며, 각 node는
  `/<센서 이름>/wrench`로 발행합니다.
- `launch/aft150_d50_ros2_control.launch.py`는 `controller_manager`를 실행하면서 센서마다 hardware
  컴포넌트와 `force_torque_sensor_broadcaster`를 하나씩 올립니다. 각 broadcaster의 이름은
  `<센서 이름>_broadcaster`이고 `/<센서 이름>_broadcaster/wrench`로 발행합니다. description
  package의 매크로를 펼쳐 robot description을 만들므로 URDF 파일을 직접 관리하지 않아도 됩니다.
- `config/aft150_d50_params.yaml`에 센서 목록이 있습니다. 최상위 블록 하나가 센서 하나이고 키가
  node 이름이므로, 센서를 추가하는 일은 블록을 추가하는 일입니다.
- `config/aft150_d50_controllers.yaml`에는 `controller_manager`의 `update_rate`만 둡니다.
  broadcaster는 여기에 적지 않습니다. launch 파일이 parameter 파일에서 센서마다 하나씩 만들기
  때문이며, 그래야 센서 목록이 한 곳에만 있습니다.

두 launch 파일 모두 `params_file` 인자를 받습니다. 어느 센서가 어느 CAN 인터페이스에 연결되어
있는지는 장비마다 다르므로, 추적 중인 파일을 고치지 말고 사본을 전달하십시오.

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py params_file:=~/my_aft150.yaml
```

parameter 목록과 여러 센서를 설정하는 방법은 [저장소 README](../README.ko.md)에 있습니다.
