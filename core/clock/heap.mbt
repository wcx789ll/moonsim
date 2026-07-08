///|
pub(all) struct PriorityEvent {
  time : SimTime
  priority : Int
  id : EventId
  mut cancelled : Bool
  payload_id : Int
} derive(Debug)

///|
pub fn PriorityEvent::compare(
  self : PriorityEvent,
  other : PriorityEvent
) -> Int {
  let time_cmp = self.time.compare(other.time)
  if time_cmp != 0 {
    time_cmp
  } else {
    let prio_cmp = if self.priority < other.priority {
      -1
    } else if self.priority > other.priority {
      1
    } else {
      0
    }
    if prio_cmp != 0 {
      prio_cmp
    } else {
      self.id.compare(other.id)
    }
  }
}

///|
pub(all) struct EventHeap {
  priv data : Array[PriorityEvent]
} derive(Debug)

///|
pub fn EventHeap::new() -> EventHeap {
  { data: [] }
}

///|
pub fn EventHeap::is_empty(self : EventHeap) -> Bool {
  self.data.is_empty()
}

///|
pub fn EventHeap::size(self : EventHeap) -> Int {
  self.data.length()
}

///|
pub fn EventHeap::clear(self : EventHeap) -> Unit {
  self.data.clear()
}

///|
pub fn EventHeap::push(self : EventHeap, event : PriorityEvent) -> Unit {
  self.data.push(event)
  self.shift_up(self.data.length() - 1)
}

///|
pub fn EventHeap::peek(self : EventHeap) -> PriorityEvent? {
  if self.data.is_empty() {
    None
  } else {
    Some(self.data[0])
  }
}

///|
pub fn EventHeap::pop(self : EventHeap) -> PriorityEvent? {
  if self.data.is_empty() {
    return None
  }
  let top = self.data[0]
  let last_idx = self.data.length() - 1
  self.data[0] = self.data[last_idx]
  let _ = self.data.pop()
  if !self.data.is_empty() {
    self.shift_down(0)
  }
  Some(top)
}

///|
fn EventHeap::shift_up(self : EventHeap, idx : Int) -> Unit {
  let mut curr = idx
  while curr > 0 {
    let parent = (curr - 1) / 2
    if self.data[curr].compare(self.data[parent]) < 0 {
      let tmp = self.data[curr]
      self.data[curr] = self.data[parent]
      self.data[parent] = tmp
      curr = parent
    } else {
      break
    }
  }
}

///|
fn EventHeap::shift_down(self : EventHeap, idx : Int) -> Unit {
  let mut curr = idx
  let len = self.data.length()
  while true {
    let left = curr * 2 + 1
    let right = curr * 2 + 2
    let mut smallest = curr
    if left < len && self.data[left].compare(self.data[smallest]) < 0 {
      smallest = left
    }
    if right < len && self.data[right].compare(self.data[smallest]) < 0 {
      smallest = right
    }
    if smallest != curr {
      let tmp = self.data[curr]
      self.data[curr] = self.data[smallest]
      self.data[smallest] = tmp
      curr = smallest
    } else {
      break
    }
  }
}

///|
pub fn EventHeap::cancel_by_id(self : EventHeap, target_id : EventId) -> Bool {
  let mut found = false
  for i = 0; i < self.data.length(); i = i + 1 {
    if self.data[i].id == target_id && !self.data[i].cancelled {
      self.data[i].cancelled = true
      found = true
      break
    }
  }
  found
}

///|
pub fn EventHeap::filter_events(
  self : EventHeap,
  predicate : (PriorityEvent) -> Bool
) -> Int {
  let mut count = 0
  for i = 0; i < self.data.length(); i = i + 1 {
    if !self.data[i].cancelled && predicate(self.data[i]) {
      self.data[i].cancelled = true
      count = count + 1
    }
  }
  count
}

///|
pub fn EventHeap::active_count(self : EventHeap) -> Int {
  let mut count = 0
  for i = 0; i < self.data.length(); i = i + 1 {
    if !self.data[i].cancelled {
      count = count + 1
    }
  }
  count
}

///|
pub fn EventHeap::get_event_by_id(
  self : EventHeap,
  target_id : EventId
) -> PriorityEvent? {
  for i = 0; i < self.data.length(); i = i + 1 {
    if self.data[i].id == target_id {
      return Some(self.data[i])
    }
  }
  None
}
