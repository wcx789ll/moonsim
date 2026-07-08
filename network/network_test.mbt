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
