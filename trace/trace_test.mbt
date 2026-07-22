// trace/trace_test.mbt

///|
test "tracer_basic_record_and_count" {
  let t = Tracer::new("sim-trace")
  assert_eq(t.stored_count(), 0)

  t.record_arrival(0.0, "Gateway", "customer #1 arrived")
  t.record_arrival(1.0, "Gateway", "customer #2 arrived")
  t.record_departure(2.5, "Teller", "customer #1 served", Some(2.5))
  assert_eq(t.stored_count(), 3)
  assert_eq(t.total_records(), 3)
}

///|
test "tracer_enable_disable" {
  let t = Tracer::new("trace")
  t.record_arrival(0.0, "src", "first")
  t.disable()
  t.record_arrival(1.0, "src", "should not be stored")
  // stored_count stays at 1 but total_records includes all calls
  assert_eq(t.stored_count(), 1)
  t.enable()
  t.record_arrival(2.0, "src", "third")
  assert_eq(t.stored_count(), 2)
}

///|
test "tracer_monotonic_valid" {
  let t = Tracer::new("trace")
  t.record(0.0, "a", Arrival, "m", None)
  t.record(1.0, "a", Departure, "m", None)
  t.record(1.0, "a", Annotation, "same-time", None) // same time is ok
  t.record(2.0, "b", StateChange, "m", None)
  assert_true(t.verify_monotonic())
}

///|
test "tracer_monotonic_invalid" {
  let t = Tracer::new("trace")
  t.record(5.0, "a", Arrival, "m", None)
  t.record(3.0, "b", Departure, "m", None) // time goes backward!
  assert_eq(t.verify_monotonic(), false)
}

///|
test "tracer_window_filter" {
  let t = Tracer::new("trace")
  t.record(0.0, "a", Arrival, "m0", None)
  t.record(2.0, "a", Arrival, "m2", None)
  t.record(5.0, "b", Arrival, "m5", None)
  t.record(8.0, "c", Arrival, "m8", None)

  let window = t.records_in_window(2.0, 6.0)
  assert_eq(window.length(), 2)
  assert_eq(window[0].message, "m2")
  assert_eq(window[1].message, "m5")
}

///|
test "tracer_category_filter" {
  let t = Tracer::new("trace")
  t.record(0.0, "a", Arrival, "arrived", None)
  t.record(1.0, "b", ResourceAcquire, "acquired", None)
  t.record(2.0, "c", Arrival, "arrived 2", None)
  t.record(3.0, "d", DeadlineMiss, "missed", None)

  let arrivals = t.records_by_category(Arrival)
  assert_eq(arrivals.length(), 2)

  let misses = t.records_by_category(DeadlineMiss)
  assert_eq(misses.length(), 1)
}

///|
test "tracer_source_filter" {
  let t = Tracer::new("trace")
  t.record(0.0, "NodeA", Arrival, "a1", None)
  t.record(1.0, "NodeB", Arrival, "b1", None)
  t.record(2.0, "NodeA", Departure, "a2", None)

  let node_a = t.records_by_source("NodeA")
  assert_eq(node_a.length(), 2)
  let node_b = t.records_by_source("NodeB")
  assert_eq(node_b.length(), 1)
}

///|
test "tracer_csv_format" {
  let t = Tracer::new("trace")
  t.record(0.5, "router", Arrival, "pkt#1", Some(64.0))
  let csv = t.to_csv()
  // Check header exists
  assert_true(csv.contains("time,source,category,message,value"))
  // Check record appears
  assert_true(csv.contains("0.5"))
  assert_true(csv.contains("router"))
  assert_true(csv.contains("pkt#1"))
  assert_true(csv.contains("64"))
}

///|
test "tracer_category_histogram" {
  let t = Tracer::new("trace")
  t.record(0.0, "a", Arrival, "m", None)
  t.record(1.0, "a", Arrival, "m", None)
  t.record(2.0, "b", Departure, "m", None)
  t.record(3.0, "c", FaultInjection, "m", None)

  let hist = t.category_histogram()
  // Should have 3 categories: Arrival(2), Departure(1), FaultInjection(1)
  assert_eq(hist.length(), 3)
  // Arrivals should be first and have count 2
  assert_eq(hist[0].0, "Arrival")
  assert_eq(hist[0].1, 2)
}

///|
test "tracer_state_change_message" {
  let t = Tracer::new("trace")
  t.record_state_change(1.5, "fsm", "Idle", "Running")
  assert_eq(t.stored_count(), 1)
  let records = t.records_by_category(StateChange)
  assert_true(records[0].message.contains("Idle"))
  assert_true(records[0].message.contains("Running"))
}

///|
test "tracer_clear" {
  let t = Tracer::new("trace")
  t.record(0.0, "x", Annotation, "before clear", None)
  t.record(1.0, "x", Annotation, "before clear 2", None)
  assert_eq(t.stored_count(), 2)
  t.clear()
  assert_eq(t.stored_count(), 0)
  // total_records still reflects the historical count
  assert_eq(t.total_records(), 2)
}
