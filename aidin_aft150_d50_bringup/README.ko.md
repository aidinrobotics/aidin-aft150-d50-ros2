# aidin_aft150_d50_bringup

AIDIN AFT150-D50의 launch 파일과 parameter 파일입니다.

| Launch file | Parameter file | 실행하는 것 |
|---|---|---|
| `launch/aft150_d50.launch.py` | `config/aft150_d50_standalone.yaml` | 센서마다 standalone node 하나. 각 node는 `/<sensor_name>/wrench`로 wrench message를 발행합니다 |
| `launch/aft150_d50_ros2_control.launch.py` | `config/aft150_d50_ros2_control.yaml` | `controller_manager`와 `robot_state_publisher`. 센서마다 hardware 컴포넌트와 broadcaster를 하나씩 실행합니다 |
| `launch/aft150_d50_view.launch.py` | `config/aft150_d50_standalone.yaml` | `robot_state_publisher`와 RViz. hardware는 사용하지 않습니다 |

- 기본 파일은 센서 하나(`left_wrist_ft`)를 설정합니다. `aft150_d50_standalone_dual.yaml`과
  `aft150_d50_ros2_control_dual.yaml`은 센서 두 개(`left_wrist_ft`, `right_wrist_ft`)를 설정합니다.
- `aft150_d50_standalone.yaml`에는 센서마다 블록이 하나씩 있으며, 블록 이름이 node 이름이 됩니다.
  센서를 추가하려면 블록을 하나 더 적으십시오.
- `aft150_d50_ros2_control.yaml`에는 `controller_manager` 블록과 함께 센서마다 broadcaster 블록과 센서
  블록이 하나씩 있습니다. `type`이 있는 블록이 broadcaster 블록입니다. 센서를 추가하려면 두 블록을
  하나씩 더 적으십시오.
- `ros2_control` launch와 RViz launch는 parameter 파일을 description package의
  `aft150_d50.urdf.xacro`에 넘겨 robot description을 만듭니다. URDF 파일을 따로 관리할 필요는 없습니다.

다른 parameter 파일을 쓰려면 `params_file` 인자로 넘기십시오. 모든 launch 파일이 이 인자를 받습니다.

```bash
ros2 launch aidin_aft150_d50_bringup aft150_d50.launch.py params_file:=~/my_aft150.yaml
```

parameter 목록은 [저장소 README](../README.ko.md#41-parameters)에 있습니다.
