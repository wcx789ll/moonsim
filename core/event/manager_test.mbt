///|
test "event_manager_actions_and_process" {
  let clock = @clock.Clock::new()
  let mgr = EventManager::new(clock)
  let mut counter = 0

  let _ = mgr.schedule_action(5.0, PRIORITY_NORMAL, fn() {
    counter = counter + 10
  })

  let steps = [
    fn(_ctx : ProcessContext) -> Double? {
      counter = counter + 1
      Some(3.0) // wait 3 seconds
    },
    fn(_ctx : ProcessContext) -> Double? {
      counter = counter + 2
      Some(2.0) // wait 2 seconds
    },
    fn(_ctx : ProcessContext) -> Double? {
      counter = counter + 5
      None // terminate process
    },
  ]

  let proc_id = mgr.register_process("TestCoroutine", steps)
  let _ = mgr.start_process(proc_id, 1.0, PRIORITY_NORMAL)

  // Run all events
  mgr.run()

  // t=1.0: step 0 runs (+1) -> schedules step 1 at t=4.0
  // t=4.0: step 1 runs (+2) -> schedules step 2 at t=6.0
  // t=5.0: action runs (+10)
  // t=6.0: step 2 runs (+5) -> process terminates
  // Total counter = 1 + 2 + 10 + 5 = 18
  assert_eq(counter, 18)
  assert_eq(clock.now_seconds(), 6.0)
  assert_eq(mgr.get_process_status(proc_id).unwrap(), Terminated)
}
