///|
fn main {
  println("==================================================")
  println("   MoonSim 微服务网格仿真示例：链路熔断与灰度流量切分   ")
  println("==================================================")

  let sim = @moonsim.Simulation::new()
  let topo : @network.NetworkTopology[String] = sim.create_network_topology(20260708)

  // 服务拓扑: Gateway -> [ServiceA, ServiceB_v1, ServiceB_v2]
  // ServiceA -> [Database]
  topo.add_node(1) // API Gateway
  topo.add_node(2) // ServiceA (稳定版)
  topo.add_node(3) // ServiceB-v1 (老版本, 90%流量)
  topo.add_node(4) // ServiceB-v2 (金丝雀版本, 10%流量)
  topo.add_node(5) // Database

  // 正常延迟链路 (< 5ms)
  topo.add_link(1, 2, 0.004, 0.01)
  topo.add_link(1, 3, 0.003, 0.01)
  topo.add_link(1, 4, 0.003, 0.02) // 金丝雀版本略高丢包率
  topo.add_link(2, 5, 0.001, 0.005)

  let lat_tracker = @stats.PercentileTracker::new("P2P延迟分布(ms)")
  let v1_success = @stats.ThroughputTracker::new("ServiceB-v1成功量", 0.0)
  let v2_success = @stats.ThroughputTracker::new("ServiceB-v2成功量", 0.0)
  let mut circuit_broken = false
  let mut circuit_break_time = 0.0
  let mut total_requests = 0
  let mut gateway_to_v2_fail = 0

  // 发送请求并收集延迟
  let mut req_id = 1

  let req_steps : Array[(@event.ProcessContext) -> Double?] = [
    fn(ctx) {
      if req_id <= 20 {
        let rid = req_id
        req_id = req_id + 1
        let now = ctx.clock.now_seconds()
        total_requests = total_requests + 1

        // 灰度流量切分: 90% -> ServiceB-v1, 10% -> ServiceB-v2
        // 用请求 id 模拟: rid mod 10 == 0 -> v2 (10%)
        let use_v2 = rid % 10 == 0

        if use_v2 && !circuit_broken {
          println("[\{now}s] [灰度分流] 请求 #\{rid} -> ServiceB-v2 (金丝雀)")
          let _ = topo.send_packet(1, 4, "REQ #\{rid} -> v2", 5, fn(pkt) {
            let delay = (sim.now() - now) * 1000.0
            lat_tracker.record(delay)
            println("[\{sim.now()}s] [ServiceB-v2] 收到 \{pkt.payload}, 延迟: \{delay}ms")
            v2_success.record(sim.now(), 1)
          })
        } else if !circuit_broken {
          // ServiceB-v1
          let _ = topo.send_packet(1, 3, "REQ #\{rid} -> v1", 5, fn(pkt) {
            let delay = (sim.now() - now) * 1000.0
            lat_tracker.record(delay)
            println("[\{sim.now()}s] [ServiceB-v1] 收到 \{pkt.payload}, 延迟: \{delay}ms")
            v1_success.record(sim.now(), 1)
          })
        } else {
          println("[\{now}s] [熔断器] 电路熔断中, 请求 #\{rid} 直接返回 fallback!")
        }
        Some(0.4) // 每0.4s发送一个请求
      } else {
        None
      }
    },
  ]
  let _ = sim.start_process(sim.register_process("请求生成器", req_steps), 0.0, 5)

  // 注入故障: t=2.5s ServiceB-v2 故障率升高(模拟部署缺陷), t=4.5s 触发熔断
  let _ = sim.schedule(2.5, 0, fn() {
    println("\n[!!! 故障注入 !!!] [\{sim.now()}s] ServiceB-v2 发现内存泄漏，丢包率突升至 100%\n")
    topo.set_node_status(4, @network.Offline)
    gateway_to_v2_fail = gateway_to_v2_fail + 1
  })

  let _ = sim.schedule(4.5, 0, fn() {
    println("\n[熔断器触发] [\{sim.now()}s] 连续失败达到阈值，ServiceB-v2 熔断激活，所有流量切回 v1\n")
    circuit_broken = true
    circuit_break_time = sim.now()
  })

  sim.run_until(10.0)

  println("\n==================================================")
  println("              微服务网格可观测性分析报告              ")
  println("==================================================")
  println("仿真总请求数: \{total_requests}")
  println("ServiceB-v1 处理成功量: \{v1_success.count}")
  println("ServiceB-v2 (金丝雀) 成功量: \{v2_success.count}")
  println("金丝雀版本触发熔断时刻: \{circuit_break_time}s")
  println("P2P 端到端延迟 P50: \{lat_tracker.p50()}ms")
  println("P2P 端到端延迟 P95: \{lat_tracker.p95()}ms")
  println("P2P 端到端延迟 P99: \{lat_tracker.p99()}ms")
  println("==================================================\n")
}
