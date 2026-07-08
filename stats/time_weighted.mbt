///|
pub(all) struct TimeWeightedSummary {
  name : String
  mut last_time : Double
  mut last_value : Double
  mut time_weighted_sum : Double
  mut total_time : Double
  mut min_value : Double
  mut max_value : Double
}

///|
pub fn TimeWeightedSummary::new(
  name : String,
  initial_time : Double,
  initial_value : Double,
) -> TimeWeightedSummary {
  {
    name,
    last_time: initial_time,
    last_value: initial_value,
    time_weighted_sum: 0.0,
    total_time: 0.0,
    min_value: initial_value,
    max_value: initial_value,
  }
}

///|
pub fn TimeWeightedSummary::update(
  self : TimeWeightedSummary,
  current_time : Double,
  new_value : Double,
) -> Unit {
  if current_time < self.last_time {
    abort("TimeWeightedSummary update time cannot move backward")
  }
  let delta = current_time - self.last_time
  if delta > 0.0 {
    self.time_weighted_sum = self.time_weighted_sum + self.last_value * delta
    self.total_time = self.total_time + delta
  }
  self.last_time = current_time
  self.last_value = new_value
  if new_value < self.min_value {
    self.min_value = new_value
  }
  if new_value > self.max_value {
    self.max_value = new_value
  }
}

///|
pub fn TimeWeightedSummary::mean(self : TimeWeightedSummary) -> Double {
  if self.total_time == 0.0 {
    self.last_value
  } else {
    self.time_weighted_sum / self.total_time
  }
}

///|
pub fn TimeWeightedSummary::min(self : TimeWeightedSummary) -> Double {
  self.min_value
}

///|
pub fn TimeWeightedSummary::max(self : TimeWeightedSummary) -> Double {
  self.max_value
}

///|
pub fn TimeWeightedSummary::total_time(self : TimeWeightedSummary) -> Double {
  self.total_time
}
