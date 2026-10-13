"""AIDIN AFT150-D50 through ros2_control.

Starts ros2_control_node and robot_state_publisher from the xacro description, then spawns every
controller declared under controller_manager. All of it comes from one parameter file: the
sensors' hardware settings for the description, and controller_manager and the broadcasters for
ros2_control_node.

  ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py
  ros2 launch aidin_aft150_d50_bringup aft150_d50_ros2_control.launch.py params_file:=~/my.yaml
"""

import os

import yaml

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.substitutions import Command, LaunchConfiguration

from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def _controller_names(params_file):
    """Controllers declared under controller_manager, each a block with a type."""
    with open(params_file) as f:
        loaded = yaml.safe_load(f) or {}
    declared = loaded.get('controller_manager', {}).get('ros__parameters', {})
    return [name for name, value in declared.items() if isinstance(value, dict)]


def _setup(context, *_):
    params_file = LaunchConfiguration('params_file').perform(context)

    description_share = get_package_share_directory('aidin_aft150_d50_description')
    xacro_file = os.path.join(description_share, 'xacro', 'aft150_d50.urdf.xacro')

    robot_description = ParameterValue(
        Command(['xacro ', xacro_file, ' params_file:=', params_file]),
        value_type=str,
    )

    control_node = Node(
        package='controller_manager',
        executable='ros2_control_node',
        parameters=[{'robot_description': robot_description}, params_file],
        output='screen',
        emulate_tty=True,
    )

    robot_state_publisher = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        parameters=[{'robot_description': robot_description}],
        output='screen',
    )

    spawners = [
        Node(
            package='controller_manager',
            executable='spawner',
            arguments=[name],
            output='screen',
        )
        for name in _controller_names(params_file)
    ]

    return [control_node, robot_state_publisher, *spawners]


def generate_launch_description():
    default_params = os.path.join(
        get_package_share_directory('aidin_aft150_d50_bringup'),
        'config', 'aft150_d50_ros2_control.yaml')

    return LaunchDescription([
        DeclareLaunchArgument(
            'params_file',
            default_value=default_params,
            description='Parameter file with controller_manager, the broadcasters and one '
                        'block per sensor.',
        ),
        OpaqueFunction(function=_setup),
    ])
