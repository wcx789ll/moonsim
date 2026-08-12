///|
test "benchmark workloads are deterministic and consistent" {
  let event_a = run_event_benchmark(1000)
  let event_b = run_event_benchmark(1000)
  assert_true(event_a.is_consistent())
  assert_true(event_b.is_consistent())
  assert_eq(event_a.completed, 1000)
  assert_eq(event_a.completed, event_b.completed)
  assert_eq(event_a.virtual_seconds, event_b.virtual_seconds)

  let network = run_network_benchmark(500, 0.0)
  assert_true(network.is_consistent())
  assert_eq(network.completed, 500)
  assert_eq(network.dropped, 0)
  assert_eq(network.p95_latency_ms, 10.0)

  let scheduled = run_scheduler_benchmark(100, 4)
  assert_true(scheduled.is_consistent())
  assert_eq(scheduled.completed + scheduled.missed_deadline, 100)
}

///|
test "benchmark input boundaries are safe" {
  let empty_events = run_event_benchmark(-1)
  assert_eq(empty_events.workload, 0)
  assert_eq(empty_events.completed, 0)
  assert_eq(empty_events.success_rate(), 0.0)

  let clamped_network = run_network_benchmark(20, 2.0)
  assert_true(clamped_network.is_consistent())
  assert_eq(clamped_network.completed, 0)
  assert_eq(clamped_network.dropped, 20)

  let fallback_scheduler = run_scheduler_benchmark(8, 0)
  assert_true(fallback_scheduler.is_consistent())
  assert_eq(fallback_scheduler.workload, 8)
}

///|
test "acceptance suite has three production scenarios" {
  let results = run_acceptance_suite()
  assert_eq(results.length(), 3)
  for result in results {
    assert_true(result.is_consistent())
    assert_true(result.summary().length() > 20)
  }
}

///|
test "acceptance report aggregates and compares runs" {
  let baseline = run_acceptance_report()
  let candidate = run_acceptance_report()
  assert_true(acceptance_report_ready(baseline))
  assert_true(baseline.quality_gate())
  assert_true(baseline.completed_or_accounted())
  assert_true(baseline.has_no_negative_metrics())
  assert_true(baseline.has_complete_accounting())
  assert_eq(baseline.scenario_names().length(), 3)
  assert_eq(baseline.total_failures(), 108)
  assert_true(baseline.failure_rate() >= 0.0)
  assert_true(baseline.is_reproducible_with(candidate))
  assert_eq(baseline.scenario_count(), 3)
  assert_true(baseline.total_workload > 0)
  assert_true(baseline.overall_success_rate() > 0.0)
  assert_true(baseline.overall_loss_rate() >= 0.0)
  assert_true(baseline.result("network_delivery") is Some(_))
  assert_true(baseline.result("missing") is None)
  assert_true(compare_reports(baseline, candidate).length() > 50)
  assert_eq(baseline.summary(), candidate.summary())
}
