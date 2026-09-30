#include "aidin_aft150_d50_driver/aft150_d50_services.hpp"

#include <cstdio>
#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"

namespace
{

int failures = 0;

#define CHECK(cond)                                                          \
  do {                                                                       \
    if (!(cond)) {                                                           \
      std::fprintf(stderr, "FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
      ++failures;                                                            \
    }                                                                        \
  } while (0)

using namespace aidin::aft150_d50;  // NOLINT(build/namespaces)

void test_can_mode()
{
  CHECK(is_valid_can_mode("classic"));
  CHECK(is_valid_can_mode("fd"));
  CHECK(is_valid_can_mode("fd_brs"));

  CHECK(!is_valid_can_mode("CAN 2.0"));
  CHECK(!is_valid_can_mode("FD"));
  CHECK(!is_valid_can_mode("brs"));
  CHECK(!is_valid_can_mode(""));

  CHECK(!can_mode_is_fd("classic"));
  CHECK(can_mode_is_fd("fd"));
  CHECK(can_mode_is_fd("fd_brs"));

  CHECK(can_mode_names().size() == 3);
}

void test_data_type()
{
  CHECK(is_valid_data_type("int6"));
  CHECK(is_valid_data_type("int12_combined"));
  CHECK(is_valid_data_type("float_combined"));

  CHECK(!is_valid_data_type("float"));
  CHECK(!is_valid_data_type("INT6"));
  CHECK(!is_valid_data_type(""));

  CHECK(data_type_names().size() == 3);

  CHECK(!data_type_needs_fd("int6"));
  CHECK(data_type_needs_fd("int12_combined"));
  CHECK(data_type_needs_fd("float_combined"));
}

void test_rate_hz()
{
  CHECK(is_valid_rate_hz(100));
  CHECK(is_valid_rate_hz(250));
  CHECK(is_valid_rate_hz(500));
  CHECK(is_valid_rate_hz(1000));

  CHECK(!is_valid_rate_hz(0));
  CHECK(!is_valid_rate_hz(-1));
  CHECK(!is_valid_rate_hz(200));
  CHECK(!is_valid_rate_hz(999));
  CHECK(!is_valid_rate_hz(2000));

  CHECK(rate_hz_values().size() == 4);
}

void test_set_id_range()
{
  // The range is the only thing checked. A value that makes the two buses overlap, or one that
  // collides with a command ID, is accepted here and lands in the sensor's NVM. Restoring the
  // defaults is the way back.
  CHECK(is_valid_set_id(0x000));
  CHECK(is_valid_set_id(0x230));
  CHECK(is_valid_set_id(0x330));
  CHECK(is_valid_set_id(0x7FF));

  CHECK(!is_valid_set_id(-1));
  CHECK(!is_valid_set_id(0x800));
  CHECK(!is_valid_set_id(0x10000));

  // Overlapping windows and command-ID collisions pass, on purpose.
  CHECK(is_valid_set_id(0x220));
  CHECK(is_valid_set_id(0x331));
}

void test_defaults_are_consistent()
{
  Settings s;
  std::string reason;
  CHECK(validate(s, reason));
  CHECK(reason.empty());
}

void test_combined_types_need_fd()
{
  // The two combined types put six axes in one frame, which a classic frame cannot hold. This
  // is the combination a user is most likely to reach by editing one line of the YAML.
  Settings s;
  s.can_mode = "classic";

  for (const char * type : {"int12_combined", "float_combined"}) {
    s.data_type = type;
    std::string reason;
    CHECK(!validate(s, reason));
    CHECK(!reason.empty());
  }

  s.data_type = "int6";
  {
    std::string reason;
    CHECK(validate(s, reason));
  }

  // With CAN FD every type is allowed.
  s.can_mode = "fd_brs";
  for (const std::string & type : data_type_names()) {
    s.data_type = type;
    std::string reason;
    CHECK(validate(s, reason));
  }
}

void test_validate_reports_each_bad_field()
{
  {
    Settings s;
    s.can_mode = "turbo";
    std::string reason;
    CHECK(!validate(s, reason));
    CHECK(reason.find("can_mode") != std::string::npos);
  }
  {
    Settings s;
    s.data_type = "no_such_type";
    std::string reason;
    CHECK(!validate(s, reason));
    CHECK(reason.find("data_type") != std::string::npos);
  }
  {
    Settings s;
    s.rate_hz = 333;
    std::string reason;
    CHECK(!validate(s, reason));
    CHECK(reason.find("rate_hz") != std::string::npos);
  }
  {
    Settings s;
    s.set_id_can20 = 0x800;
    std::string reason;
    CHECK(!validate(s, reason));
    CHECK(reason.find("set_id_can20") != std::string::npos);
  }
  {
    Settings s;
    s.set_id_canfd = -1;
    std::string reason;
    CHECK(!validate(s, reason));
    CHECK(reason.find("set_id_canfd") != std::string::npos);
  }
  {
    Settings s;
    s.can_interface.clear();
    std::string reason;
    CHECK(!validate(s, reason));
    CHECK(reason.find("can_interface") != std::string::npos);
  }
}

void test_parameters_are_read_only()
{
  // Every parameter is read at startup and none of them can be changed afterwards. Changing the
  // mode, the data type or the rate makes the sensor stop transmitting for about 100 ms while the
  // driver puts the stream back, and in the ros2_control path read() keeps returning the last
  // sample throughout. A robot holding a force target would act on a stale value for 100 cycles.
  auto node = std::make_shared<rclcpp::Node>("aft150_d50_param_probe");
  Settings s;
  declare_settings(node.get(), s);

  for (const char * name : {"can_interface", "can_mode", "data_type", "rate_hz",
      "set_id_can20", "set_id_canfd", "frame_id"})
  {
    CHECK(node->describe_parameter(name).read_only);
  }

  // rclcpp refuses the write rather than the driver having to catch it. Depending on the path it
  // takes, it either returns an unsuccessful result or throws, so both count as refused, and the
  // value is checked afterwards because that is what actually matters.
  const auto refuses = [&node](const rclcpp::Parameter & p) {
      try {
        return !node->set_parameter(p).successful;
      } catch (const rclcpp::exceptions::ParameterImmutableException &) {
        return true;
      }
    };

  CHECK(refuses(rclcpp::Parameter("rate_hz", 500)));
  CHECK(node->get_parameter("rate_hz").as_int() == s.rate_hz);

  CHECK(refuses(rclcpp::Parameter("set_id_can20", 0x341)));
  CHECK(node->get_parameter("set_id_can20").as_int() == s.set_id_can20);

  CHECK(refuses(rclcpp::Parameter("can_mode", std::string("classic"))));
  CHECK(node->get_parameter("can_mode").as_string() == s.can_mode);

  // Declaring picks up what the caller already holds, which is how the ros2_control component
  // passes the values that arrived as <param>.
  Settings given;
  given.can_interface = "can7";
  given.rate_hz = 250;
  auto other = std::make_shared<rclcpp::Node>("aft150_d50_param_probe_2");
  declare_settings(other.get(), given);
  CHECK(other->get_parameter("can_interface").as_string() == "can7");
  CHECK(other->get_parameter("rate_hz").as_int() == 250);

  // frame_id defaults to the node name when nothing set it.
  CHECK(other->get_parameter("frame_id").as_string() == "aft150_d50_param_probe_2_link");
}

}  // namespace

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);

  test_can_mode();
  test_data_type();
  test_rate_hz();
  test_set_id_range();
  test_defaults_are_consistent();
  test_combined_types_need_fd();
  test_validate_reports_each_bad_field();
  test_parameters_are_read_only();

  rclcpp::shutdown();

  if (failures == 0) {
    std::printf("ok  aft150_d50_param_test\n");
    return 0;
  }
  std::fprintf(stderr, "aft150_d50_param_test: %d check(s) failed\n", failures);
  return 1;
}
