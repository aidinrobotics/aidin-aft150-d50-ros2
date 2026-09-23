#include <algorithm>
#include <atomic>
#include <chrono>
#include <memory>
#include <string>
#include <thread>

#include "aidin_aft150_d50_driver/aft150_d50_services.hpp"

#include "geometry_msgs/msg/wrench_stamped.hpp"
#include "rclcpp/rclcpp.hpp"

namespace aidin::aft150_d50
{

class Aft150D50Node : public rclcpp::Node
{
public:
  Aft150D50Node()
  : Node("aft150_d50")
  {
    declare_settings(this, settings_);

    publisher_ = create_publisher<geometry_msgs::msg::WrenchStamped>(
      "~/wrench", rclcpp::SensorDataQoS());
  }

  ~Aft150D50Node() override
  {
    running_.store(false);
    if (publish_thread_.joinable()) {
      publish_thread_.join();
    }
  }

  bool start()
  {
    services_ = std::make_unique<Services>(this, settings_);
    std::string reason;
    if (!services_->start(reason)) {
      RCLCPP_FATAL(get_logger(), "%s", reason.c_str());
      return false;
    }
    running_.store(true);
    publish_thread_ = std::thread([this] {publish_loop();});
    return true;
  }

private:
  void publish_loop()
  {
    geometry_msgs::msg::WrenchStamped msg;
    Sample s{};

    while (running_.load(std::memory_order_relaxed) && rclcpp::ok()) {
      if (!services_->read_latest(s)) {
        const int hz = std::max(1, services_->settings().rate_hz);
        std::this_thread::sleep_for(std::chrono::microseconds(250000 / hz));
        continue;
      }
      msg.header.stamp = rclcpp::Time(s.stamp_ns);
      msg.header.frame_id = services_->settings().frame_id;
      msg.wrench.force.x = s.fx;
      msg.wrench.force.y = s.fy;
      msg.wrench.force.z = s.fz;
      msg.wrench.torque.x = s.tx;
      msg.wrench.torque.y = s.ty;
      msg.wrench.torque.z = s.tz;
      publisher_->publish(msg);
    }
  }

  Settings settings_;
  std::unique_ptr<Services> services_;
  rclcpp::Publisher<geometry_msgs::msg::WrenchStamped>::SharedPtr publisher_;

  std::atomic<bool> running_{false};
  std::thread publish_thread_;
};

}  // namespace aidin::aft150_d50

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  auto node = std::make_shared<aidin::aft150_d50::Aft150D50Node>();
  if (!node->start()) {
    rclcpp::shutdown();
    return 1;
  }
  rclcpp::spin(node);
  rclcpp::shutdown();
  return 0;
}
