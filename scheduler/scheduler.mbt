// scheduler/scheduler.mbt
// Discrete-event driven scheduler that cooperates with the MoonSim
// EventManager.  A Scheduler manages a pool of identical executors and a
// waiting queue.  When a new Job arrives, it is either assigned immediately
// to a free executor or enqueued.  When an executor finishes, the next job
// (if any) is dispatched.

///|
/// A discrete-event scheduler with configurable queuing discipline and a
/// fixed pool of identical executor slots.
///
/// The scheduler integrates with the EventManager so that job start/finish
/// transitions are automatically scheduled as simulation events.
pub(all) struct Scheduler {
  name : String
  executors : Int
  mut busy_executors : Int
  queue : JobQueue
  event_manager : @event.EventManager
  /// Called when a job starts running.
  on_start : (Job) -> Unit
  /// Called when a job finishes successfully.
  on_complete : (Job) -> Unit
  /// Called when a job is cancelled before it could run.
  on_cancel : (Job) -> Unit
  /// Called when a job misses its deadline.
  on_deadline_miss : (Job) -> Unit
  mut total_arrived : Int
  mut total_completed : Int
  mut total_cancelled : Int
  mut total_deadline_miss : Int
  mut total_wait_time : Double
  mut total_service_time : Double
}

///|
pub fn Scheduler::new(
  name : String,
  executors : Int,
  discipline : QueueDiscipline,
  event_manager : @event.EventManager,
  on_start : (Job) -> Unit,
  on_complete : (Job) -> Unit,
  on_cancel : (Job) -> Unit,
  on_deadline_miss : (Job) -> Unit,
) -> Scheduler {
  if executors <= 0 {
    abort("Scheduler must have at least one executor")
  }
  {
    name,
    executors,
    busy_executors: 0,
    queue: JobQueue::new(discipline),
    event_manager,
    on_start,
    on_complete,
    on_cancel,
    on_deadline_miss,
    total_arrived: 0,
    total_completed: 0,
    total_cancelled: 0,
    total_deadline_miss: 0,
    total_wait_time: 0.0,
    total_service_time: 0.0,
  }
}

///|
/// Return the number of free executor slots at the current simulation time.
pub fn Scheduler::free_executors(self : Scheduler) -> Int {
  self.executors - self.busy_executors
}

///|
/// Return the current queue length.
pub fn Scheduler::queue_length(self : Scheduler) -> Int {
  self.queue.length()
}

///|
/// Return total jobs that have arrived since the scheduler was created.
pub fn Scheduler::total_arrived(self : Scheduler) -> Int {
  self.total_arrived
}

///|
/// Return total jobs that completed before their deadline.
pub fn Scheduler::total_completed(self : Scheduler) -> Int {
  self.total_completed
}

///|
/// Return total jobs cancelled before running.
pub fn Scheduler::total_cancelled(self : Scheduler) -> Int {
  self.total_cancelled
}

///|
/// Return total jobs that missed their deadline.
pub fn Scheduler::total_deadline_miss(self : Scheduler) -> Int {
  self.total_deadline_miss
}

///|
/// Return the mean queuing wait time across all completed jobs.
/// Returns 0.0 if no jobs have completed yet.
pub fn Scheduler::mean_wait_time(self : Scheduler) -> Double {
  if self.total_completed == 0 {
    0.0
  } else {
    self.total_wait_time / Double::from_int(self.total_completed)
  }
}

///|
/// Return the mean service (execution) time across all completed jobs.
pub fn Scheduler::mean_service_time(self : Scheduler) -> Double {
  if self.total_completed == 0 {
    0.0
  } else {
    self.total_service_time / Double::from_int(self.total_completed)
  }
}

///|
/// Submit a new job to the scheduler.
///
/// If a free executor is available, the job starts immediately; otherwise
/// it enters the waiting queue.  Deadline enforcement is scheduled as a
/// separate simulation event when a deadline is present.
pub fn Scheduler::submit(self : Scheduler, job : Job) -> Unit {
  self.total_arrived = self.total_arrived + 1

  // Enforce deadline: schedule a "miss" event if applicable
  match job.deadline {
    None => ()
    Some(dl) => {
      let now = self.event_manager.clock.now_seconds()
      let remaining = dl - now
      if remaining > 0.0 {
        let _ = self.event_manager.schedule_action(remaining, 0, fn() {
          if job.status == Queued || job.status == Running {
            if job.status == Queued {
              let _ = self.queue.remove_by_id(job.id)
            } else {
              // Running job missed deadline: free executor slot
              self.busy_executors = self.busy_executors - 1
            }
            job.status = DeadlineMissed
            job.finish_time = Some(self.event_manager.clock.now_seconds())
            self.total_deadline_miss = self.total_deadline_miss + 1
            (self.on_deadline_miss)(job)
            self.try_dispatch()
          }
        })
      } else {
        // Already past deadline on arrival
        job.status = DeadlineMissed
        job.finish_time = Some(self.event_manager.clock.now_seconds())
        self.total_deadline_miss = self.total_deadline_miss + 1
        (self.on_deadline_miss)(job)
        return
      }
    }
  }

  if self.busy_executors < self.executors {
    self.dispatch(job)
  } else {
    self.queue.enqueue(job)
  }
}

///|
/// Cancel a queued (not yet running) job by id.
/// Returns `true` if the job was found in the queue and cancelled.
pub fn Scheduler::cancel(self : Scheduler, job_id : Int) -> Bool {
  // We need to cancel in the queue only; running jobs cannot be cancelled
  // without cooperative preemption (outside scope here)
  // Find in raw job list through public remove_by_id
  let removed = self.queue.remove_by_id(job_id)
  if removed {
    self.total_cancelled = self.total_cancelled + 1
  }
  removed
}

///|
fn Scheduler::dispatch(self : Scheduler, job : Job) -> Unit {
  let now = self.event_manager.clock.now_seconds()
  job.status = Running
  job.start_time = Some(now)
  self.busy_executors = self.busy_executors + 1
  self.total_wait_time = self.total_wait_time + (now - job.arrival_time)
  (self.on_start)(job)

  let _ = self.event_manager.schedule_action(job.service_time, 5, fn() {
    if job.status == Running {
      let finish = self.event_manager.clock.now_seconds()
      job.status = Completed
      job.finish_time = Some(finish)
      self.busy_executors = self.busy_executors - 1
      self.total_completed = self.total_completed + 1
      self.total_service_time = self.total_service_time + job.service_time
      (self.on_complete)(job)
      self.try_dispatch()
    }
  })
}

///|
fn Scheduler::try_dispatch(self : Scheduler) -> Unit {
  while self.busy_executors < self.executors && !self.queue.is_empty() {
    match self.queue.dequeue() {
      None => break
      Some(j) => if j.status == Queued { self.dispatch(j) }
    }
  }
}
