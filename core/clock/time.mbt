///|
pub(all) struct SimTime {
  val : Double
} derive(Debug, Eq)

///|
pub fn SimTime::zero() -> SimTime {
  { val: 0.0 }
}

///|
pub fn SimTime::from_seconds(sec : Double) -> SimTime {
  if sec < 0.0 {
    abort("SimTime cannot be negative")
  }
  { val: sec }
}

///|
pub fn SimTime::to_seconds(self : SimTime) -> Double {
  self.val
}

///|
pub fn SimTime::op_add(self : SimTime, delta : Double) -> SimTime {
  if delta < 0.0 {
    abort("Cannot add negative time delta to SimTime")
  }
  { val: self.val + delta }
}

///|
pub fn SimTime::compare(self : SimTime, other : SimTime) -> Int {
  if self.val < other.val {
    -1
  } else if self.val > other.val {
    1
  } else {
    0
  }
}

///|
pub(all) struct EventId {
  seq : Int64
} derive(Debug, Eq)

///|
pub fn EventId::compare(self : EventId, other : EventId) -> Int {
  if self.seq < other.seq {
    -1
  } else if self.seq > other.seq {
    1
  } else {
    0
  }
}
