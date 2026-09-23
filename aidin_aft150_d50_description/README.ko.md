# aidin_aft150_d50_description

AIDIN AFT150-D50의 URDF와 `ros2_control` description입니다.

- `urdf/aft150_d50.ros2_control.xacro`에 매크로 두 개가 있습니다. `aft150_d50_ros2_control`은
  hardware plugin과 그 parameter, state interface 여섯 개를 담은 `<ros2_control>` 블록을
  작성합니다. `aft150_d50_link`는 센서 link를 작성하고, `parent`를 주면 그 link에 연결하는 고정
  joint도 함께 작성합니다.
- `urdf/aft150_d50.urdf.xacro`는 센서 하나만 담은 독립 description이며, driver만 단독으로 실행할
  때 사용합니다. 실제 로봇에서는 매크로 파일을 include해서 자신의 description에서 매크로를
  호출하십시오. 그래야 센서가 올바른 link에 놓입니다.

매크로에는 센서 이름을 넘깁니다. 이 이름이 `ros2_control` 컴포넌트 이름이자 node 이름이 되고,
state interface 이름의 앞부분이 됩니다.

```xml
<xacro:include filename="$(find aidin_aft150_d50_description)/urdf/aft150_d50.ros2_control.xacro"/>

<xacro:aft150_d50_link name="right_wrist_ft" parent="tool0"/>
<xacro:aft150_d50_ros2_control name="right_wrist_ft" can_interface="can0"/>
```

`can_mode`, `data_type`, `rate_hz`, `set_id_can20`, `set_id_canfd` 인자는 선택 사항이며 독립
node와 같은 기본값을 사용합니다. 값의 의미는 [저장소 README](../README.ko.md)에 있습니다.
