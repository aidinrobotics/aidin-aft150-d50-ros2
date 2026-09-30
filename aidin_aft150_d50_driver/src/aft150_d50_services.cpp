#include "aidin_aft150_d50_driver/aft150_d50_services.hpp"

#include <unistd.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <string>
#include <utility>
#include <vector>

namespace aidin::aft150_d50
{
namespace
{

std::string join(const std::vector<std::string> & values)
{
  std::string out;
  for (std::size_t i = 0; i < values.size(); ++i) {
    if (i > 0) {
      out += ", ";
    }
    out += values[i];
  }
  return out;
}

std::string join(const std::vector<int> & values)
{
  std::string out;
  for (std::size_t i = 0; i < values.size(); ++i) {
    if (i > 0) {
      out += ", ";
    }
    out += std::to_string(values[i]);
  }
  return out;
}

// The answer to CONFIRM ID comes back on the receive thread, so a caller waits before reading it.
constexpr int CONFIRM_ID_WAIT_MS = 150;

std::string as_hex(int value)
{
  char buf[16];
  std::snprintf(buf, sizeof(buf), "0x%03X", value);
  return std::string(buf);
}

std::string read_link_name(const std::string & path)
{
  char buf[512];
  const ssize_t n = ::readlink(path.c_str(), buf, sizeof(buf) - 1);
  if (n <= 0) {
    return {};
  }
  buf[n] = '\0';
  std::string s(buf);
  const std::size_t slash = s.find_last_of('/');
  return (slash == std::string::npos) ? s : s.substr(slash + 1);
}

unsigned long read_mtu(const std::string & interface)
{
  const std::string path = "/sys/class/net/" + interface + "/mtu";
  std::FILE * f = std::fopen(path.c_str(), "r");
  if (f == nullptr) {
    return 0;
  }
  unsigned long mtu = 0;
  if (std::fscanf(f, "%lu", &mtu) != 1) {
    mtu = 0;
  }
  std::fclose(f);
  return mtu;
}

}  // namespace

const std::vector<std::string> & can_mode_names()
{
  static const std::vector<std::string> names = {"classic", "fd", "fd_brs"};
  return names;
}

const std::vector<std::string> & data_type_names()
{
  static const std::vector<std::string> names = {"int6", "int12_combined", "float_combined"};
  return names;
}

const std::vector<int> & rate_hz_values()
{
  static const std::vector<int> values = {100, 250, 500, 1000};
  return values;
}

bool is_valid_can_mode(const std::string & value)
{
  const auto & names = can_mode_names();
  return std::find(names.begin(), names.end(), value) != names.end();
}

bool is_valid_data_type(const std::string & value)
{
  const auto & names = data_type_names();
  return std::find(names.begin(), names.end(), value) != names.end();
}

bool is_valid_rate_hz(int value)
{
  const auto & values = rate_hz_values();
  return std::find(values.begin(), values.end(), value) != values.end();
}

bool is_valid_set_id(int value)
{
  return value >= SET_ID_MIN && value <= SET_ID_MAX;
}

bool data_type_needs_fd(const std::string & value)
{
  static const std::vector<std::string> fd_only = {"int12_combined", "float_combined"};
  return std::find(fd_only.begin(), fd_only.end(), value) != fd_only.end();
}

bool can_mode_is_fd(const std::string & value)
{
  return value == "fd" || value == "fd_brs";
}

bool validate(const Settings & s, std::string & reason)
{
  reason.clear();

  if (s.can_interface.empty()) {
    reason = "can_interface is empty. Name a CAN interface, for example can0";
    return false;
  }
  if (!is_valid_can_mode(s.can_mode)) {
    reason = "can_mode is '" + s.can_mode + "'. Allowed: " + join(can_mode_names());
    return false;
  }
  if (!is_valid_data_type(s.data_type)) {
    reason = "data_type is '" + s.data_type + "'. Allowed: " + join(data_type_names());
    return false;
  }
  if (!is_valid_rate_hz(s.rate_hz)) {
    reason = "rate_hz is " + std::to_string(s.rate_hz) + ". Allowed: " + join(rate_hz_values());
    return false;
  }
  if (!is_valid_set_id(s.set_id_can20)) {
    reason = "set_id_can20 is " + std::to_string(s.set_id_can20) +
      ", which is outside 0x000 to 0x7FF";
    return false;
  }
  if (!is_valid_set_id(s.set_id_canfd)) {
    reason = "set_id_canfd is " + std::to_string(s.set_id_canfd) +
      ", which is outside 0x000 to 0x7FF";
    return false;
  }
  if (data_type_needs_fd(s.data_type) && !can_mode_is_fd(s.can_mode)) {
    reason = "data_type '" + s.data_type + "' puts six axes in one frame and needs CAN FD, but "
      "can_mode is '" + s.can_mode + "'";
    return false;
  }
  return true;
}

rcl_interfaces::msg::ParameterDescriptor read_only(const std::string & description)
{
  rcl_interfaces::msg::ParameterDescriptor d;
  d.description = description;
  d.read_only = true;
  return d;
}

void declare_settings(rclcpp::Node * node, Settings & s)
{
  s.can_interface = node->declare_parameter(
    "can_interface", s.can_interface,
    read_only("Name of the SocketCAN interface to open. It must already be up"));
  s.can_mode = node->declare_parameter(
    "can_mode", s.can_mode,
    read_only("Frame format: " + join(can_mode_names())));
  s.data_type = node->declare_parameter(
    "data_type", s.data_type,
    read_only("What the sensor transmits: " + join(data_type_names())));
  s.rate_hz = static_cast<int>(
    node->declare_parameter(
      "rate_hz", static_cast<int64_t>(s.rate_hz),
      read_only("Update rate in Hz: " + join(rate_hz_values()))));
  s.set_id_can20 = static_cast<int>(
    node->declare_parameter(
      "set_id_can20", static_cast<int64_t>(s.set_id_can20),
      read_only("CAN 2.0 transmit ID to give the sensor, 0x000 to 0x7FF")));
  s.set_id_canfd = static_cast<int>(
    node->declare_parameter(
      "set_id_canfd", static_cast<int64_t>(s.set_id_canfd),
      read_only("CAN FD transmit ID to give the sensor, 0x000 to 0x7FF")));
  s.frame_id = node->declare_parameter(
    "frame_id",
    s.frame_id.empty() ? std::string(node->get_name()) + "_link" : s.frame_id,
    read_only("frame_id of the published wrench"));
}

Services::Services(rclcpp::Node * node, Settings settings)
: node_(node), settings_(std::move(settings))
{
  if (settings_.frame_id.empty()) {
    settings_.frame_id = std::string(node_->get_name()) + "_link";
  }
}

Services::~Services()
{
  stop();
}

bool Services::start(std::string & reason)
{
  if (!validate(settings_, reason)) {
    return false;
  }

  char err[256] = {0};
  comms_.reset(
    Comms::open_bus(
      settings_.can_interface.c_str(), settings_.can_mode.c_str(), err, sizeof(err)));
  if (comms_ == nullptr) {
    reason = err;
    return false;
  }

  const unsigned long mtu = read_mtu(settings_.can_interface);
  const std::string driver =
    read_link_name("/sys/class/net/" + settings_.can_interface + "/device/driver");
  RCLCPP_INFO(
    node_->get_logger(), "connected on %s (driver %s, MTU %lu, CAN FD %s), mode %s",
    settings_.can_interface.c_str(), driver.empty() ? "unknown" : driver.c_str(), mtu,
    mtu >= 72 ? "available" : "unavailable", settings_.can_mode.c_str());

  if (!apply_transmit_ids(reason)) {
    comms_.reset();
    return false;
  }

  if (!comms_->cmd_mode(settings_.can_mode.c_str())) {
    reason = comms_->last_error();
    comms_.reset();
    return false;
  }
  RCLCPP_INFO(node_->get_logger(), "CAN mode applied: %s", settings_.can_mode.c_str());

  if (!comms_->on_transmit(
      static_cast<std::uint32_t>(settings_.rate_hz), settings_.data_type.c_str()))
  {
    reason = comms_->last_error();
    comms_.reset();
    return false;
  }
  RCLCPP_INFO(
    node_->get_logger(), "transmitting %s at %d Hz",
    settings_.data_type.c_str(), settings_.rate_hz);

  set_bias_ = node_->create_service<std_srvs::srv::Trigger>(
    "~/set_bias",
    [this](
      const std::shared_ptr<std_srvs::srv::Trigger::Request> req,
      std::shared_ptr<std_srvs::srv::Trigger::Response> res) {handle_set_bias(req, res);});
  confirm_id_ = node_->create_service<std_srvs::srv::Trigger>(
    "~/confirm_id",
    [this](
      const std::shared_ptr<std_srvs::srv::Trigger::Request> req,
      std::shared_ptr<std_srvs::srv::Trigger::Response> res) {handle_confirm_id(req, res);});
  restore_defaults_ = node_->create_service<std_srvs::srv::Trigger>(
    "~/restore_defaults",
    [this](
      const std::shared_ptr<std_srvs::srv::Trigger::Request> req,
      std::shared_ptr<std_srvs::srv::Trigger::Response> res) {handle_restore_defaults(req, res);});

  return true;
}

// The transmit ID lives in the sensor's NVM, so the driver finds out what it is before deciding
// whether the parameters ask for a different one. Writing it unconditionally at every startup
// would put a flash write in the boot path of every robot.
bool Services::apply_transmit_ids(std::string & reason)
{
  if (!comms_->cmd_confirm_id()) {
    reason = comms_->last_error();
    return false;
  }
  rclcpp::sleep_for(std::chrono::milliseconds(CONFIRM_ID_WAIT_MS));

  std::uint16_t id20 = 0;
  std::uint16_t idfd = 0;
  comms_->current_tx_id(id20, idfd);
  RCLCPP_INFO(
    node_->get_logger(), "sensor transmit ID 2.0=%s FD=%s",
    as_hex(id20).c_str(), as_hex(idfd).c_str());

  const bool change_can20 = (id20 != settings_.set_id_can20);
  const bool change_canfd = (idfd != settings_.set_id_canfd);
  if (!change_can20 && !change_canfd) {
    return true;
  }

  if (change_can20) {
    RCLCPP_INFO(
      node_->get_logger(), "changing the CAN 2.0 transmit ID from %s to %s",
      as_hex(id20).c_str(), as_hex(settings_.set_id_can20).c_str());
    if (!comms_->send_set_id(true, static_cast<std::uint16_t>(settings_.set_id_can20))) {
      reason = comms_->last_error();
      return false;
    }
  }
  if (change_canfd) {
    RCLCPP_INFO(
      node_->get_logger(), "changing the CAN FD transmit ID from %s to %s",
      as_hex(idfd).c_str(), as_hex(settings_.set_id_canfd).c_str());
    if (!comms_->send_set_id(false, static_cast<std::uint16_t>(settings_.set_id_canfd))) {
      reason = comms_->last_error();
      return false;
    }
  }

  // SET ID is not acknowledged, so the sensor is asked again rather than assumed to have moved.
  if (!comms_->cmd_confirm_id()) {
    reason = comms_->last_error();
    return false;
  }
  rclcpp::sleep_for(std::chrono::milliseconds(CONFIRM_ID_WAIT_MS));
  comms_->current_tx_id(id20, idfd);

  if (id20 != settings_.set_id_can20 || idfd != settings_.set_id_canfd) {
    RCLCPP_WARN(
      node_->get_logger(),
      "the sensor reports 2.0=%s FD=%s but the parameters ask for 2.0=%s FD=%s. "
      "Reading continues on the IDs the sensor reported",
      as_hex(id20).c_str(), as_hex(idfd).c_str(),
      as_hex(settings_.set_id_can20).c_str(), as_hex(settings_.set_id_canfd).c_str());
  } else {
    RCLCPP_INFO(
      node_->get_logger(), "sensor transmit ID now 2.0=%s FD=%s",
      as_hex(id20).c_str(), as_hex(idfd).c_str());
  }
  return true;
}

void Services::stop()
{
  set_bias_.reset();
  confirm_id_.reset();
  restore_defaults_.reset();
  comms_.reset();
}

bool Services::read_latest(Sample & out)
{
  return comms_ != nullptr && comms_->read_latest(out);
}

bool Services::resume_stream(std::string & reason)
{
  if (!comms_->on_transmit(
      static_cast<std::uint32_t>(settings_.rate_hz), settings_.data_type.c_str()))
  {
    reason = comms_->last_error();
    return false;
  }
  RCLCPP_INFO(
    node_->get_logger(), "transmitting %s at %d Hz",
    settings_.data_type.c_str(), settings_.rate_hz);
  return true;
}

void Services::handle_set_bias(
  const std::shared_ptr<std_srvs::srv::Trigger::Request>,
  std::shared_ptr<std_srvs::srv::Trigger::Response> response)
{
  if (comms_ == nullptr) {
    response->success = false;
    response->message = "the bus is not open";
    return;
  }
  if (!comms_->cmd_bias()) {
    RCLCPP_ERROR(node_->get_logger(), "BIAS failed: %s", comms_->last_error());
    response->success = false;
    response->message = comms_->last_error();
    return;
  }
  RCLCPP_INFO(node_->get_logger(), "BIAS sent: the present load is now zero");
  response->success = true;
  response->message = "the present load is now zero";
}

void Services::handle_confirm_id(
  const std::shared_ptr<std_srvs::srv::Trigger::Request>,
  std::shared_ptr<std_srvs::srv::Trigger::Response> response)
{
  if (comms_ == nullptr) {
    response->success = false;
    response->message = "the bus is not open";
    return;
  }
  if (!comms_->cmd_confirm_id()) {
    RCLCPP_ERROR(node_->get_logger(), "CONFIRM ID failed: %s", comms_->last_error());
    response->success = false;
    response->message = comms_->last_error();
    return;
  }

  rclcpp::sleep_for(std::chrono::milliseconds(CONFIRM_ID_WAIT_MS));
  std::uint16_t id20 = 0;
  std::uint16_t idfd = 0;
  comms_->current_tx_id(id20, idfd);
  const std::string text = "2.0=" + as_hex(id20) + " FD=" + as_hex(idfd);
  RCLCPP_INFO(node_->get_logger(), "transmit ID %s", text.c_str());
  response->success = true;
  response->message = text;
}

void Services::handle_restore_defaults(
  const std::shared_ptr<std_srvs::srv::Trigger::Request>,
  std::shared_ptr<std_srvs::srv::Trigger::Response> response)
{
  if (comms_ == nullptr) {
    response->success = false;
    response->message = "the bus is not open";
    return;
  }
  if (!comms_->cmd_factory_reset()) {
    RCLCPP_ERROR(node_->get_logger(), "factory reset failed: %s", comms_->last_error());
    response->success = false;
    response->message = comms_->last_error();
    return;
  }
  RCLCPP_INFO(
    node_->get_logger(),
    "factory reset sent. The sensor stopped transmitting and its IDs are back to the defaults");

  std::string reason;
  if (!resume_stream(reason)) {
    RCLCPP_ERROR(node_->get_logger(), "could not resume the stream: %s", reason.c_str());
    response->success = false;
    response->message = "the reset was sent but the stream did not come back: " + reason;
    return;
  }
  response->success = true;
  response->message = "the sensor is back to its factory settings";
}

}  // namespace aidin::aft150_d50
