// scheduler/scheduler_test.mbt
// Unit tests for the Job, JobQueue, and Scheduler abstractions.

///|
test "job_wait_time_and_sojourn_time" {
  let j = Job::new(1, 0.0, 2.0, None, 5)
  assert_true(j.wait_time() is None)
  assert_true(j.sojourn_time() is None)
  j.start_time = Some(1.0)
  assert_eq(j.wait_time().unwrap(), 1.0)
  j.finish_time = Some(3.0)
  assert_eq(j.sojourn_time().unwrap(), 3.0)
}

///|
test "job_has_missed_deadline" {
  let j_no_dl = Job::new(2, 0.0, 1.0, None, 0)
  assert_eq(j_no_dl.has_missed_deadline(100.0), false)

  let j_dl = Job::new(3, 0.0, 1.0, Some(5.0), 0)
  assert_eq(j_dl.has_missed_deadline(4.0), false)
  assert_eq(j_dl.has_missed_deadline(6.0), true)
  j_dl.finish_time = Some(4.9)
  assert_eq(j_dl.has_missed_deadline(100.0), false)
  j_dl.finish_time = Some(5.1)
  assert_eq(j_dl.has_missed_deadline(100.0), true)
}

///|
test "job_queue_fifo_ordering" {
  let q = JobQueue::new(Fifo)
  let j1 = Job::new(10, 0.0, 1.0, None, 5)
  let j2 = Job::new(11, 1.0, 1.0, None, 1)
  let j3 = Job::new(12, 0.5, 1.0, None, 10)
  q.enqueue(j1)
  q.enqueue(j2)
  q.enqueue(j3)
  assert_eq(q.length(), 3)

  // FIFO: j1 (t=0.0) first, then j3 (t=0.5), then j2 (t=1.0)
  let first = q.dequeue().unwrap()
  assert_eq(first.id, 10)
  let second = q.dequeue().unwrap()
  assert_eq(second.id, 12)
  let third = q.dequeue().unwrap()
  assert_eq(third.id, 11)
  assert_true(q.is_empty())
}

///|
test "job_queue_priority_ascending" {
  let q = JobQueue::new(PriorityAscending)
  let j1 = Job::new(1, 0.0, 1.0, None, 10)
  let j2 = Job::new(2, 0.0, 1.0, None, 1)
  let j3 = Job::new(3, 0.0, 1.0, None, 5)
  q.enqueue(j1)
  q.enqueue(j2)
  q.enqueue(j3)

  assert_eq(q.dequeue().unwrap().priority, 1)
  assert_eq(q.dequeue().unwrap().priority, 5)
  assert_eq(q.dequeue().unwrap().priority, 10)
}

///|
test "job_queue_sjf" {
  let q = JobQueue::new(ShortestJobFirst)
  let j1 = Job::new(1, 0.0, 5.0, None, 0)
  let j2 = Job::new(2, 0.0, 1.0, None, 0)
  let j3 = Job::new(3, 0.0, 3.0, None, 0)
  q.enqueue(j1)
  q.enqueue(j2)
  q.enqueue(j3)

  assert_eq(q.dequeue().unwrap().service_time, 1.0)
  assert_eq(q.dequeue().unwrap().service_time, 3.0)
  assert_eq(q.dequeue().unwrap().service_time, 5.0)
}

///|
test "job_queue_edf" {
  let q = JobQueue::new(EarliestDeadlineFirst)
  let j1 = Job::new(1, 0.0, 1.0, Some(10.0), 0)
  let j2 = Job::new(2, 0.0, 1.0, Some(2.0), 0)
  let j3 = Job::new(3, 0.0, 1.0, None, 0) // No deadline -> serves last
  q.enqueue(j1)
  q.enqueue(j2)
  q.enqueue(j3)

  assert_eq(q.dequeue().unwrap().id, 2)
  assert_eq(q.dequeue().unwrap().id, 1)
  assert_eq(q.dequeue().unwrap().id, 3)
}

///|
test "job_queue_remove_by_id" {
  let q = JobQueue::new(Fifo)
  q.enqueue(Job::new(1, 0.0, 1.0, None, 0))
  q.enqueue(Job::new(2, 1.0, 1.0, None, 0))
  q.enqueue(Job::new(3, 2.0, 1.0, None, 0))

  let removed = q.remove_by_id(2)
  assert_true(removed)
  assert_eq(q.length(), 2)

  let not_found = q.remove_by_id(99)
  assert_eq(not_found, false)

  assert_eq(q.dequeue().unwrap().id, 1)
  assert_eq(q.dequeue().unwrap().id, 3)
}

///|
test "scheduler_basic_fifo_completion" {
  let clock = @clock.Clock::new()
  let mgr = @event.EventManager::new(clock)
  let completed_jobs : Array[Int] = []

  let sched = Scheduler::new(
    "TestSched",
    2, // 2 executors
    Fifo,
    mgr,
    fn(_j) {  },
    fn(j) { completed_jobs.push(j.id) },
    fn(_j) {  },
    fn(_j) {  },
  )

  // Submit 4 jobs, 2 will queue (service_time = 1.0s)
  sched.submit(Job::new(1, 0.0, 1.0, None, 0))
  sched.submit(Job::new(2, 0.0, 1.0, None, 0))
  sched.submit(Job::new(3, 0.0, 1.0, None, 0))
  sched.submit(Job::new(4, 0.0, 1.0, None, 0))

  assert_eq(sched.busy_executors, 2)
  assert_eq(sched.queue_length(), 2)

  mgr.run_until(5.0)

  assert_eq(sched.total_completed(), 4)
  assert_eq(sched.total_arrived(), 4)
  assert_eq(completed_jobs.length(), 4)
}

///|
test "scheduler_deadline_enforcement" {
  let clock = @clock.Clock::new()
  let mgr = @event.EventManager::new(clock)
  let mut deadline_misses = 0

  let sched = Scheduler::new(
    "DeadlineSched",
    1, // 1 executor only
    Fifo,
    mgr,
    fn(_j) {  },
    fn(_j) {  },
    fn(_j) {  },
    fn(_j) { deadline_misses = deadline_misses + 1 },
  )

  // Job 1 occupies executor for 5.0s
  sched.submit(Job::new(1, 0.0, 5.0, None, 0))
  // Job 2 has deadline of 3.0s but arrives when executor is busy -> deadline miss
  sched.submit(Job::new(2, 0.0, 1.0, Some(3.0), 0))

  mgr.run_until(10.0)
  assert_eq(deadline_misses, 1)
  assert_eq(sched.total_deadline_miss(), 1)
}

///|
test "scheduler_mean_wait_time" {
  let clock = @clock.Clock::new()
  let mgr = @event.EventManager::new(clock)

  let sched = Scheduler::new(
    "WaitSched",
    1,
    Fifo,
    mgr,
    fn(_j) {  },
    fn(_j) {  },
    fn(_j) {  },
    fn(_j) {  },
  )

  // Job 1: arrives t=0, runs immediately (no wait)
  // Job 2: arrives t=0, waits for job 1 to finish at t=2.0
  sched.submit(Job::new(1, 0.0, 2.0, None, 0))
  sched.submit(Job::new(2, 0.0, 1.0, None, 0))

  mgr.run_until(10.0)

  assert_eq(sched.total_completed(), 2)
  // Total wait = 0 + 2.0 = 2.0. Mean wait = 1.0s
  assert_eq(sched.mean_wait_time(), 1.0)
}
