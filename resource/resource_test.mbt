///|
test "resource_request_and_release" {
  let res = Resource::new("Teller", 2)
  let mut served = 0

  let _ = res.request(1, 10, fn(success : Bool) {
    if success {
      served = served + 1
    }
  })
  let _ = res.request(1, 10, fn(success : Bool) {
    if success {
      served = served + 1
    }
  })
  assert_eq(served, 2)
  assert_eq(res.available(), 0)

  // Third request must wait
  let _ = res.request(1, 10, fn(success : Bool) {
    if success {
      served = served + 10
    }
  })
  assert_eq(served, 2)
  assert_eq(res.queue_length(), 1)

  // Release 1 unit -> waiting request triggered
  res.release(1)
  assert_eq(served, 12)
  assert_eq(res.available(), 0)
  assert_eq(res.queue_length(), 0)
}

///|
test "resource_request_with_timeout" {
  let clock = @clock.Clock::new()
  let mgr = @event.EventManager::new(clock)
  let res = Resource::new("CPU", 1)
  let mut status_res = -1

  // Acquire the only CPU unit
  let _ = res.request(1, 10, fn(_ : Bool) {  })

  // Second request tries to acquire with timeout = 5.0s
  let _ = request_with_timeout(mgr, res, 1, 10, 5.0, fn(success : Bool) {
    if success {
      status_res = 1
    } else {
      status_res = 0 // timed out
    }
  })

  // Run simulation until t=6.0 -> timeout should trigger at t=5.0
  mgr.run_until(6.0)
  assert_eq(status_res, 0)
  assert_eq(res.queue_length(), 0)
}

///|
test "store_and_container" {
  let store : Store[String] = Store::new("Buffer", 2)
  let mut got = ""
  store.put("Item A", fn() {  })
  store.get(fn(item : String) { got = item })
  assert_eq(got, "Item A")

  let container = Container::new("Water", 100.0, 50.0)
  let mut put_ok = false
  container.put(20.0, fn(ok : Bool) { put_ok = ok })
  assert_true(put_ok)
  assert_eq(container.level(), 70.0)
}
