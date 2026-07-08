///|
pub(all) enum ProcessStatus {
  Ready
  Running
  Suspended
  Terminated
} derive(Debug, Eq)

///|
pub impl Show for ProcessStatus with fn output(self, logger) {
  match self {
    Ready => logger.write_string("Ready")
    Running => logger.write_string("Running")
    Suspended => logger.write_string("Suspended")
    Terminated => logger.write_string("Terminated")
  }
}

///|
pub(all) struct Process {
  id : Int
  name : String
  mut step_idx : Int
  steps : Array[(ProcessContext) -> Double?]
  mut status : ProcessStatus
}

///|
pub impl Show for Process with fn output(self, logger) {
  logger.write_string(
    "Process(\{self.id}, \{self.name}, status=\{self.status})",
  )
}

///|
pub(all) struct ProcessContext {
  manager : EventManager
  clock : @clock.Clock
  proc_id : Int
}

///|
pub(all) struct EventManager {
  clock : @clock.Clock
  priv actions : Map[Int, () -> Unit]
  priv processes : Map[Int, Process]
  mut next_action_id : Int
  mut next_proc_id : Int
}

///|
pub fn EventManager::new(clock : @clock.Clock) -> EventManager {
  {
    clock,
    actions: Map::from_array([]),
    processes: Map::from_array([]),
    next_action_id: 1,
    next_proc_id: 1,
  }
}

///|
pub fn EventManager::clock(self : EventManager) -> @clock.Clock {
  self.clock
}

///|
pub fn EventManager::schedule_action(
  self : EventManager,
  delta_seconds : Double,
  priority : Int,
  action : () -> Unit,
) -> @clock.EventId {
  let action_id = self.next_action_id
  self.next_action_id = self.next_action_id + 1
  self.actions.set(action_id, action)
  self.clock.schedule(delta_seconds, priority, action_id)
}

///|
pub fn EventManager::register_process(
  self : EventManager,
  name : String,
  steps : Array[(ProcessContext) -> Double?],
) -> Int {
  let proc_id = self.next_proc_id
  self.next_proc_id = self.next_proc_id + 1
  let proc = { id: proc_id, name, step_idx: 0, steps, status: Ready }
  self.processes.set(proc_id, proc)
  proc_id
}

///|
pub fn EventManager::start_process(
  self : EventManager,
  proc_id : Int,
  delay : Double,
  priority : Int,
) -> @clock.EventId? {
  match self.processes.get(proc_id) {
    None => None
    Some(proc) => {
      if proc.status == Terminated {
        return None
      }
      proc.status = Running
      let payload_id = -proc_id
      Some(self.clock.schedule(delay, priority, payload_id))
    }
  }
}

///|
pub fn EventManager::step(self : EventManager) -> Bool {
  match self.clock.next_event() {
    None => false
    Some(ev) => {
      if ev.payload_id > 0 {
        match self.actions.get(ev.payload_id) {
          Some(action) => {
            action()
            self.actions.remove(ev.payload_id)
          }
          None => ()
        }
      } else if ev.payload_id < 0 {
        let proc_id = -ev.payload_id
        match self.processes.get(proc_id) {
          Some(proc) =>
            if proc.status != Terminated && !proc.steps.is_empty() {
              if proc.step_idx >= proc.steps.length() {
                proc.step_idx = 0
              }
              let ctx = { manager: self, clock: self.clock, proc_id }
              let current_step = proc.steps[proc.step_idx]
              proc.step_idx = proc.step_idx + 1
              match current_step(ctx) {
                Some(next_delay) => {
                  if proc.step_idx >= proc.steps.length() {
                    proc.step_idx = 0
                  }
                  proc.status = Suspended
                  let _ = self.clock.schedule(next_delay, ev.priority, -proc_id)
                }
                None => proc.status = Terminated
              }
            } else {
              proc.status = Terminated
            }
          None => ()
        }
      }
      true
    }
  }
}

///|
pub fn EventManager::run_until(
  self : EventManager,
  target_seconds : Double,
) -> Unit {
  self.clock.set_target_time(Some(target_seconds))
  while self.step() {

  }
}

///|
pub fn EventManager::run(self : EventManager) -> Unit {
  self.clock.set_target_time(None)
  while self.step() {

  }
}

///|
pub fn EventManager::get_process_status(
  self : EventManager,
  proc_id : Int,
) -> ProcessStatus? {
  match self.processes.get(proc_id) {
    None => None
    Some(p) => Some(p.status)
  }
}
