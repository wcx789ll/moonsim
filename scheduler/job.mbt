// scheduler/job.mbt
// Defines the Job abstraction: a unit of work with an arrival time, service
// time, deadline, and priority, together with its lifecycle status.

///|
/// Enumeration of all possible lifecycle states a Job can occupy.
pub(all) enum JobStatus {
  /// Waiting in a queue for a free executor slot.
  Queued
  /// Currently being executed by an executor.
  Running
  /// Finished execution successfully before its deadline.
  Completed
  /// Execution was cancelled before it could finish.
  Cancelled
  /// The job exceeded its deadline and was forcibly evicted.
  DeadlineMissed
} derive(Debug, Eq)

///|
pub impl Show for JobStatus with fn output(self, logger) {
  let s = match self {
    Queued => "Queued"
    Running => "Running"
    Completed => "Completed"
    Cancelled => "Cancelled"
    DeadlineMissed => "DeadlineMissed"
  }
  logger.write_string(s)
}

///|
/// A schedulable unit of work.
///
/// Each Job carries:
/// - `id`: globally unique integer identifier.
/// - `arrival_time`: the simulation time (seconds) when the job entered the system.
/// - `service_time`: the duration (seconds) the job requires on an executor.
/// - `deadline`: optional absolute time limit (seconds); `None` means no deadline.
/// - `priority`: scheduling priority �?lower values are processed first.
/// - `status`: mutable lifecycle state.
/// - `start_time`: set when execution begins.
/// - `finish_time`: set when execution completes or is aborted.
pub(all) struct Job {
  id : Int
  arrival_time : Double
  service_time : Double
  deadline : Double?
  priority : Int
  mut status : JobStatus
  mut start_time : Double?
  mut finish_time : Double?
}

///|
pub fn Job::new(
  id : Int,
  arrival_time : Double,
  service_time : Double,
  deadline : Double?,
  priority : Int,
) -> Job {
  if service_time <= 0.0 {
    abort("Job service_time must be positive")
  }
  {
    id,
    arrival_time,
    service_time,
    deadline,
    priority,
    status: Queued,
    start_time: None,
    finish_time: None,
  }
}

///|
/// Returns the wall-clock waiting time: time from arrival until the job
/// started running. Returns `None` if the job has not yet started.
pub fn Job::wait_time(self : Job) -> Double? {
  match self.start_time {
    None => None
    Some(s) => Some(s - self.arrival_time)
  }
}

///|
/// Returns the total sojourn time: time from arrival until the job finished.
/// Returns `None` if the job has not yet finished.
pub fn Job::sojourn_time(self : Job) -> Double? {
  match self.finish_time {
    None => None
    Some(f) => Some(f - self.arrival_time)
  }
}

///|
/// Returns `true` if this job has missed its deadline.
/// A job misses its deadline when its `finish_time` (or the current time,
/// if still running) exceeds `deadline`.
pub fn Job::has_missed_deadline(self : Job, now : Double) -> Bool {
  match self.deadline {
    None => false
    Some(dl) =>
      match self.finish_time {
        Some(f) => f > dl
        None => now > dl
      }
  }
}
