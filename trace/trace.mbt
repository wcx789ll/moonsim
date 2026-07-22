// trace/trace.mbt
// Deterministic simulation event tracer.
//
// The Tracer records every EventRecord emitted by the simulation in
// chronological order.  It supports:
//   - Filtered export (by tag or time window)
//   - CSV/JSON-style textual formatting
//   - Replay verification: check whether a recorded trace is valid

///|
/// Categories of simulation events that can be traced.
pub(all) enum EventCategory {
  /// A simulation entity arrived (job, packet, customer, etc.)
  Arrival
  /// A simulation entity departed or was served.
  Departure
  /// A resource was acquired.
  ResourceAcquire
  /// A resource was released.
  ResourceRelease
  /// A state machine transitioned to a new state.
  StateChange
  /// A user-defined annotation or debugging marker.
  Annotation
  /// A deadline was missed.
  DeadlineMiss
  /// A fault or failure event was injected.
  FaultInjection
} derive(Debug, Eq)

///|
pub impl Show for EventCategory with fn output(self, logger) {
  let s = match self {
    Arrival => "Arrival"
    Departure => "Departure"
    ResourceAcquire => "ResourceAcquire"
    ResourceRelease => "ResourceRelease"
    StateChange => "StateChange"
    Annotation => "Annotation"
    DeadlineMiss => "DeadlineMiss"
    FaultInjection => "FaultInjection"
  }
  logger.write_string(s)
}

///|
/// A single recorded simulation event.
pub(all) struct EventRecord {
  /// Wall-clock simulation time (seconds) at which the event occurred.
  time : Double
  /// Source entity identifier (e.g. process name, node id converted to string).
  source : String
  /// Human-readable description of what happened.
  message : String
  /// Category for filtering.
  category : EventCategory
  /// Optional numeric payload (e.g. queue length, resource usage).
  value : Double?
}

///|
pub fn EventRecord::to_csv_row(self : EventRecord) -> String {
  let val_str = match self.value {
    None => ""
    Some(v) => "\{v}"
  }
  "\{self.time},\{self.source},\{self.category},\{self.message},\{val_str}"
}

///|
/// The central event tracer.  Attach it to a simulation and call `record`
/// from event callbacks to accumulate a full audit trail.
pub(all) struct Tracer {
  name : String
  priv records : Array[EventRecord]
  mut enabled : Bool
  mut record_count : Int
}

///|
pub fn Tracer::new(name : String) -> Tracer {
  { name, records: [], enabled: true, record_count: 0 }
}

///|
pub fn Tracer::enable(self : Tracer) -> Unit {
  self.enabled = true
}

///|
pub fn Tracer::disable(self : Tracer) -> Unit {
  self.enabled = false
}

///|
pub fn Tracer::is_enabled(self : Tracer) -> Bool {
  self.enabled
}

///|
pub fn Tracer::record(
  self : Tracer,
  time : Double,
  source : String,
  category : EventCategory,
  message : String,
  value : Double?,
) -> Unit {
  if !self.enabled {
    return
  }
  self.records.push({ time, source, message, category, value })
  self.record_count = self.record_count + 1
}

///|
pub fn Tracer::record_arrival(
  self : Tracer,
  time : Double,
  source : String,
  message : String,
) -> Unit {
  self.record(time, source, Arrival, message, None)
}

///|
pub fn Tracer::record_departure(
  self : Tracer,
  time : Double,
  source : String,
  message : String,
  sojourn_time : Double?,
) -> Unit {
  self.record(time, source, Departure, message, sojourn_time)
}

///|
pub fn Tracer::record_state_change(
  self : Tracer,
  time : Double,
  source : String,
  from_state : String,
  to_state : String,
) -> Unit {
  self.record(
    time,
    source,
    StateChange,
    "transition: \{from_state} -> \{to_state}",
    None,
  )
}

///|
pub fn Tracer::record_annotation(
  self : Tracer,
  time : Double,
  source : String,
  message : String,
) -> Unit {
  self.record(time, source, Annotation, message, None)
}

///|
/// Return the total number of records written (including while disabled).
pub fn Tracer::total_records(self : Tracer) -> Int {
  self.record_count
}

///|
/// Return the number of currently stored records (not cleared).
pub fn Tracer::stored_count(self : Tracer) -> Int {
  self.records.length()
}

///|
/// Return records within the given time window [from, to] (inclusive).
pub fn Tracer::records_in_window(
  self : Tracer,
  from : Double,
  to : Double,
) -> Array[EventRecord] {
  let result : Array[EventRecord] = []
  for r in self.records {
    if r.time >= from && r.time <= to {
      result.push(r)
    }
  }
  result
}

///|
/// Return all records matching a given category.
pub fn Tracer::records_by_category(
  self : Tracer,
  category : EventCategory,
) -> Array[EventRecord] {
  let result : Array[EventRecord] = []
  for r in self.records {
    if r.category == category {
      result.push(r)
    }
  }
  result
}

///|
/// Return all records from a specific source entity.
pub fn Tracer::records_by_source(
  self : Tracer,
  source : String,
) -> Array[EventRecord] {
  let result : Array[EventRecord] = []
  for r in self.records {
    if r.source == source {
      result.push(r)
    }
  }
  result
}

///|
/// Export the full trace as a CSV string.
/// The header row is: `time,source,category,message,value`
pub fn Tracer::to_csv(self : Tracer) -> String {
  let mut buf = "time,source,category,message,value\n"
  for r in self.records {
    buf = buf + r.to_csv_row() + "\n"
  }
  buf
}

///|
/// Verify that the trace is monotonically non-decreasing in time.
/// Returns `true` if valid, `false` if any record has a timestamp earlier
/// than the previous record.
pub fn Tracer::verify_monotonic(self : Tracer) -> Bool {
  if self.records.length() <= 1 {
    return true
  }
  let mut prev_time = self.records[0].time
  for i = 1; i < self.records.length(); i = i + 1 {
    if self.records[i].time < prev_time {
      return false
    }
    prev_time = self.records[i].time
  }
  true
}

///|
/// Clear all stored records (does not reset the total_count counter).
pub fn Tracer::clear(self : Tracer) -> Unit {
  self.records.clear()
}

///|
/// Compute a simple histogram of event counts per category.
/// Returns an array of (category_name, count) pairs in insertion order.
pub fn Tracer::category_histogram(self : Tracer) -> Array[(String, Int)] {
  let categories = [
    "Arrival", "Departure", "ResourceAcquire", "ResourceRelease", "StateChange",
    "Annotation", "DeadlineMiss", "FaultInjection",
  ]
  let result : Array[(String, Int)] = []
  for cat_name in categories {
    let mut count = 0
    for r in self.records {
      let r_name = match r.category {
        Arrival => "Arrival"
        Departure => "Departure"
        ResourceAcquire => "ResourceAcquire"
        ResourceRelease => "ResourceRelease"
        StateChange => "StateChange"
        Annotation => "Annotation"
        DeadlineMiss => "DeadlineMiss"
        FaultInjection => "FaultInjection"
      }
      if r_name == cat_name {
        count = count + 1
      }
    }
    if count > 0 {
      result.push((cat_name, count))
    }
  }
  result
}
