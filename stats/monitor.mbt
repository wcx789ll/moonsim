///|
pub(all) struct Histogram {
  name : String
  mut count : Int
  mut sum : Double
  mut min_val : Double
  mut max_val : Double
  priv bins : Array[Int]
  bin_width : Double
  min_bin : Double
}

///|
pub fn Histogram::new(
  name : String,
  num_bins : Int,
  min_bin : Double,
  max_bin : Double,
) -> Histogram {
  if num_bins <= 0 || max_bin <= min_bin {
    abort("Invalid Histogram bin parameters")
  }
  let bins = []
  for i = 0; i < num_bins + 2; i = i + 1 {
    bins.push(0)
  }
  let bin_width = (max_bin - min_bin) / Double::from_int(num_bins)
  {
    name,
    count: 0,
    sum: 0.0,
    min_val: 1.0e300,
    max_val: -1.0e300,
    bins,
    bin_width,
    min_bin,
  }
}

///|
pub fn Histogram::add(self : Histogram, value : Double) -> Unit {
  self.count = self.count + 1
  self.sum = self.sum + value
  if value < self.min_val {
    self.min_val = value
  }
  if value > self.max_val {
    self.max_val = value
  }
  if value < self.min_bin {
    self.bins[0] = self.bins[0] + 1
  } else {
    let num_bins = self.bins.length() - 2
    let idx = ((value - self.min_bin) / self.bin_width).to_int()
    if idx >= num_bins {
      self.bins[num_bins + 1] = self.bins[num_bins + 1] + 1
    } else {
      self.bins[idx + 1] = self.bins[idx + 1] + 1
    }
  }
}

///|
pub fn Histogram::mean(self : Histogram) -> Double {
  if self.count == 0 {
    0.0
  } else {
    self.sum / Double::from_int(self.count)
  }
}

///|
pub fn Histogram::count(self : Histogram) -> Int {
  self.count
}

///|
pub(all) struct ThroughputTracker {
  name : String
  mut count : Int
  mut start_time : Double
  mut last_time : Double
}

///|
pub fn ThroughputTracker::new(
  name : String,
  start_time : Double,
) -> ThroughputTracker {
  { name, count: 0, start_time, last_time: start_time }
}

///|
pub fn ThroughputTracker::record(
  self : ThroughputTracker,
  time : Double,
  count_delta : Int,
) -> Unit {
  if time < self.last_time {
    abort("ThroughputTracker time cannot move backward")
  }
  self.count = self.count + count_delta
  self.last_time = time
}

///|
pub fn ThroughputTracker::rate(self : ThroughputTracker) -> Double {
  let elapsed = self.last_time - self.start_time
  if elapsed <= 0.0 {
    0.0
  } else {
    Double::from_int(self.count) / elapsed
  }
}

///|
pub(all) struct SlaMonitor {
  name : String
  threshold : Double
  mut total : Int
  mut violations : Int
}

///|
pub fn SlaMonitor::new(name : String, threshold : Double) -> SlaMonitor {
  { name, threshold, total: 0, violations: 0 }
}

///|
pub fn SlaMonitor::record(self : SlaMonitor, wait_time : Double) -> Bool {
  self.total = self.total + 1
  let violated = wait_time > self.threshold
  if violated {
    self.violations = self.violations + 1
  }
  violated
}

///|
pub fn SlaMonitor::violation_rate(self : SlaMonitor) -> Double {
  if self.total == 0 {
    0.0
  } else {
    Double::from_int(self.violations) / Double::from_int(self.total)
  }
}

///|
pub fn SlaMonitor::violations(self : SlaMonitor) -> Int {
  self.violations
}

///|
pub fn SlaMonitor::total(self : SlaMonitor) -> Int {
  self.total
}
