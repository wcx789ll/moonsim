///|
pub(all) struct ActiveHolder {
  id : Int
  amount : Int
  priority : Int
  preempt_callback : () -> Unit
}

///|
pub(all) struct PreemptibleResource {
  name : String
  capacity : Int
  mut available : Int
  priv wait_queue : Array[ResourceRequest]
  priv holders : Array[ActiveHolder]
  mut next_req_id : Int
  mut next_holder_id : Int
}

///|
pub fn PreemptibleResource::new(
  name : String,
  capacity : Int,
) -> PreemptibleResource {
  if capacity <= 0 {
    abort("PreemptibleResource capacity must be positive")
  }
  {
    name,
    capacity,
    available: capacity,
    wait_queue: [],
    holders: [],
    next_req_id: 1,
    next_holder_id: 1,
  }
}

///|
pub fn PreemptibleResource::available(self : PreemptibleResource) -> Int {
  self.available
}

///|
pub fn PreemptibleResource::capacity(self : PreemptibleResource) -> Int {
  self.capacity
}

///|
pub fn PreemptibleResource::holder_count(self : PreemptibleResource) -> Int {
  self.holders.length()
}

///|
pub fn PreemptibleResource::request(
  self : PreemptibleResource,
  amount : Int,
  priority : Int,
  callback : (Int?) -> Unit,
  preempt_callback : () -> Unit,
) -> Int {
  if amount <= 0 || amount > self.capacity {
    abort("Invalid request amount for PreemptibleResource")
  }
  let req_id = self.next_req_id
  self.next_req_id = self.next_req_id + 1

  if self.available >= amount {
    self.allocate(amount, priority, preempt_callback, callback)
    req_id
  } else {
    let mut preemptible_amount = self.available
    let candidate_indices : Array[Int] = []
    for i = self.holders.length() - 1; i >= 0; i = i - 1 {
      if self.holders[i].priority > priority {
        preemptible_amount = preemptible_amount + self.holders[i].amount
        candidate_indices.push(i)
        if preemptible_amount >= amount {
          break
        }
      }
    }

    if preemptible_amount >= amount {
      for i in candidate_indices {
        let holder = self.holders[i]
        self.available = self.available + holder.amount
        (holder.preempt_callback)()
      }
      let new_holders : Array[ActiveHolder] = []
      for h in self.holders {
        let mut keep = true
        for idx in candidate_indices {
          if self.holders[idx].id == h.id {
            keep = false
            break
          }
        }
        if keep {
          new_holders.push(h)
        }
      }
      self.holders.clear()
      for h in new_holders {
        self.holders.push(h)
      }

      self.allocate(amount, priority, preempt_callback, callback)
      req_id
    } else {
      let req = {
        id: req_id,
        amount,
        priority,
        callback: fn(ok) {
          if ok {
            let holder_id = self.next_holder_id
            self.next_holder_id = self.next_holder_id + 1
            self.holders.push({
              id: holder_id,
              amount,
              priority,
              preempt_callback,
            })
            callback(Some(holder_id))
          } else {
            callback(None)
          }
        },
        cancelled: false,
      }
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
}

///|
fn PreemptibleResource::allocate(
  self : PreemptibleResource,
  amount : Int,
  priority : Int,
  preempt_callback : () -> Unit,
  callback : (Int?) -> Unit,
) -> Unit {
  self.available = self.available - amount
  let holder_id = self.next_holder_id
  self.next_holder_id = self.next_holder_id + 1
  self.holders.push({ id: holder_id, amount, priority, preempt_callback })
  callback(Some(holder_id))
}

///|
pub fn PreemptibleResource::release(
  self : PreemptibleResource,
  holder_id : Int,
) -> Unit {
  let mut found = false
  let mut released_amount = 0
  let mut idx = 0
  while idx < self.holders.length() {
    if self.holders[idx].id == holder_id {
      released_amount = self.holders[idx].amount
      let _ = self.holders.remove(idx)
      found = true
      break
    } else {
      idx = idx + 1
    }
  }
  if found {
    self.available = self.available + released_amount
    self.process_queue()
  }
}

///|
fn PreemptibleResource::process_queue(self : PreemptibleResource) -> Unit {
  let mut idx = 0
  while idx < self.wait_queue.length() {
    if self.wait_queue[idx].cancelled {
      let _ = self.wait_queue.remove(idx)
    } else {
      idx = idx + 1
    }
  }
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
