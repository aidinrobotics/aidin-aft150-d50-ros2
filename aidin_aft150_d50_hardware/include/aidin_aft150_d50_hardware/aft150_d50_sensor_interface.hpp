#ifndef AIDIN_AFT150_D50_HARDWARE__AFT150_D50_SENSOR_INTERFACE_HPP_
#define AIDIN_AFT150_D50_HARDWARE__AFT150_D50_SENSOR_INTERFACE_HPP_

#include <array>
#include <memory>
#include <string>
#include <thread>
#include <vector>

#include "aidin_aft150_d50_driver/aft150_d50_services.hpp"

#include "hardware_interface/sensor_interface.hpp"
#include "hardware_interface/types/hardware_interface_return_values.hpp"
#include "rclcpp/executors/single_threaded_executor.hpp"
#include "rclcpp/rclcpp.hpp"
#include "rclcpp_lifecycle/state.hpp"

namespace aidin_aft150_d50_hardware
{

class Aft150D50SensorInterface : public hardware_interface::SensorInterface
{
public:
  hardware_interface::CallbackReturn on_init(
    const hardware_interface::HardwareInfo & info) override;

  hardware_interface::CallbackReturn on_configure(
    const rclcpp_lifecycle::State & previous_state) override;

  hardware_interface::CallbackReturn on_cleanup(
    const rclcpp_lifecycle::State & previous_state) override;

  hardware_interface::CallbackReturn on_shutdown(
    const rclcpp_lifecycle::State & previous_state) override;

  std::vector<hardware_interface::StateInterface> export_state_interfaces() override;

  hardware_interface::return_type read(
    const rclcpp::Time & time, const rclcpp::Duration & period) override;

private:
  void shut_down();

  aidin::aft150_d50::Settings settings_;
  std::unique_ptr<aidin::aft150_d50::Services> services_;

  std::array<double, 6> values_{};

  std::shared_ptr<rclcpp::Node> service_node_;
  std::unique_ptr<rclcpp::executors::SingleThreadedExecutor> service_executor_;
  std::thread service_spin_thread_;
};

}  // namespace aidin_aft150_d50_hardware

#endif  // AIDIN_AFT150_D50_HARDWARE__AFT150_D50_SENSOR_INTERFACE_HPP_
