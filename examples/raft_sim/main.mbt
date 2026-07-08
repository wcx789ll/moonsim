///|
fn main {
  println("==================================================")
  println(
    "   MoonSim 分布式系统网络仿真示例：Raft心跳与网络分区   ",
  )
  println("==================================================")

  let sim = @moonsim.Simulation::new()
  let topo : @network.NetworkTopology[String] = sim.create_network_topology(
    20260708,
  )

  topo.add_node(1) // Leader
  topo.add_node(2) // Follower A
  topo.add_node(3) // Follower B

  // Links with 0.01s (10ms) latency and 0.05 (5%) drop probability
  topo.add_link(1, 2, 0.01, 0.05)
  topo.add_link(1, 3, 0.01, 0.05)

  let mut heartbeat_seq = 1

  // Periodic Leader Heartbeat process
  let steps : Array[(@event.ProcessContext) -> Double?] = [
    fn(ctx : @event.ProcessContext) -> Double? {
      if ctx.clock.now_seconds() <= 0.4 {
        let seq = heartbeat_seq
        heartbeat_seq = heartbeat_seq + 1
        let now = ctx.clock.now_seconds()
        println(
          "[\{now}s] Leader(Node 1) 发送心跳包 #\{seq} -> Node 2, Node 3",
        )

        let _ = topo.send_packet(1, 2, "HEARTBEAT #\{seq}", 5, fn(pkt) {
          println("[\{sim.now()}s] Follower(Node 2) 收到: \{pkt.payload}")
        })
        let _ = topo.send_packet(1, 3, "HEARTBEAT #\{seq}", 5, fn(pkt) {
          println("[\{sim.now()}s] Follower(Node 3) 收到: \{pkt.payload}")
        })
        Some(0.05) // Send heartbeat every 50ms
      } else {
        None
      }
    },
  ]

  let leader_proc = sim.register_process("LeaderHeartbeat", steps)
  let _ = sim.start_process(leader_proc, 0.0, 5)

  // Inject Network Partition at t=0.12s (Node 3 goes Offline)
  let _ = sim.schedule(0.12, 0, fn() {
    println(
      "\n[!!! 故障注入 !!!] [\{sim.now()}s] Node 3 发生网络分区/宕机状态切换为 Offline\n",
    )
    topo.set_node_status(3, @network.Offline)
  })

  // Recover Node 3 at t=0.28s
  let _ = sim.schedule(0.28, 0, fn() {
    println(
      "\n[+++ 故障恢复 +++] [\{sim.now()}s] Node 3 网络分区恢复，状态切换为 Online\n",
    )
    topo.set_node_status(3, @network.Online)
  })

  sim.run_until(0.45)

  println("\n==================================================")
  println("               分布式网络通信统计                   ")
  println("==================================================")
  let link12 = topo.get_link(1, 2).unwrap()
  println("Link 1->2 (Leader -> Follower A):")
  println("  发送总数据包: \{link12.packets_sent()}")
  println("  成功送达: \{link12.packets_delivered()}")
  println("  丢失/超时: \{link12.packets_dropped()}")

  let link13 = topo.get_link(1, 3).unwrap()
  println("Link 1->3 (Leader -> Follower B [分区经历者]):")
  println("  发送总数据包: \{link13.packets_sent()}")
  println("  成功送达: \{link13.packets_delivered()}")
  println("  丢失/超时: \{link13.packets_dropped()}")
  println("==================================================\n")
}
