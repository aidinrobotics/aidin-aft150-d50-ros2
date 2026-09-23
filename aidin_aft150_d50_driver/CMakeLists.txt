cmake_minimum_required(VERSION 3.8)
project(aidin_aft150_d50_driver VERSION 0.1.0)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(std_srvs REQUIRED)
find_package(rcl_interfaces REQUIRED)

set(_comms_archive libaft150_d50_comms.a)
set(_comms_dir ${CMAKE_CURRENT_SOURCE_DIR}/prebuilt/${CMAKE_SYSTEM_PROCESSOR})

if(NOT EXISTS ${_comms_dir}/${_comms_archive})
  file(GLOB _comms_shipped RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}/prebuilt
       ${CMAKE_CURRENT_SOURCE_DIR}/prebuilt/*)
  message(FATAL_ERROR
    "this release does not ship the communication archive for ${CMAKE_SYSTEM_PROCESSOR}. "
    "It ships: ${_comms_shipped}")
endif()

add_library(aft150_d50_comms STATIC IMPORTED)
set_target_properties(aft150_d50_comms PROPERTIES
  IMPORTED_LOCATION ${_comms_dir}/${_comms_archive})
message(STATUS "aidin_aft150_d50_driver: comms = ${_comms_dir}/${_comms_archive}")

add_library(${PROJECT_NAME} SHARED
  src/aft150_d50_services.cpp
)
target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_include_directories(${PROJECT_NAME} PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)
target_link_libraries(${PROJECT_NAME} aft150_d50_comms)
target_link_options(${PROJECT_NAME} PRIVATE "-Wl,--exclude-libs,${_comms_archive}")
ament_target_dependencies(${PROJECT_NAME}
  rclcpp
  geometry_msgs
  std_srvs
  rcl_interfaces
)

add_executable(aft150_d50_node src/aft150_d50_node.cpp)
target_link_libraries(aft150_d50_node ${PROJECT_NAME})
ament_target_dependencies(aft150_d50_node rclcpp geometry_msgs std_srvs rcl_interfaces)

install(DIRECTORY include/ DESTINATION include)
install(TARGETS ${PROJECT_NAME}
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)
install(TARGETS aft150_d50_node DESTINATION lib/${PROJECT_NAME})

if(BUILD_TESTING)
  add_executable(aft150_d50_param_test tests/aft150_d50_param_test.cpp)
  target_link_libraries(aft150_d50_param_test ${PROJECT_NAME})
  add_test(NAME aft150_d50_param COMMAND aft150_d50_param_test)
endif()

ament_export_include_directories(include)
ament_export_libraries(${PROJECT_NAME})
ament_export_dependencies(rclcpp geometry_msgs std_srvs rcl_interfaces)
ament_package()
