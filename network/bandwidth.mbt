///|
pub(all) struct BandwidthLink {
  src : Int
  dst : Int
  bandwidth_bps : Double
  propagation_latency : Double
  buffer_capacity_bytes : Int
  mut current_buffer_bytes : Int
  mut next_available_time : Double
  mut packets_sent : Int
  mut packets_delivered : Int
  mut overflow_drops : Int
  mut total_queueing_delay : Double
}

///|
pub fn BandwidthLink::new(
  src : Int,
  dst : Int,
  bandwidth_bps : Double,
  propagation_latency : Double,
  buffer_capacity_bytes : Int,
) -> BandwidthLink {
  if bandwidth_bps <= 0.0 ||
    propagation_latency < 0.0 ||
    buffer_capacity_bytes < 0 {
    abort("Invalid BandwidthLink parameters")
  }
  {
    src,
    dst,
    bandwidth_bps,
    propagation_latency,
    buffer_capacity_bytes,
    current_buffer_bytes: 0,
    next_available_time: 0.0,
    packets_sent: 0,
    packets_delivered: 0,
    overflow_drops: 0,
    total_queueing_delay: 0.0,
  }
}

///|
pub fn BandwidthLink::update_buffer(self : BandwidthLink, now : Double) -> Unit {
  if now > self.next_available_time {
    self.current_buffer_bytes = 0
  } else {
    // Estimate cleared buffer
    let remaining_time = self.next_available_time - now
    let remaining_bytes = (remaining_time * self.bandwidth_bps).to_int()
    if remaining_bytes < self.current_buffer_bytes {
      self.current_buffer_bytes = if remaining_bytes > 0 {
        remaining_bytes
      } else {
        0
      }
    }
  }
}

///|
pub fn BandwidthLink::transmit(
  self : BandwidthLink,
  now : Double,
  size_bytes : Int,
) -> Double? {
  self.packets_sent = self.packets_sent + 1
  self.update_buffer(now)

  if self.current_buffer_bytes + size_bytes > self.buffer_capacity_bytes {
    self.overflow_drops = self.overflow_drops + 1
    return None
  }

  self.current_buffer_bytes = self.current_buffer_bytes + size_bytes
  let tx_start = if now > self.next_available_time {
    now
  } else {
    self.next_available_time
  }
  let queue_delay = tx_start - now
  self.total_queueing_delay = self.total_queueing_delay + queue_delay

  let tx_duration = Double::from_int(size_bytes) / self.bandwidth_bps
  self.next_available_time = tx_start + tx_duration
  let delivery_time = self.next_available_time + self.propagation_latency
  self.packets_delivered = self.packets_delivered + 1
  Some(delivery_time)
}

///|
pub fn BandwidthLink::packets_sent(self : BandwidthLink) -> Int {
  self.packets_sent
}

///|
pub fn BandwidthLink::packets_delivered(self : BandwidthLink) -> Int {
  self.packets_delivered
}

///|
pub fn BandwidthLink::overflow_drops(self : BandwidthLink) -> Int {
  self.overflow_drops
}

///|
pub fn BandwidthLink::mean_queueing_delay(self : BandwidthLink) -> Double {
  if self.packets_delivered == 0 {
    0.0
  } else {
    self.total_queueing_delay / Double::from_int(self.packets_delivered)
  }
}
