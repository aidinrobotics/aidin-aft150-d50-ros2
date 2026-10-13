# aidin_aft150_d50_driver

AIDIN AFT150-D50의 센서 통신 라이브러리와 standalone node `aft150_d50_node`입니다.

- `aft150_d50_node`는 CAN interface를 열어 센서 값을 읽고, `/<sensor_name>/wrench`로
  `geometry_msgs/msg/WrenchStamped`를 발행합니다. service 두 개도 제공합니다.
- node는 [`aidin_aft150_d50_bringup`](../aidin_aft150_d50_bringup/README.ko.md)의 launch 파일로
  실행하십시오.
- 센서 통신 라이브러리는 x86_64용과 aarch64용으로 제공됩니다. 다른 아키텍처에서 빌드하면 빌드가
  중단되고, 지원하는 아키텍처가 message에 표시됩니다.

parameter와 service, topic은 [저장소 README](../README.ko.md)에 있습니다.
