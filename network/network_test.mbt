///|
test "network_deterministic_packet_delivery_and_drop" {
  let clock = @clock.Clock::new()
  let mgr = @event.EventManager::new(clock)
  let topo : NetworkTopology[String] = NetworkTopology::new(mgr, 42)

  topo.add_node(1)
  topo.add_node(2)
  // Add a link with 0.0 drop rate -> 100% reliable
  topo.add_link(1, 2, 0.05, 0.0)

  let mut delivered_msg = ""
  let sent = topo.send_packet(1, 2, "Hello Raft", 10, fn(pkt : Packet[String]) {
    delivered_msg = pkt.payload
  })
  assert_true(sent)

  mgr.run()
  assert_eq(delivered_msg, "Hello Raft")
  assert_eq(clock.now_seconds(), 0.05)

  let mailbox = topo.get_mailbox(2)
  assert_eq(mailbox.length(), 1)
  assert_eq(mailbox[0].payload, "Hello Raft")

  // Now test node going Offline
  topo.set_node_status(2, Offline)
  let sent_off = topo.send_packet(1, 2, "Should Drop", 10, fn(_pkt) {  })
  assert_true(!sent_off)
}

///|
test "network_bandwidth_link_queueing_and_overflow" {
  // 1000 bytes/sec link, 0.01s propagation, buffer cap 2500 bytes
  let bw = BandwidthLink::new(1, 2, 1000.0, 0.01, 2500)

  // Packet 1: 1000 bytes at t=0.0 -> serialization take 1.0s, arrives at 1.01s
  let p1_delivery = bw.transmit(0.0, 1000)
  assert_true(p1_delivery is Some(_))
  assert_eq(p1_delivery.unwrap(), 1.01)

  // Packet 2: 1000 bytes immediately after at t=0.0 -> queued behind P1 until t=1.0, takes 1.0s, arrives at 2.01s!
  let p2_delivery = bw.transmit(0.0, 1000)
  assert_true(p2_delivery is Some(_))
  assert_eq(p2_delivery.unwrap(), 2.01)

  // Packet 3: 1000 bytes at t=0.0 -> buffer already has 2000 bytes. 2000 + 1000 > 2500 cap -> MUST DROP!
  let p3_delivery = bw.transmit(0.0, 1000)
  assert_true(p3_delivery is None)
  assert_eq(bw.overflow_drops(), 1)
  assert_eq(bw.packets_sent(), 3)
  assert_eq(bw.packets_delivered(), 2)

  // Average queueing delay: P1 delayed 0s, P2 delayed 1.0s. Mean queueing delay = 0.5s!
  assert_eq(bw.mean_queueing_delay(), 0.5)
}
