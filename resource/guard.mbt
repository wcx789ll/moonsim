///|
pub fn request_with_timeout(
  mgr : @event.EventManager,
  res : Resource,
  amount : Int,
  priority : Int,
  timeout : Double,
  callback : (Bool) -> Unit,
) -> @clock.EventId {
  let mut completed = false
  let mut req_id_box = 0
  let mut timeout_ev_box = @clock.EventId::{ seq: 0L }

  let timeout_ev = mgr.schedule_action(timeout, priority, fn() {
    if !completed {
      completed = true
      let _ = res.cancel_request(req_id_box)
      callback(false)
    }
  })
  timeout_ev_box = timeout_ev

  let req_id = res.request(amount, priority, fn(success : Bool) {
    if !completed {
      completed = true
      let _ = mgr.clock().cancel(timeout_ev_box)
      callback(success)
    }
  })
  req_id_box = req_id
  timeout_ev
}
