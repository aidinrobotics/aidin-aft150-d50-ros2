#ifndef AIDIN_AFT150_D50_DRIVER__AFT150_D50_SERVICES_HPP_
#define AIDIN_AFT150_D50_DRIVER__AFT150_D50_SERVICES_HPP_

#include <memory>
#include <string>
#include <vector>

#include "aidin_aft150_d50_driver/aft150_d50_comms.hpp"

#include "geometry_msgs/msg/wrench_stamped.hpp"
#include "rcl_interfaces/msg/parameter_descriptor.hpp"
#include "rclcpp/rclcpp.hpp"
#include "std_srvs/srv/trigger.hpp"

namespace aidin::aft150_d50
{

struct Settings
{
  std::string can_interface = "can0";
  std::string can_mode = "fd_brs";
  std::string data_type = "float_combined";
  int rate_hz = 1000;
  int set_id_can20 = 0x430;
  int set_id_canfd = 0x330;
  std::string frame_id;
};

inline constexpr int SET_ID_MIN = 0x000;
inline constexpr int SET_ID_MAX = 0x7FF;

const std::vector<std::string> & can_mode_names();
const std::vector<std::string> & data_type_names();
const std::vector<int> & rate_hz_values();

bool is_valid_can_mode(const std::string & value);
bool is_valid_data_type(const std::string & value);
bool is_valid_rate_hz(int value);
bool is_valid_set_id(int value);
bool data_type_needs_fd(const std::string & value);
bool can_mode_is_fd(const std::string & value);

bool validate(const Settings & s, std::string & reason);

rcl_interfaces::msg::ParameterDescriptor read_only(const std::string & description);
void declare_settings(rclcpp::Node * node, Settings & settings);

class Services
{
public:
  Services(rclcpp::Node * node, Settings settings);
  ~Services();

  Services(const Services &) = delete;
  Services & operator=(const Services &) = delete;

  bool start(std::string & reason);
  void stop();

  bool read_latest(Sample & out);

  const Settings & settings() const {return settings_;}

private:
  bool apply_transmit_ids(std::string & reason);

  void handle_set_bias(
    const std::shared_ptr<std_srvs::srv::Trigger::Request> request,
    std::shared_ptr<std_srvs::srv::Trigger::Response> response);
  void handle_confirm_id(
    const std::shared_ptr<std_srvs::srv::Trigger::Request> request,
    std::shared_ptr<std_srvs::srv::Trigger::Response> response);
  void handle_restore_defaults(
    const std::shared_ptr<std_srvs::srv::Trigger::Request> request,
    std::shared_ptr<std_srvs::srv::Trigger::Response> response);

  bool resume_stream(std::string & reason);

  rclcpp::Node * node_;
  Settings settings_;
  std::unique_ptr<Comms> comms_;

  rclcpp::Service<std_srvs::srv::Trigger>::SharedPtr set_bias_;
  rclcpp::Service<std_srvs::srv::Trigger>::SharedPtr confirm_id_;
  rclcpp::Service<std_srvs::srv::Trigger>::SharedPtr restore_defaults_;
};

}  // namespace aidin::aft150_d50

#endif  // AIDIN_AFT150_D50_DRIVER__AFT150_D50_SERVICES_HPP_
