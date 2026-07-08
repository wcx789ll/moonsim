///|
pub(all) enum ClockStatus {
  Idle
  Running
  Paused
  Completed
} derive(Debug, Eq)

///|
pub(all) struct Clock {
  mut time : SimTime
  mut next_seq : Int64
  heap : EventHeap
  mut status : ClockStatus
  mut target_time : Double?
} derive(Debug)

///|
pub fn Clock::new() -> Clock {
  {
    time: SimTime::zero(),
    next_seq: 1L,
    heap: EventHeap::new(),
    status: Idle,
    target_time: None,
  }
}

///|
pub fn Clock::now(self : Clock) -> SimTime {
  self.time
}

///|
pub fn Clock::now_seconds(self : Clock) -> Double {
  self.time.to_seconds()
}

///|
pub fn Clock::status(self : Clock) -> ClockStatus {
  self.status
}

///|
pub fn Clock::reset(self : Clock) -> Unit {
  self.time = SimTime::zero()
  self.next_seq = 1L
  self.heap.clear()
  self.status = Idle
  self.target_time = None
}

///|
fn Clock::generate_id(self : Clock) -> EventId {
  let id = { seq: self.next_seq }
  self.next_seq = self.next_seq + 1L
  id
}

///|
pub fn Clock::schedule_at(
  self : Clock,
  target : SimTime,
  priority : Int,
  payload_id : Int
) -> EventId {
  if target.val < self.time.val {
    abort("Cannot schedule event in the past")
  }
  let id = self.generate_id()
  let ev = { time: target, priority, id, cancelled: false, payload_id }
  self.heap.push(ev)
  id
}

///|
pub fn Clock::schedule(
  self : Clock,
  delta_seconds : Double,
  priority : Int,
  payload_id : Int
) -> EventId {
  let target = self.time.op_add(delta_seconds)
  self.schedule_at(target, priority, payload_id)
}

///|
pub fn Clock::cancel(self : Clock, id : EventId) -> Bool {
  self.heap.cancel_by_id(id)
}

///|
pub fn Clock::filter_events(
  self : Clock,
  predicate : (PriorityEvent) -> Bool
) -> Int {
  self.heap.filter_events(predicate)
}

///|
pub fn Clock::active_count(self : Clock) -> Int {
  self.heap.active_count()
}

///|
pub fn Clock::get_event(self : Clock, id : EventId) -> PriorityEvent? {
  self.heap.get_event_by_id(id)
}

///|
pub fn Clock::next_event(self : Clock) -> PriorityEvent? {
  while true {
    match self.heap.pop() {
      None => return None
      Some(ev) => {
        if ev.cancelled {
          continue
        }
        match self.target_time {
          Some(limit) =>
            if ev.time.val > limit {
              self.heap.push(ev)
              return None
            }
          None => ()
        }
        self.time = ev.time
        return Some(ev)
      }
    }
  }
  None
}

///|
pub fn Clock::set_target_time(self : Clock, limit_seconds : Double?) -> Unit {
  self.target_time = limit_seconds
}
