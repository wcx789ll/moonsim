///|
/// A compact report assembled from deterministic benchmark results.
/// Keeping this logic in the library makes CI and downstream tooling use the
/// same acceptance criteria as the command-line example.
pub(all) struct BenchmarkReport {
  results : Array[BenchmarkResult]
  mut valid : Bool
  mut total_workload : Int
  mut total_completed : Int
  mut total_dropped : Int
  mut total_deadline_miss : Int
  mut max_virtual_seconds : Double
}

///|
pub fn BenchmarkReport::new(
  results : Array[BenchmarkResult],
) -> BenchmarkReport {
  let report = {
    results,
    valid: true,
    total_workload: 0,
    total_completed: 0,
    total_dropped: 0,
    total_deadline_miss: 0,
    max_virtual_seconds: 0.0,
  }
  report.recalculate()
  report
}

///|
pub fn BenchmarkReport::recalculate(self : BenchmarkReport) -> Unit {
  self.valid = true
  self.total_workload = 0
  self.total_completed = 0
  self.total_dropped = 0
  self.total_deadline_miss = 0
  self.max_virtual_seconds = 0.0
  for result in self.results {
    self.total_workload = self.total_workload + result.workload
    self.total_completed = self.total_completed + result.completed
    self.total_dropped = self.total_dropped + result.dropped
    self.total_deadline_miss = self.total_deadline_miss + result.missed_deadline
    if result.virtual_seconds > self.max_virtual_seconds {
      self.max_virtual_seconds = result.virtual_seconds
    }
    if !result.is_consistent() {
      self.valid = false
    }
  }
}

///|
pub fn BenchmarkReport::is_valid(self : BenchmarkReport) -> Bool {
  self.valid
}

///|
pub fn BenchmarkReport::scenario_count(self : BenchmarkReport) -> Int {
  self.results.length()
}

///|
pub fn BenchmarkReport::overall_success_rate(self : BenchmarkReport) -> Double {
  if self.total_workload <= 0 {
    0.0
  } else {
    Double::from_int(self.total_completed) /
    Double::from_int(self.total_workload)
  }
}

///|
pub fn BenchmarkReport::overall_loss_rate(self : BenchmarkReport) -> Double {
  if self.total_workload <= 0 {
    0.0
  } else {
    Double::from_int(self.total_dropped) / Double::from_int(self.total_workload)
  }
}

///|
pub fn BenchmarkReport::result(
  self : BenchmarkReport,
  name : String,
) -> BenchmarkResult? {
  for result in self.results {
    if result.name == name {
      return Some(result)
    }
  }
  None
}

///|
pub fn BenchmarkReport::has_scenario(
  self : BenchmarkReport,
  name : String,
) -> Bool {
  self.result(name) is Some(_)
}

///|
pub fn BenchmarkReport::all_results_consistent(self : BenchmarkReport) -> Bool {
  for result in self.results {
    if !result.is_consistent() {
      return false
    }
  }
  true
}

///|
pub fn BenchmarkReport::completed_or_accounted(self : BenchmarkReport) -> Bool {
  self.total_completed + self.total_dropped + self.total_deadline_miss <=
  self.total_workload
}

///|
pub fn BenchmarkReport::has_no_negative_metrics(self : BenchmarkReport) -> Bool {
  self.total_workload >= 0 &&
  self.total_completed >= 0 &&
  self.total_dropped >= 0 &&
  self.total_deadline_miss >= 0 &&
  self.max_virtual_seconds >= 0.0
}

///|
pub fn BenchmarkReport::quality_gate(self : BenchmarkReport) -> Bool {
  self.is_valid() &&
  self.completed_or_accounted() &&
  self.has_no_negative_metrics() &&
  self.scenario_count() >= 3
}

///|
pub fn BenchmarkReport::scenario_names(self : BenchmarkReport) -> Array[String] {
  let names = []
  for result in self.results {
    names.push(result.name)
  }
  names
}

///|
pub fn BenchmarkReport::has_complete_accounting(self : BenchmarkReport) -> Bool {
  self.completed_or_accounted() &&
  self.total_completed + self.total_dropped + self.total_deadline_miss >=
  self.total_workload
}

///|
pub fn BenchmarkReport::total_failures(self : BenchmarkReport) -> Int {
  self.total_dropped + self.total_deadline_miss
}

///|
pub fn BenchmarkReport::failure_rate(self : BenchmarkReport) -> Double {
  if self.total_workload <= 0 {
    0.0
  } else {
    Double::from_int(self.total_failures()) /
    Double::from_int(self.total_workload)
  }
}

///|
pub fn BenchmarkReport::is_reproducible_with(
  self : BenchmarkReport,
  other : BenchmarkReport,
) -> Bool {
  self.summary() == other.summary()
}

///|
pub fn BenchmarkReport::summary(self : BenchmarkReport) -> String {
  "scenarios=\{self.scenario_count()}, workload=\{self.total_workload}, " +
  "completed=\{self.total_completed}, dropped=\{self.total_dropped}, " +
  "deadline_miss=\{self.total_deadline_miss}, success_rate=\{self.overall_success_rate()}, " +
  "loss_rate=\{self.overall_loss_rate()}, max_virtual_seconds=\{self.max_virtual_seconds}, " +
  "valid=\{self.valid}"
}

///|
/// Build the canonical report used by acceptance tooling.
pub fn run_acceptance_report() -> BenchmarkReport {
  BenchmarkReport::new(run_acceptance_suite())
}

///|
/// Verify that the canonical suite contains the expected production paths.
pub fn acceptance_report_ready(report : BenchmarkReport) -> Bool {
  report.is_valid() &&
  report.all_results_consistent() &&
  report.has_scenario("event_dispatch") &&
  report.has_scenario("network_delivery") &&
  report.has_scenario("deadline_scheduler") &&
  report.total_workload > 0
}

///|
/// Return a human-readable delta between two runs.
pub fn compare_reports(
  baseline : BenchmarkReport,
  candidate : BenchmarkReport,
) -> String {
  let workload_delta = candidate.total_workload - baseline.total_workload
  let completed_delta = candidate.total_completed - baseline.total_completed
  let dropped_delta = candidate.total_dropped - baseline.total_dropped
  let deadline_delta = candidate.total_deadline_miss -
    baseline.total_deadline_miss
  "workload_delta=\{workload_delta}, completed_delta=\{completed_delta}, " +
  "dropped_delta=\{dropped_delta}, deadline_miss_delta=\{deadline_delta}, " +
  "success_rate_delta=\{candidate.overall_success_rate() - baseline.overall_success_rate()}, " +
  "virtual_time_delta=\{candidate.max_virtual_seconds - baseline.max_virtual_seconds}"
}
