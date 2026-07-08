///|
pub(all) enum NodeStatus {
  Online
  Offline
  Partitioned
} derive(Debug, Eq)

///|
pub impl Show for NodeStatus with fn output(self, logger) {
  match self {
    Online => logger.write_string("Online")
    Offline => logger.write_string("Offline")
    Partitioned => logger.write_string("Partitioned")
  }
}

///|
pub(all) struct Packet[T] {
  src : Int
  dst : Int
  payload : T
  send_time : Double
}

///|
pub(all) struct NetworkLink {
  src : Int
  dst : Int
  latency : Double
  drop_probability : Double
  mut packets_sent : Int
  mut packets_dropped : Int
  mut packets_delivered : Int
}

///|
pub fn NetworkLink::new(
  src : Int,
  dst : Int,
  latency : Double,
  drop_probability : Double,
) -> NetworkLink {
  if latency < 0.0 || drop_probability < 0.0 || drop_probability > 1.0 {
    abort("Invalid NetworkLink parameters")
  }
  {
    src,
    dst,
    latency,
    drop_probability,
    packets_sent: 0,
    packets_dropped: 0,
    packets_delivered: 0,
  }
}

///|
pub fn NetworkLink::packets_sent(self : NetworkLink) -> Int {
  self.packets_sent
}

///|
pub fn NetworkLink::packets_dropped(self : NetworkLink) -> Int {
  self.packets_dropped
}

///|
pub fn NetworkLink::packets_delivered(self : NetworkLink) -> Int {
  self.packets_delivered
}
