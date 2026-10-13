# aidin_aft150_d50_driver

AIDIN AFT150-D50의 통신 계층과 독립 ROS 2 node입니다.

- `aft150_d50_node`가 CAN interface를 열고 `~/wrench`로 `geometry_msgs/msg/WrenchStamped`를
  발행하며 service 두 개를 제공합니다. 이 topic 이름은 `/<센서 이름>/wrench`로 해석됩니다. 실행은
  [`aidin_aft150_d50_bringup`](../aidin_aft150_d50_bringup/README.ko.md)의 launch 파일로 합니다.
- `include/aidin_aft150_d50_driver/aft150_d50_comms.hpp`가 통신 계층의 경계입니다.
  `Comms::open_bus`가 socket과 수신 스레드를 소유하는 handle을 돌려주고, handle을 해제하면 둘 다
  정리됩니다.
- `include/aidin_aft150_d50_driver/aft150_d50_services.hpp`에 parameter 검증과 service 구현이
  있습니다. 독립 node와 `ros2_control` 컴포넌트가 모두 이 구현을 링크하므로 두 경로의 service
  이름과 동작이 같습니다.
- `prebuilt/<arch>/libaft150_d50_comms.a`가 통신 계층이며, 따로 설치하지 않고 이 package의 공유
  라이브러리에 흡수됩니다. 같은 자리의 `BUILD-INFO`에 버전과 commit, 빌드에 사용한 toolchain을
  기록합니다. 현재 아키텍처용 아카이브가 없으면 빌드가 중단되면서 제공하는 아키텍처를 알려 줍니다.

parameter와 service, topic은 [저장소 README](../README.ko.md)에 있습니다.
