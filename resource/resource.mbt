///|
pub(all) struct ResourceRequest {
  id : Int
  amount : Int
  priority : Int
  callback : (Bool) -> Unit
  mut cancelled : Bool
}

///|
pub(all) struct Resource {
  name : String
  capacity : Int
  mut available : Int
  priv wait_queue : Array[ResourceRequest]
  mut next_req_id : Int
}

///|
pub fn Resource::new(name : String, capacity : Int) -> Resource {
  if capacity <= 0 {
    abort("Resource capacity must be positive")
  }
  { name, capacity, available: capacity, wait_queue: [], next_req_id: 1 }
}

///|
pub fn Resource::available(self : Resource) -> Int {
  self.available
}

///|
pub fn Resource::capacity(self : Resource) -> Int {
  self.capacity
}

///|
pub fn Resource::queue_length(self : Resource) -> Int {
  let mut count = 0
  for req in self.wait_queue {
    if !req.cancelled {
      count = count + 1
    }
  }
  count
}

///|
pub fn Resource::request(
  self : Resource,
  amount : Int,
  priority : Int,
  callback : (Bool) -> Unit,
) -> Int {
  if amount <= 0 || amount > self.capacity {
    abort("Invalid request amount for Resource")
  }
  let req_id = self.next_req_id
  self.next_req_id = self.next_req_id + 1

  if self.wait_queue.is_empty() && self.available >= amount {
    self.available = self.available - amount
    callback(true)
    req_id
  } else {
    let req = { id: req_id, amount, priority, callback, cancelled: false }
    // Insert into wait queue ordered by priority (lower number = higher priority)
    let mut insert_idx = self.wait_queue.length()
    for i = 0; i < self.wait_queue.length(); i = i + 1 {
      if self.wait_queue[i].priority > priority {
        insert_idx = i
        break
      }
    }
    self.wait_queue.insert(insert_idx, req)
    req_id
  }
}

///|
pub fn Resource::cancel_request(self : Resource, req_id : Int) -> Bool {
  let mut found = false
  for i = 0; i < self.wait_queue.length(); i = i + 1 {
    if self.wait_queue[i].id == req_id && !self.wait_queue[i].cancelled {
      self.wait_queue[i].cancelled = true
      found = true
      break
    }
  }
  self.clean_cancelled()
  found
}

///|
fn Resource::clean_cancelled(self : Resource) -> Unit {
  let mut idx = 0
  while idx < self.wait_queue.length() {
    if self.wait_queue[idx].cancelled {
      let _ = self.wait_queue.remove(idx)
    } else {
      idx = idx + 1
    }
  }
}

///|
pub fn Resource::release(self : Resource, amount : Int) -> Unit {
  if amount <= 0 {
    abort("Release amount must be positive")
  }
  if self.available + amount > self.capacity {
    abort("Release exceeds capacity of Resource \{self.name}")
  }
  self.available = self.available + amount
  self.process_queue()
}

///|
fn Resource::process_queue(self : Resource) -> Unit {
  self.clean_cancelled()
  while !self.wait_queue.is_empty() {
    let top = self.wait_queue[0]
    if self.available >= top.amount {
      self.available = self.available - top.amount
      let _ = self.wait_queue.remove(0)
      (top.callback)(true)
    } else {
      break
    }
  }
}
