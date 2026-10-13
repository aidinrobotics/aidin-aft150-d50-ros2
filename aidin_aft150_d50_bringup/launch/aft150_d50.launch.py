# Starts one standalone node per sensor.
#
# The parameter file is an ordinary ROS 2 parameter file, so its top-level keys are node names.
# This reads those keys to know how many nodes to start and what to call them, then hands the
# same file to every node, which picks up its own block.

import yaml

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.substitutions import LaunchConfiguration

from launch_ros.actions import Node


def sensor_names(params_file):
    with open(params_file, 'r') as handle:
        loaded = yaml.safe_load(handle) or {}
    # '/**' is the wildcard block, which applies to every node rather than naming one.
    return [key for key in loaded if key != '/**' and isinstance(loaded[key], dict)]


def launch_setup(context, *args, **kwargs):
    params_file = LaunchConfiguration('params_file').perform(context)
    return [
        Node(
            package='aidin_aft150_d50_driver',
            executable='aft150_d50_node',
            name=name,
            parameters=[params_file],
            output='screen',
            emulate_tty=True,
        )
        for name in sensor_names(params_file)
    ]


def generate_launch_description():
    default_params = get_package_share_directory('aidin_aft150_d50_bringup') \
        + '/config/aft150_d50_standalone.yaml'

    return LaunchDescription([
        DeclareLaunchArgument(
            'params_file',
            default_value=default_params,
            description='Parameter file. One top-level block per sensor, keyed by node name.',
        ),
        OpaqueFunction(function=launch_setup),
    ])
