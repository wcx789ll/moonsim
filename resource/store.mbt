///|
pub(all) struct StorePutRequest[T] {
  item : T
  callback : () -> Unit
}

///|
pub(all) struct StoreGetRequest[T] {
  callback : (T) -> Unit
}

///|
pub(all) struct Store[T] {
  name : String
  capacity : Int
  priv items : Array[T]
  priv put_queue : Array[StorePutRequest[T]]
  priv get_queue : Array[StoreGetRequest[T]]
}

///|
pub fn[T] Store::new(name : String, capacity : Int) -> Store[T] {
  if capacity <= 0 {
    abort("Store capacity must be positive")
  }
  { name, capacity, items: [], put_queue: [], get_queue: [] }
}

///|
pub fn[T] Store::size(self : Store[T]) -> Int {
  self.items.length()
}

///|
pub fn[T] Store::capacity(self : Store[T]) -> Int {
  self.capacity
}

///|
pub fn[T] Store::put(self : Store[T], item : T, callback : () -> Unit) -> Unit {
  if !self.get_queue.is_empty() {
    let req = self.get_queue[0]
    let _ = self.get_queue.remove(0)
    callback()
    (req.callback)(item)
  } else if self.items.length() < self.capacity {
    self.items.push(item)
    callback()
  } else {
    self.put_queue.push({ item, callback })
  }
}

///|
pub fn[T] Store::get(self : Store[T], callback : (T) -> Unit) -> Unit {
  if !self.items.is_empty() {
    let item = self.items[0]
    let _ = self.items.remove(0)
    callback(item)
    if !self.put_queue.is_empty() {
      let put_req = self.put_queue[0]
      let _ = self.put_queue.remove(0)
      self.items.push(put_req.item)
      (put_req.callback)()
    }
  } else {
    self.get_queue.push({ callback, })
  }
}

///|
pub(all) struct Container {
  name : String
  capacity : Double
  mut level : Double
  priv get_queue : Array[(Double, (Bool) -> Unit)]
  priv put_queue : Array[(Double, (Bool) -> Unit)]
}

///|
pub fn Container::new(
  name : String,
  capacity : Double,
  initial_level : Double,
) -> Container {
  if capacity <= 0.0 || initial_level < 0.0 || initial_level > capacity {
    abort("Invalid Container initial parameters")
  }
  { name, capacity, level: initial_level, get_queue: [], put_queue: [] }
}

///|
pub fn Container::level(self : Container) -> Double {
  self.level
}

///|
pub fn Container::capacity(self : Container) -> Double {
  self.capacity
}

///|
pub fn Container::put(
  self : Container,
  amount : Double,
  callback : (Bool) -> Unit,
) -> Unit {
  if amount <= 0.0 {
    abort("Container put amount must be positive")
  }
  if self.level + amount <= self.capacity {
    self.level = self.level + amount
    callback(true)
    self.process_get_queue()
  } else {
    self.put_queue.push((amount, callback))
  }
}

///|
pub fn Container::get(
  self : Container,
  amount : Double,
  callback : (Bool) -> Unit,
) -> Unit {
  if amount <= 0.0 {
    abort("Container get amount must be positive")
  }
  if self.level >= amount {
    self.level = self.level - amount
    callback(true)
    self.process_put_queue()
  } else {
    self.get_queue.push((amount, callback))
  }
}

///|
fn Container::process_get_queue(self : Container) -> Unit {
  while !self.get_queue.is_empty() {
    let (req_amt, cb) = self.get_queue[0]
    if self.level >= req_amt {
      self.level = self.level - req_amt
      let _ = self.get_queue.remove(0)
      cb(true)
      self.process_put_queue()
    } else {
      break
    }
  }
}

///|
fn Container::process_put_queue(self : Container) -> Unit {
  while !self.put_queue.is_empty() {
    let (req_amt, cb) = self.put_queue[0]
    if self.level + req_amt <= self.capacity {
      self.level = self.level + req_amt
      let _ = self.put_queue.remove(0)
      cb(true)
      self.process_get_queue()
    } else {
      break
    }
  }
}
