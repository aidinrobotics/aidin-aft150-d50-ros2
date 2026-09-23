# Starts controller_manager with one hardware component and one broadcaster per sensor.
#
# It reads the same parameter file the standalone launch uses, so the sensor list, the interface
# names and the modes live in one place. From that file it builds the robot description by
# expanding the description package's macro once per sensor, and it derives the broadcaster
# settings rather than repeating them in a second file.

import xacro
import yaml

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.substitutions import LaunchConfiguration

from launch_ros.actions import Node


def sensor_blocks(params_file):
    with open(params_file, 'r') as handle:
        loaded = yaml.safe_load(handle) or {}

    wildcard = loaded.get('/**', {}).get('ros__parameters', {})
    blocks = {}
    for key, value in loaded.items():
        if key == '/**' or not isinstance(value, dict):
            continue
        settings = dict(wildcard)
        settings.update(value.get('ros__parameters', {}))
        blocks[key] = settings
    return blocks


def build_description(blocks):
    macros = get_package_share_directory('aidin_aft150_d50_description') \
        + '/urdf/aft150_d50.ros2_control.xacro'

    parts = [
        '<?xml version="1.0"?>',
        '<robot name="aft150_d50" xmlns:xacro="http://www.ros.org/wiki/xacro">',
        '  <xacro:include filename="{}"/>'.format(macros),
        '  <link name="world"/>',
    ]
    for name, settings in blocks.items():
        parts.append(
            '  <xacro:aft150_d50_link name="{}" parent="world"/>'.format(name))
        parts.append(
            '  <xacro:aft150_d50_ros2_control name="{}" can_interface="{}" can_mode="{}"'
            ' data_type="{}" rate_hz="{}" set_id_can20="{}" set_id_canfd="{}"/>'.format(
                name,
                settings.get('can_interface', 'can0'),
                settings.get('can_mode', 'fd_brs'),
                settings.get('data_type', 'float_combined'),
                settings.get('rate_hz', 1000),
                settings.get('set_id_can20', 0x230),
                settings.get('set_id_canfd', 0x330),
            ))
    parts.append('</robot>')

    document = xacro.parse('\n'.join(parts))
    xacro.process_doc(document)
    return document.toxml()


def launch_setup(context, *args, **kwargs):
    params_file = LaunchConfiguration('params_file').perform(context)
    controllers_file = LaunchConfiguration('controllers_file').perform(context)

    blocks = sensor_blocks(params_file)
    description = build_description(blocks)

    broadcasters = {}
    for name in blocks:
        controller = '{}_broadcaster'.format(name)
        broadcasters[controller + '.type'] = \
            'force_torque_sensor_broadcaster/ForceTorqueSensorBroadcaster'
        broadcasters[controller + '.sensor_name'] = name
        broadcasters[controller + '.frame_id'] = '{}_link'.format(name)

    actions = [
        Node(
            package='controller_manager',
            executable='ros2_control_node',
            parameters=[
                {'robot_description': description},
                controllers_file,
                broadcasters,
            ],
            output='screen',
            emulate_tty=True,
        ),
        Node(
            package='robot_state_publisher',
            executable='robot_state_publisher',
            parameters=[{'robot_description': description}],
            output='screen',
        ),
    ]
    actions += [
        Node(
            package='controller_manager',
            executable='spawner',
            arguments=['{}_broadcaster'.format(name)],
            output='screen',
        )
        for name in blocks
    ]
    return actions


def generate_launch_description():
    share = get_package_share_directory('aidin_aft150_d50_bringup')

    return LaunchDescription([
        DeclareLaunchArgument(
            'params_file',
            default_value=share + '/config/aft150_d50_params.yaml',
            description='Parameter file. One top-level block per sensor, keyed by node name.',
        ),
        DeclareLaunchArgument(
            'controllers_file',
            default_value=share + '/config/aft150_d50_controllers.yaml',
            description='Settings for controller_manager itself.',
        ),
        OpaqueFunction(function=launch_setup),
    ])
