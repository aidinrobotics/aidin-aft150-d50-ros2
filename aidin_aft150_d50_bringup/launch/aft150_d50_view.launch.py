# Shows the sensors of a parameter file in RViz, with robot_state_publisher and no hardware.
#
# Run it alongside the standalone launch with the same parameter file, and a Wrench display on
# /<sensor name>/wrench draws the force on the sensor model.

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import Command, LaunchConfiguration

from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def generate_launch_description():
    default_params = get_package_share_directory('aidin_aft150_d50_bringup') \
        + '/config/aft150_d50_standalone.yaml'
    description_share = get_package_share_directory('aidin_aft150_d50_description')

    robot_description = ParameterValue(
        Command([
            'xacro ', description_share + '/xacro/aft150_d50.urdf.xacro',
            ' params_file:=', LaunchConfiguration('params_file'),
        ]),
        value_type=str,
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'params_file',
            default_value=default_params,
            description='Parameter file. One top-level block per sensor, keyed by node name.',
        ),
        Node(
            package='robot_state_publisher',
            executable='robot_state_publisher',
            parameters=[{'robot_description': robot_description}],
            output='screen',
        ),
        Node(
            package='rviz2',
            executable='rviz2',
            arguments=['-d', description_share + '/rviz/view_sensor.rviz'],
            output='screen',
        ),
    ])
