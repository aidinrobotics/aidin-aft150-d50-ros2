#include "aidin_aft150_d50_hardware/aft150_d50_sensor_interface.hpp"

#include <string>
#include <utility>
#include <vector>

#include "hardware_interface/types/hardware_interface_type_values.hpp"
#include "pluginlib/class_list_macros.hpp"

namespace aidin_aft150_d50_hardware
{
namespace
{

using aidin::aft150_d50::Sample;
using aidin::aft150_d50::Services;
using aidin::aft150_d50::Settings;

std::string param_or(
  const hardware_interface::HardwareInfo & info, const std::string & name,
  const std::string & fallback)
{
  const auto it = info.hardware_parameters.find(name);
  return (it == info.hardware_parameters.end()) ? fallback : it->second;
}

int int_param_or(
  const hardware_interface::HardwareInfo & info, const std::string & name, int fallback)
{
  const auto it = info.hardware_parameters.find(name);
  if (it == info.hardware_parameters.end()) {
    return fallback;
  }
  try {
    return std::stoi(it->second, nullptr, 0);
  } catch (const std::exception &) {
    return fallback;
  }
}

}  // namespace

hardware_interface::CallbackReturn Aft150D50SensorInterface::on_init(
  const hardware_interface::HardwareInfo & info)
{
  if (hardware_interface::SensorInterface::on_init(info) !=
    hardware_interface::CallbackReturn::SUCCESS)
  {
    return hardware_interface::CallbackReturn::ERROR;
  }

  const Settings defaults;
  settings_.can_interface = param_or(info_, "can_interface", defaults.can_interface);
  settings_.can_mode = param_or(info_, "can_mode", defaults.can_mode);
  settings_.data_type = param_or(info_, "data_type", defaults.data_type);
  settings_.rate_hz = int_param_or(info_, "rate_hz", defaults.rate_hz);
  settings_.frame_id = param_or(info_, "frame_id", info_.name + "_link");

  std::string reason;
  if (!aidin::aft150_d50::validate(settings_, reason)) {
    RCLCPP_FATAL(rclcpp::get_logger(info_.name), "%s", reason.c_str());
    return hardware_interface::CallbackReturn::ERROR;
  }

  if (info_.sensors.size() != 1) {
    RCLCPP_FATAL(
      rclcpp::get_logger(info_.name),
      "expected exactly one <sensor> in the ros2_control description, found %zu",
      info_.sensors.size());
    return hardware_interface::CallbackReturn::ERROR;
  }
  if (info_.sensors[0].state_interfaces.size() != values_.size()) {
    RCLCPP_FATAL(
      rclcpp::get_logger(info_.name),
      "expected %zu state interfaces, found %zu. force_torque_sensor_broadcaster needs "
      "force.x force.y force.z torque.x torque.y torque.z",
      values_.size(), info_.sensors[0].state_interfaces.size());
    return hardware_interface::CallbackReturn::ERROR;
  }

  return hardware_interface::CallbackReturn::SUCCESS;
}

std::vector<hardware_interface::StateInterface>
Aft150D50SensorInterface::export_state_interfaces()
{
  std::vector<hardware_interface::StateInterface> interfaces;
  const auto & sensor = info_.sensors[0];
  for (std::size_t i = 0; i < sensor.state_interfaces.size(); ++i) {
    interfaces.emplace_back(sensor.name, sensor.state_interfaces[i].name, &values_[i]);
  }
  return interfaces;
}

hardware_interface::CallbackReturn Aft150D50SensorInterface::on_configure(
  const rclcpp_lifecycle::State & /*previous_state*/)
{
  service_node_ = std::make_shared<rclcpp::Node>(info_.name);

  // The values that arrived as <param> become the defaults, so the declared parameters report
  // what the component is actually running with.
  aidin::aft150_d50::declare_settings(service_node_.get(), settings_);

  services_ = std::make_unique<Services>(service_node_.get(), settings_);
  std::string reason;
  if (!services_->start(reason)) {
    RCLCPP_FATAL(service_node_->get_logger(), "%s", reason.c_str());
    services_.reset();
    service_node_.reset();
    return hardware_interface::CallbackReturn::ERROR;
  }

  service_executor_ = std::make_unique<rclcpp::executors::SingleThreadedExecutor>();
  service_executor_->add_node(service_node_);
  service_spin_thread_ = std::thread([this] {service_executor_->spin();});

  return hardware_interface::CallbackReturn::SUCCESS;
}

hardware_interface::CallbackReturn Aft150D50SensorInterface::on_cleanup(
  const rclcpp_lifecycle::State & /*previous_state*/)
{
  shut_down();
  return hardware_interface::CallbackReturn::SUCCESS;
}

hardware_interface::CallbackReturn Aft150D50SensorInterface::on_shutdown(
  const rclcpp_lifecycle::State & /*previous_state*/)
{
  shut_down();
  return hardware_interface::CallbackReturn::SUCCESS;
}

void Aft150D50SensorInterface::shut_down()
{
  if (service_executor_) {
    service_executor_->cancel();
  }
  if (service_spin_thread_.joinable()) {
    service_spin_thread_.join();
  }
  if (service_executor_ && service_node_) {
    service_executor_->remove_node(service_node_);
  }
  services_.reset();
  service_executor_.reset();
  service_node_.reset();
}

hardware_interface::return_type Aft150D50SensorInterface::read(
  const rclcpp::Time & /*time*/, const rclcpp::Duration & /*period*/)
{
  Sample s{};
  if (services_ && services_->read_latest(s)) {
    values_[0] = s.fx;
    values_[1] = s.fy;
    values_[2] = s.fz;
    values_[3] = s.tx;
    values_[4] = s.ty;
    values_[5] = s.tz;
  }
  // No new frame is not an error. Returning ERROR here would make controller_manager deactivate
  // every controller using this component, so a cable brushed loose for one cycle would take the
  // broadcaster down for good.
  return hardware_interface::return_type::OK;
}

}  // namespace aidin_aft150_d50_hardware

PLUGINLIB_EXPORT_CLASS(
  aidin_aft150_d50_hardware::Aft150D50SensorInterface, hardware_interface::SensorInterface)
