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

///|
test "clock_filter_and_active_count" {
  let clock = Clock::new()
  let _ = clock.schedule(1.0, 10, 201)
  let _ = clock.schedule(2.0, 5, 202)
  let _ = clock.schedule(3.0, 10, 203)
  let _ = clock.schedule(4.0, 1, 204)

  assert_eq(clock.active_count(), 4)

  // Filter out all events with priority >= 10
  let removed = clock.filter_events(fn(ev) { ev.priority >= 10 })
  assert_eq(removed, 2)
  assert_eq(clock.active_count(), 2)

  let ev1 = clock.next_event().unwrap()
  assert_eq(ev1.payload_id, 202)
  assert_eq(clock.now_seconds(), 2.0)

  let ev2 = clock.next_event().unwrap()
  assert_eq(ev2.payload_id, 204)
  assert_eq(clock.now_seconds(), 4.0)

  assert_true(clock.next_event() is None)
}

///|
test "clock_get_event_by_id" {
  let clock = Clock::new()
  let id1 = clock.schedule(5.0, 0, 301)
  let _ = clock.schedule(10.0, 0, 302)

  match clock.get_event(id1) {
    Some(ev) => {
      assert_eq(ev.payload_id, 301)
      assert_eq(ev.time.to_seconds(), 5.0)
    }
    None => abort("Event should be found by ID")
  }
}
