///|
test "stats_time_weighted" {
  let summary = TimeWeightedSummary::new("QueueLength", 0.0, 10.0)
  // Queue stays at length 10 from t=0.0 to t=99.0 (99 seconds)
  summary.update(99.0, 0.0)
  // Queue stays at length 0 from t=99.0 to t=100.0 (1 second)
  summary.update(100.0, 0.0)

  // Weighted average = (10.0 * 99.0 + 0.0 * 1.0) / 100.0 = 9.9
  assert_eq(summary.mean(), 9.9)
  assert_eq(summary.total_time(), 100.0)
  assert_eq(summary.max(), 10.0)
  assert_eq(summary.min(), 0.0)
}

///|
test "stats_monitor_histogram_and_sla" {
  let hist = Histogram::new("ResponseTime", 10, 0.0, 100.0)
  hist.add(15.0)
  hist.add(25.0)
  hist.add(85.0)
  assert_eq(hist.count(), 3)
  assert_true(hist.mean() > 41.0 && hist.mean() < 42.0)

  let tracker = ThroughputTracker::new("Requests", 0.0)
  tracker.record(10.0, 50)
  assert_eq(tracker.rate(), 5.0)

  let sla = SlaMonitor::new("LatencySLA", 50.0)
  let _ = sla.record(30.0)
  let _ = sla.record(60.0)
  let _ = sla.record(80.0)
  assert_eq(sla.total(), 3)
  assert_eq(sla.violations(), 2)
  // 2 out of 3 = 0.6666...
  assert_true(sla.violation_rate() > 0.666 && sla.violation_rate() < 0.667)
}
