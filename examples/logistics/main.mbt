///|
fn main {
  println("==================================================")
  println(
    "   MoonSim 供应链与物流仓储仿真示例：智能自动化产线   ",
  )
  println("==================================================")

  let sim = @moonsim.Simulation::new()
  let buffer : @resource.Store[String] = @resource.Store::new("原料仓区", 5)
  let robot = sim.create_resource("组装机械臂", 1)
  let battery = @resource.Container::new("蓄电池能量池", 100.0, 100.0)

  let mut produced_count = 0
  let mut batch_id = 1

  // 1. Raw material supplier coroutine
  let supplier_steps : Array[(@event.ProcessContext) -> Double?] = [
    fn(ctx) {
      if batch_id <= 6 {
        let mat_name = "零件包-Batch#\{batch_id}"
        batch_id = batch_id + 1
        println(
          "[\{ctx.clock.now_seconds()}s] [供应商] 送达新原料: \{mat_name}，放入原料缓冲区",
        )
        buffer.put(mat_name, fn() {
          println(
            "[\{sim.now()}s] [缓冲区] \{mat_name} 成功入库，当前库内容量: \{buffer.size()}/\{buffer.capacity()}",
          )
        })
        Some(1.8) // New batch arrives every 1.8s
      } else {
        None
      }
    },
  ]
  let _ = sim.start_process(
    sim.register_process("供应商生成器", supplier_steps),
    0.0,
    10,
  )

  // 2. Robot assembly worker coroutine
  let robot_steps : Array[(@event.ProcessContext) -> Double?] = [
    fn(ctx) {
      if produced_count < 6 {
        println(
          "[\{ctx.clock.now_seconds()}s] [机械臂] 准备从原料仓抓取零件...",
        )
        buffer.get(fn(mat : String) {
          println(
            "[\{sim.now()}s] [机械臂] 抓取到原料: \{mat}，请求耗能与工位...",
          )
          let _ = robot.request(1, 10, fn(_ok) {
            battery.get(15.0, fn(_ok2) {
              println(
                "[\{sim.now()}s] [组装工位] 开始加工 \{mat}，消耗能量 15.0，剩余电量: \{battery.level()}/100.0",
              )
              let _ = sim.schedule(2.5, 10, fn() {
                produced_count = produced_count + 1
                robot.release(1)
                println(
                  "[\{sim.now()}s] [组装工位] 成品 #\{produced_count} 制造完工出库！释放工位机械臂。",
                )
              })
            })
          })
        })
        Some(3.0) // Next assembly attempt after cycle
      } else {
        None
      }
    },
  ]
  let _ = sim.start_process(
    sim.register_process("机械臂主控室", robot_steps),
    0.5,
    10,
  )

  // 3. Battery recharge monitor coroutine
  let recharge_steps : Array[(@event.ProcessContext) -> Double?] = [
    fn(ctx) {
      if battery.level() < 40.0 {
        println(
          "[\{ctx.clock.now_seconds()}s] [能源中心] 蓄电池电量偏低(\{battery.level()})，启动快充网格化回充...",
        )
        battery.put(50.0, fn(_ok) {
          println(
            "[\{sim.now()}s] [能源中心] 回充完成 +50.0！当前电池电量: \{battery.level()}/100.0",
          )
        })
      }
      Some(2.0) // Check battery level every 2 seconds
    },
  ]
  let _ = sim.start_process(
    sim.register_process("能源调度中心", recharge_steps),
    1.0,
    10,
  )

  sim.run_until(25.0)

  println("\n==================================================")
  println("                 自动化制造运行报告                 ")
  println("==================================================")
  println("仿真总运行虚拟耗时: \{sim.now()}s")
  println("成功组装并交付下线成品: \{produced_count} 件")
  println("原料仓期末剩余数: \{buffer.size()} / \{buffer.capacity()}")
  println(
    "蓄电池末期电量水平: \{battery.level()} / \{battery.capacity()}",
  )
  println("==================================================\n")
}
