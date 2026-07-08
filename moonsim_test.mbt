///|
test "simulation_facade_integration" {
  let sim = Simulation::new()
  let teller = sim.create_resource("Teller", 1)
  let queue_len = sim.create_summary("QueueLen", 0.0)

  let mut customers_served = 0

  let _ = sim.schedule(1.0, 10, fn() {
    queue_len.update(sim.now(), Double::from_int(teller.queue_length()))
    let _ = teller.request(1, 10, fn(_ok) {
      customers_served = customers_served + 1
      let _ = sim.schedule(3.0, 10, fn() {
        teller.release(1)
        queue_len.update(sim.now(), Double::from_int(teller.queue_length()))
      })
    })
    queue_len.update(sim.now(), Double::from_int(teller.queue_length()))
  })

  let _ = sim.schedule(2.0, 10, fn() {
    queue_len.update(sim.now(), Double::from_int(teller.queue_length()))
    let _ = teller.request(1, 10, fn(_ok) {
      customers_served = customers_served + 1
      let _ = sim.schedule(2.0, 10, fn() {
        teller.release(1)
        queue_len.update(sim.now(), Double::from_int(teller.queue_length()))
      })
    })
    queue_len.update(sim.now(), Double::from_int(teller.queue_length()))
  })

  sim.run_until(10.0)
  assert_eq(customers_served, 2)
  assert_true(sim.now() >= 6.0)
}

///|
test "simulation_facade_schedule_at" {
  let sim = Simulation::new()
  let mut fired_at = 0.0

  // schedule_at absolute time t=5.0
  let _ = sim.schedule_at(5.0, 10, fn() { fired_at = sim.now() })
  sim.run_until(10.0)
  assert_eq(fired_at, 5.0)
}

///|
test "simulation_facade_sla_monitor_and_percentile" {
  let sim = Simulation::new()
  let sla = sim.create_sla_monitor("WebLatency", 100.0)
  let p99 = sim.create_percentile_tracker("Latencies")

  // Inject 100 samples: 1ms to 100ms
  for i = 1; i <= 100; i = i + 1 {
    let ms = Double::from_int(i)
    let _ = sla.record(ms)
    p99.record(ms)
  }

  // 1 violation (100ms exactly on threshold? no; only strictly >threshold)
  assert_eq(sla.total(), 100)
  assert_eq(sla.violations(), 0)
  assert_true(p99.p99() >= 99.0 && p99.p99() <= 100.0)
}

///|
test "simulation_facade_active_event_count" {
  let sim = Simulation::new()
  let _ = sim.schedule(1.0, 5, fn() {  })
  let _ = sim.schedule(2.0, 5, fn() {  })
  let _ = sim.schedule(3.0, 5, fn() {  })
  assert_eq(sim.active_event_count(), 3)

  sim.run_until(1.5)
  assert_eq(sim.active_event_count(), 2)
}
