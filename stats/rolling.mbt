///|
pub(all) struct TimePoint {
  time : Double
  value : Double
}

///|
pub(all) struct RollingSummary {
  name : String
  window_size : Double
  priv points : Array[TimePoint]
}

///|
pub fn RollingSummary::new(
  name : String,
  window_size : Double,
) -> RollingSummary {
  if window_size <= 0.0 {
    abort("RollingSummary window_size must be positive")
  }
  { name, window_size, points: [] }
}

///|
pub fn RollingSummary::record(
  self : RollingSummary,
  time : Double,
  value : Double,
) -> Unit {
  self.points.push({ time, value })
}

///|
pub fn RollingSummary::rolling_mean(
  self : RollingSummary,
  now : Double,
) -> Double {
  if self.points.is_empty() {
    return 0.0
  }
  let cutoff = now - self.window_size
  let mut sum = 0.0
  let mut total_t = 0.0
  let mut prev_t = cutoff
  let mut prev_val = self.points[0].value

  for i = 0; i < self.points.length(); i = i + 1 {
    let pt = self.points[i]
    if pt.time <= cutoff {
      prev_val = pt.value
      prev_t = cutoff
    } else {
      let dt = pt.time - prev_t
      if dt > 0.0 {
        sum = sum + prev_val * dt
        total_t = total_t + dt
      }
      prev_t = pt.time
      prev_val = pt.value
    }
  }

  let dt_end = now - prev_t
  if dt_end > 0.0 {
    sum = sum + prev_val * dt_end
    total_t = total_t + dt_end
  }

  if total_t <= 0.0 {
    prev_val
  } else {
    sum / total_t
  }
}

///|
pub(all) struct PercentileTracker {
  name : String
  priv samples : Array[Double]
}

///|
pub fn PercentileTracker::new(name : String) -> PercentileTracker {
  { name, samples: [] }
}

///|
pub fn PercentileTracker::record(
  self : PercentileTracker,
  value : Double,
) -> Unit {
  self.samples.push(value)
}

///|
pub fn PercentileTracker::count(self : PercentileTracker) -> Int {
  self.samples.length()
}

///|
pub fn PercentileTracker::percentile(
  self : PercentileTracker,
  p : Double,
) -> Double {
  if self.samples.is_empty() {
    return 0.0
  }
  if p <= 0.0 {
    return self.samples[0]
  }
  let n = self.samples.length()
  // Create sorted copy
  let sorted : Array[Double] = []
  for s in self.samples {
    sorted.push(s)
  }
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      if sorted[j] < sorted[i] {
        let tmp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = tmp
      }
    }
  }
  let rank = p / 100.0 * Double::from_int(n - 1)
  let idx = rank.to_int()
  if idx >= n - 1 {
    sorted[n - 1]
  } else {
    let frac = rank - Double::from_int(idx)
    sorted[idx] + frac * (sorted[idx + 1] - sorted[idx])
  }
}

///|
pub fn PercentileTracker::p50(self : PercentileTracker) -> Double {
  self.percentile(50.0)
}

///|
pub fn PercentileTracker::p90(self : PercentileTracker) -> Double {
  self.percentile(90.0)
}

///|
pub fn PercentileTracker::p95(self : PercentileTracker) -> Double {
  self.percentile(95.0)
}

///|
pub fn PercentileTracker::p99(self : PercentileTracker) -> Double {
  self.percentile(99.0)
}
