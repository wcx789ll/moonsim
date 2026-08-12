///|
fn main {
  println("MoonSim deterministic acceptance benchmark")
  println("workloads: event dispatch 10,000; network 2,000; scheduler 1,000")
  for result in @benchmarks.run_acceptance_suite() {
    println(result.summary())
  }
  let report = @benchmarks.run_acceptance_report()
  println("acceptance report: \{report.summary()}")
  println("ready: \{@benchmarks.acceptance_report_ready(report)}")
  println("quality gate: \{report.quality_gate()}")
}
