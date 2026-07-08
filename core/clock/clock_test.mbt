///|
test "clock_deterministic_ordering" {
  let clock = Clock::new()
  let id1 = clock.schedule(10.0, 5, 101)
  let _ = clock.schedule(5.0, 0, 102)
  let _ = clock.schedule(10.0, 1, 103)
  let id4 = clock.schedule(10.0, 5, 104)

  let ev1 = clock.next_event().unwrap()
  assert_eq(ev1.payload_id, 102)
  assert_eq(clock.now_seconds(), 5.0)

  let ev2 = clock.next_event().unwrap()
  assert_eq(ev2.payload_id, 103)
  assert_eq(clock.now_seconds(), 10.0)

  let ev3 = clock.next_event().unwrap()
  assert_eq(ev3.payload_id, 101)
  assert_eq(ev3.id.seq, id1.seq)

  let ev4 = clock.next_event().unwrap()
  assert_eq(ev4.payload_id, 104)
  assert_eq(ev4.id.seq, id4.seq)

  assert_true(clock.next_event() is None)
}

///|
test "clock_cancellation" {
  let clock = Clock::new()
  let _ = clock.schedule(2.0, 0, 1)
  let id_to_cancel = clock.schedule(3.0, 0, 2)
  let _ = clock.schedule(4.0, 0, 3)

  let cancelled = clock.cancel(id_to_cancel)
  assert_true(cancelled)

  let ev1 = clock.next_event().unwrap()
  assert_eq(ev1.payload_id, 1)

  let ev2 = clock.next_event().unwrap()
  assert_eq(ev2.payload_id, 3)
  assert_eq(clock.now_seconds(), 4.0)
}
