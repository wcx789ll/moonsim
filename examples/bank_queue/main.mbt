///|
fn main {
  println("==================================================")
  println(
    "   MoonSim 确定性离散事件仿真示例：多窗口银行排队系统   ",
  )
  println("==================================================")

  let sim = @moonsim.Simulation::new()
  let teller = sim.create_resource("柜员窗口", 2)
  let queue_summary = sim.create_summary("排队人数均值", 0.0)
  let sla_monitor = @stats.SlaMonitor::new("服务满意度(等待<5s)", 5.0)

  let mut customer_id = 1

  let steps : Array[(@event.ProcessContext) -> Double?] = [
    fn(ctx : @event.ProcessContext) -> Double? {
      if customer_id <= 8 {
        let cid = customer_id
        customer_id = customer_id + 1
        let arrival_time = ctx.clock.now_seconds()
        println(
          "[\{arrival_time}s] 顾客 #\{cid} 进入银行，当前窗口可用数: \{teller.available()}，排队人数: \{teller.queue_length()}",
        )

        queue_summary.update(
          arrival_time,
          Double::from_int(teller.queue_length()),
        )

        let _ = teller.request(1, 10, fn(ok : Bool) {
          if ok {
            let start_time = ctx.clock.now_seconds()
            let wait_time = start_time - arrival_time
            let _ = sla_monitor.record(wait_time)
            println(
              "[\{start_time}s] 顾客 #\{cid} 开始办理业务，已等待 \{wait_time}s",
            )

            let _ = sim.schedule(4.0, 10, fn() {
              let end_time = sim.now()
              teller.release(1)
              queue_summary.update(
                end_time,
                Double::from_int(teller.queue_length()),
              )
              println(
                "[\{end_time}s] 顾客 #\{cid} 业务完成离开，释放窗口。",
              )
            })
          }
        })
        queue_summary.update(
          arrival_time,
          Double::from_int(teller.queue_length()),
        )
        Some(1.5)
      } else {
        None
      }
    },
  ]

  let gen_id = sim.register_process("顾客生成器", steps)
  let _ = sim.start_process(gen_id, 0.0, 10)

  sim.run_until(30.0)

  println("\n==================================================")
  println("                  仿真统计报告                     ")
  println("==================================================")
  println("仿真总虚拟时间: \{sim.now()}s")
  println("时间加权平均排队人数: \{queue_summary.mean()}")
  println("排队人数峰值: \{queue_summary.max()}")
  println("业务处理总人次: \{sla_monitor.total()}")
  println("等待超时(>5s)人次: \{sla_monitor.violations()}")
  println("SLA达标率: \{(1.0 - sla_monitor.violation_rate()) * 100.0}%")
  println("==================================================\n")
}
