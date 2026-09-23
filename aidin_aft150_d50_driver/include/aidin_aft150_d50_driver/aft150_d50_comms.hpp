#ifndef AIDIN_AFT150_D50_DRIVER__AFT150_D50_COMMS_HPP_
#define AIDIN_AFT150_D50_DRIVER__AFT150_D50_COMMS_HPP_

#include <cstddef>
#include <cstdint>

namespace aidin::aft150_d50
{

struct Sample
{
  double fx;
  double fy;
  double fz;
  double tx;
  double ty;
  double tz;
  std::int64_t stamp_ns;
};

class Comms
{
public:
  static Comms * open_bus(
    const char * can_interface, const char * can_mode, char * err, std::size_t err_len);

  ~Comms();

  Comms(const Comms &) = delete;
  Comms & operator=(const Comms &) = delete;

  bool read_latest(Sample & out);

  bool cmd_bias();
  bool cmd_mode(const char * can_mode);
  bool on_transmit(std::uint32_t hz, const char * data_type);
  bool cmd_set_rate(std::uint32_t hz);
  bool cmd_confirm_id();
  bool send_set_id(bool is_can20, std::uint16_t new_id);
  bool cmd_factory_reset();

  void current_tx_id(std::uint16_t & can20, std::uint16_t & canfd) const;
  const char * last_error() const;

private:
  struct Impl;

  explicit Comms(Impl * impl);

  Impl * impl_;
};

}  // namespace aidin::aft150_d50

#endif  // AIDIN_AFT150_D50_DRIVER__AFT150_D50_COMMS_HPP_
