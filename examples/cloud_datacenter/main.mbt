///|
fn main {
  println("==================================================")
  println("   MoonSim 云计算数据中心仿真示例：多租户GPU抢占与调度   ")
  println("==================================================")

  let sim = @moonsim.Simulation::new()
  let gpu_cluster = @resource.PreemptibleResource::new("NVIDIA-H800集群", 4)
  let spot_tracker = @stats.PercentileTracker::new("Spot任务响应时间(ms)")
  let vip_tracker = @stats.PercentileTracker::new("VIP任务响应时间(ms)")

  let mut spot_id = 1
  let mut vip_id = 1
  let mut spot_completed = 0
  let mut vip_completed = 0
  let mut spot_preempted = 0

  // 1. Low-priority Spot Batch Job Generator (prio=10)
  let spot_steps : Array[(@event.ProcessContext) -> Double?] = [
    fn(ctx) {
      if spot_id <= 6 {
        let jid = spot_id
        spot_id = spot_id + 1
        let arrival = ctx.clock.now_seconds()
        println("[\{arrival}s] [Spot批处理] 任务 #\{jid} 申请 2卡 GPU (优先级=10)")
        
        let _ = gpu_cluster.request(
          2,
          10,
          fn(holder) {
            if holder is Some(_) {
              let start = sim.now()
              println("[\{start}s] [Spot批处理] 任务 #\{jid} 成功获取 2卡 GPU，开始训练")
              let _ = sim.schedule(4.0, 10, fn() {
                // If not preempted, complete training!
                gpu_cluster.release(holder.unwrap())
                spot_completed = spot_completed + 1
                let dur = (sim.now() - arrival) * 1000.0
                spot_tracker.record(dur)
                println("[\{sim.now()}s] [Spot批处理] 任务 #\{jid} 训练完成释放 GPU！总耗时: \{dur}ms")
              })
            }
          },
          fn() {
            spot_preempted = spot_preempted + 1
            println("[\{sim.now()}s] [!!! 资源抢占 !!!] [Spot批处理] 任务 #\{jid} 被高优先级 VIP 业务抢占并驱逐出集群！")
          }
        )
        Some(1.2) // New spot job every 1.2s
      } else {
        None
      }
    },
  ]
  let _ = sim.start_process(sim.register_process("Spot作业生成器", spot_steps), 0.0, 10)

  // 2. High-priority VIP Online Job Generator (prio=1)
  let vip_steps : Array[(@event.ProcessContext) -> Double?] = [
    fn(ctx) {
      if vip_id <= 3 {
        let vid = vip_id
        vip_id = vip_id + 1
        let arrival = ctx.clock.now_seconds()
        println("\n[\{arrival}s] [+++ VIP推理 +++] 紧急任务 #\{vid} 申请 3卡 GPU (最高优先级=1)")
        
        let _ = gpu_cluster.request(
          3,
          1,
          fn(holder) {
            if holder is Some(_) {
              let start = sim.now()
              println("[\{start}s] [VIP推理] 任务 #\{vid} 瞬间分配并独占 3卡 GPU！等待时间: \{(start - arrival)*1000.0}ms")
              let _ = sim.schedule(1.5, 1, fn() {
                gpu_cluster.release(holder.unwrap())
                vip_completed = vip_completed + 1
                let dur = (sim.now() - arrival) * 1000.0
                vip_tracker.record(dur)
                println("[\{sim.now()}s] [VIP推理] 紧急任务 #\{vid} 计算完成出库，释放 GPU 资源池。")
              })
            }
          },
          fn() {
            println("[\{sim.now()}s] [VIP任务被抢占异常]")
          }
        )
        Some(3.0) // VIP burst arrives at t=2.0, t=5.0, t=8.0
      } else {
        None
      }
    },
  ]
  let _ = sim.start_process(sim.register_process("VIP在线业务网关", vip_steps), 2.0, 1)

  sim.run_until(15.0)

  println("\n==================================================")
  println("                云原生集群调度分析报告              ")
  println("==================================================")
  println("仿真虚拟总时长: \{sim.now()}s")
  println("VIP高优先级业务完结数: \{vip_completed} (响应时间 P50: \{vip_tracker.p50()}ms, P99: \{vip_tracker.p99()}ms)")
  println("Spot低优先级批处理完结数: \{spot_completed}")
  println("触发优先级抢占驱逐次数: \{spot_preempted}")
  println("==================================================\n")
}
