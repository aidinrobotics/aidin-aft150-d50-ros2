# aidin_aft150_d50_bringup

AIDIN AFT150-D50의 launch 파일과 parameter 파일입니다.

| Launch file | Parameter file | 실행하는 것 |
|---|---|---|
| `launch/aft150_d50.launch.py` | `config/aft150_d50_standalone.yaml` | 센서마다 독립 node 하나. 각 node는 `/<센서 이름>/wrench`로 발행합니다 |
| `launch/aft150_d50_ros2_control.launch.py` | `config/aft150_d50_ros2_control.yaml` | 센서마다 hardware 컴포넌트를 하나씩 둔 `controller_manager`, `robot_state_publisher`, 파일에 선언된 모든 controller |
| `launch/aft150_d50_view.launch.py` | `config/aft150_d50_standalone.yaml` | `robot_state_publisher`와 RViz. hardware는 사용하지 않습니다 |

- 기본 파일은 센서 하나, `left_wrist_ft`를 설정합니다. `aft150_d50_standalone_dual.yaml`과
  `aft150_d50_ros2_control_dual.yaml`은 `left_wrist_ft`와 `right_wrist_ft` 두 개를 설정하며, 두 센서를
  함께 실행하려면 이 파일을 `params_file`로 넘깁니다.
- `aft150_d50_standalone.yaml`에는 센서마다 블록이 하나씩 있고 키가 node 이름입니다. 센서를
  추가하는 일은 블록을 추가하는 일입니다.
- `aft150_d50_ros2_control.yaml`에는 같은 센서 블록과 함께 `controller_manager`, 그리고 센서마다
  `force_torque_sensor_broadcaster`가 하나씩 있습니다. broadcaster의 이름은 `<센서 이름>_broadcaster`이고
  `/<센서 이름>_broadcaster/wrench`로 발행합니다. 센서를 추가하려면 센서 블록과 broadcaster를 함께
  추가합니다.
- `ros2_control` launch와 RViz 확인 launch는 description package의 `aft150_d50.urdf.xacro`를
  parameter 파일로 실행해 robot description을 만듭니다. 따라서 URDF 파일을 직접 관리하지 않아도 됩니다.

다른 parameter 파일을 쓰려면 `params_file` 인자로 넘깁니다. 모든 launch 파일이 이 인자를 받습니다.

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py params_file:=~/my_aft150.yaml
```

parameter 목록과 여러 센서를 설정하는 방법은 [저장소 README](../README.ko.md)에 있습니다.
