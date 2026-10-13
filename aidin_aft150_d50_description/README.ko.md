# aidin_aft150_d50_description

AIDIN AFT150-D50의 URDF와 메시, `ros2_control` description입니다.

| File | Contents |
|---|---|
| [xacro/aft150_d50_unit.urdf.xacro](xacro/aft150_d50_unit.urdf.xacro) | `aft150_d50_unit` 매크로입니다. 센서 하나의 몸체와 frame을 작성하며, 어디에 장착할지는 정하지 않습니다 |
| [ros2_control/aft150_d50.ros2_control.xacro](ros2_control/aft150_d50.ros2_control.xacro) | `aft150_d50_ros2_control` 매크로입니다. parameter 파일을 읽어 센서 하나의 `<ros2_control>` 블록을 작성합니다 |
| [xacro/aft150_d50.urdf.xacro](xacro/aft150_d50.urdf.xacro) | parameter 파일의 센서를 `world`에 놓습니다. `aidin_aft150_d50_bringup`의 launch 파일이 사용합니다. `left_wrist_ft`와 `right_wrist_ft`는 정해진 위치에, 그 밖의 센서는 원점에 놓입니다 |
| [meshes/aft150_d50.stl](meshes/aft150_d50.stl) | 센서 메시입니다 |
| [rviz/view_sensor.rviz](rviz/view_sensor.rviz) | `aft150_d50_view.launch.py`가 사용하는 RViz 설정입니다 |

## Frames

`aft150_d50_unit`은 frame 세 개를 작성하며, 이름은 매크로에 넘긴 센서 이름으로 시작합니다.

| Frame | Position |
|---|---|
| `<name>_base_link` | 장착면의 중심입니다. 메시가 이 frame에 붙고, +Z는 몸체를 지나 tool 면을 향합니다 |
| `<name>_link` | 측정 frame이며 wrench의 `frame_id`입니다. tool 면의 중심, 즉 +Z로 17.7 mm 위치에 있습니다 |
| `<name>_tool_link` | tool 면의 중심이며 +Z로 17.7 mm 위치에 있습니다. tool이나 AIDIN Hand Gen2를 이 frame에 붙입니다 |

joint 이름은 child link 이름의 `_link`를 `_joint`로 바꾼 것입니다. 센서를 장착하는 joint는
호출하는 쪽이 작성하며, 같은 규칙에 따라 `<name>_base_joint`로 씁니다.

## Macros

| Macro | Arguments | 작성하는 것 |
|---|---|---|
| `aft150_d50_unit` | `name` | 위의 frame 세 개와 메시, 센서 내부의 joint 두 개 |
| `aft150_d50_ros2_control` | `name`, `params_file` | hardware plugin과 그 parameter, state interface 여섯 개를 담은 `<ros2_control>` 블록 하나 |

`aft150_d50_ros2_control`은 `params_file`에서 `name` 블록을 읽어 파일의 `/**` 블록과 합친 뒤, 그
블록에 있는 설정마다 `<param>`을 작성합니다. 파일에 없는 설정은 driver의 기본값을 사용합니다.

두 매크로로 기존 `ros2_control` 시스템에 센서를 추가하는 방법은
[7. Integration](../README.ko.md#7-integration)에 있습니다.

## Replacing the mesh

`meshes/aft150_d50.stl`은 외형 크기만 맞춘 임시 메시이며, 지름 50 mm, 높이 17.7 mm 원통에 지름
8 mm 관통 구멍이 있습니다. 아래 규칙을 지킨 STL로 파일을 바꾸면 xacro는 고칠 필요가 없습니다.

- 단위는 mm입니다.
- 원점은 장착면의 중심이고, +Z는 몸체를 지나 tool 면을 향합니다.
- X와 Y는 센서에 새겨진 축 방향을 따릅니다.
