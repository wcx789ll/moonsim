// Deterministic, repeatable workloads used for acceptance checks and
// regression tracking.  These are intentionally implemented on top of the
// public facade so that the examples exercise the same API as downstream
// users.

///|
pub(all) struct BenchmarkResult {
  name : String
  workload : Int
  completed : Int
  dropped : Int
  missed_deadline : Int
  virtual_seconds : Double
  mean_wait_seconds : Double
  p95_latency_ms : Double
}

///|
pub fn BenchmarkResult::success_rate(self : BenchmarkResult) -> Double {
  if self.workload <= 0 {
    0.0
  } else {
    Double::from_int(self.completed) / Double::from_int(self.workload)
  }
}

///|
pub fn BenchmarkResult::drop_rate(self : BenchmarkResult) -> Double {
  if self.workload <= 0 {
    0.0
  } else {
    Double::from_int(self.dropped) / Double::from_int(self.workload)
  }
}

///|
pub fn BenchmarkResult::summary(self : BenchmarkResult) -> String {
  "\{self.name}: workload=\{self.workload}, completed=\{self.completed}, " +
  "dropped=\{self.dropped}, deadline_miss=\{self.missed_deadline}, " +
  "virtual_seconds=\{self.virtual_seconds}, mean_wait_seconds=\{self.mean_wait_seconds}, " +
  "p95_latency_ms=\{self.p95_latency_ms}"
}

///|
fn safe_workload(value : Int) -> Int {
  if value < 0 {
    0
  } else {
    value
  }
}

///|
fn safe_drop_probability(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
/// Run a high-volume event dispatch workload.
///
/// Each event is scheduled at a deterministic offset.  The callback count
/// proves that the event manager both dispatches and removes every action.
pub fn run_event_benchmark(event_count : Int) -> BenchmarkResult {
  let workload = safe_workload(event_count)
  let sim = @moonsim.Simulation::new()
  let mut completed = 0
  for i = 0; i < workload; i = i + 1 {
    let delay = Double::from_int(i % 100) / 1000.0
    let _ = sim.schedule(delay, i % 7, fn() { completed = completed + 1 })
  }
  sim.run()
  {
    name: "event_dispatch",
    workload,
    completed,
    dropped: workload - completed,
    missed_deadline: 0,
    virtual_seconds: sim.now(),
    mean_wait_seconds: 0.0,
    p95_latency_ms: 0.0,
  }
}

///|
/// Run a deterministic packet workload with a configurable loss rate.
///
/// The LCG seed is fixed by the topology, making delivery counts suitable
/// for a regression test while still exercising real drop decisions.
pub fn run_network_benchmark(
  packet_count : Int,
  drop_probability : Double,
) -> BenchmarkResult {
  let workload = safe_workload(packet_count)
  let probability = safe_drop_probability(drop_probability)
  let sim = @moonsim.Simulation::new()
  let topo : @network.NetworkTopology[Int] = sim.create_network_topology(
    20260817,
  )
  topo.add_node(1)
  topo.add_node(2)
  topo.add_link(1, 2, 0.010, probability)
  let latency = @stats.PercentileTracker::new("network_latency_ms")
  let mut completed = 0
  for i = 0; i < workload; i = i + 1 {
    let sent_at = sim.now()
    let sent = topo.send_packet(1, 2, i, i % 3, fn(_packet) {
      completed = completed + 1
      latency.record((sim.now() - sent_at) * 1000.0)
    })
    if !sent {
      // A deterministic drop occurs before an event is scheduled.
      ()
    }
  }
  sim.run()
  {
    name: "network_delivery",
    workload,
    completed,
    dropped: workload - completed,
    missed_deadline: 0,
    virtual_seconds: sim.now(),
    mean_wait_seconds: 0.0,
    p95_latency_ms: latency.p95(),
  }
}

///|
/// Run a fixed executor pool with FIFO jobs and absolute deadlines.
///
/// Jobs arrive at time zero, so queueing pressure is controlled solely by
/// the executor count and service-time distribution.  This is useful for
/// comparing scheduling changes without depending on wall-clock timing.
pub fn run_scheduler_benchmark(
  job_count : Int,
  executor_count : Int,
) -> BenchmarkResult {
  let workload = safe_workload(job_count)
  let executors = if executor_count <= 0 { 1 } else { executor_count }
  let sim = @moonsim.Simulation::new()
  let scheduler = sim.create_scheduler(
    "acceptance_scheduler",
    executors,
    @scheduler.Fifo,
    fn(_job) {  },
    fn(_job) {  },
    fn(_job) {  },
    fn(_job) {  },
  )
  for i = 0; i < workload; i = i + 1 {
    let service = 0.01 + Double::from_int(i % 5) * 0.002
    let deadline = Some(0.03 + Double::from_int(i / executors) * 0.02)
    scheduler.submit(@scheduler.Job::new(i, 0.0, service, deadline, i % 4))
  }
  sim.run()
  {
    name: "deadline_scheduler",
    workload,
    completed: scheduler.total_completed(),
    dropped: scheduler.total_cancelled(),
    missed_deadline: scheduler.total_deadline_miss(),
    virtual_seconds: sim.now(),
    mean_wait_seconds: scheduler.mean_wait_time(),
    p95_latency_ms: 0.0,
  }
}

///|
/// Execute the standard acceptance workload set.
pub fn run_acceptance_suite() -> Array[BenchmarkResult] {
  [
    run_event_benchmark(10000),
    run_network_benchmark(2000, 0.05),
    run_scheduler_benchmark(1000, 8),
  ]
}

///|
/// Return true when a result is internally consistent.
pub fn BenchmarkResult::is_consistent(self : BenchmarkResult) -> Bool {
  self.workload >= 0 &&
  self.completed >= 0 &&
  self.dropped >= 0 &&
  self.missed_deadline >= 0 &&
  self.completed + self.dropped <= self.workload &&
  self.virtual_seconds >= 0.0 &&
  self.mean_wait_seconds >= 0.0 &&
  self.p95_latency_ms >= 0.0
}
