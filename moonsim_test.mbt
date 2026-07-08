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
