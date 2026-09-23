cmake_minimum_required(VERSION 3.8)
project(aidin_aft150_d50_description VERSION 0.1.0)

find_package(ament_cmake REQUIRED)

install(DIRECTORY urdf DESTINATION share/${PROJECT_NAME})

ament_package()
