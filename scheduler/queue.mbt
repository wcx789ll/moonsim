// scheduler/queue.mbt
// Priority-aware waiting queue used by all scheduling disciplines.
// Jobs are stored sorted by the chosen discipline at insertion time so
// dequeue is always O(1) and enqueue is O(n) worst-case (acceptable for
// simulation workloads).

///|
/// Available queueing disciplines governing the order in which Jobs are
/// dequeued from the waiting area.
pub(all) enum QueueDiscipline {
  /// Jobs are served in the order they arrived (smallest `arrival_time` first).
  Fifo
  /// Jobs are served in reverse arrival order (newest first).
  Lifo
  /// Jobs are served in ascending priority order (smallest priority integer wins).
  PriorityAscending
  /// Jobs are served in descending priority order (largest priority integer wins).
  PriorityDescending
  /// Shortest-service-time jobs are served first (Shortest Job First).
  ShortestJobFirst
  /// Longest-service-time jobs are served first.
  LongestJobFirst
  /// Jobs closest to their deadline are served first (Earliest Deadline First).
  EarliestDeadlineFirst
} derive(Debug, Eq)

///|
/// A waiting queue backed by an array sorted according to a chosen discipline.
pub(all) struct JobQueue {
  discipline : QueueDiscipline
  priv jobs : Array[Job]
}

///|
pub fn JobQueue::new(discipline : QueueDiscipline) -> JobQueue {
  { discipline, jobs: [] }
}

///|
pub fn JobQueue::length(self : JobQueue) -> Int {
  self.jobs.length()
}

///|
pub fn JobQueue::is_empty(self : JobQueue) -> Bool {
  self.jobs.is_empty()
}

///|
/// Compare two jobs according to the queue's discipline.
/// Returns negative if `a` should be served before `b`.
fn JobQueue::compare_jobs(self : JobQueue, a : Job, b : Job) -> Int {
  match self.discipline {
    Fifo =>
      if a.arrival_time < b.arrival_time {
        -1
      } else if a.arrival_time > b.arrival_time {
        1
      } else {
        a.id - b.id
      }
    Lifo =>
      if a.arrival_time > b.arrival_time {
        -1
      } else if a.arrival_time < b.arrival_time {
        1
      } else {
        b.id - a.id
      }
    PriorityAscending =>
      if a.priority < b.priority {
        -1
      } else if a.priority > b.priority {
        1
      } else if a.arrival_time < b.arrival_time {
        -1
      } else if a.arrival_time > b.arrival_time {
        1
      } else {
        a.id - b.id
      }
    PriorityDescending =>
      if a.priority > b.priority {
        -1
      } else if a.priority < b.priority {
        1
      } else if a.arrival_time < b.arrival_time {
        -1
      } else if a.arrival_time > b.arrival_time {
        1
      } else {
        a.id - b.id
      }
    ShortestJobFirst =>
      if a.service_time < b.service_time {
        -1
      } else if a.service_time > b.service_time {
        1
      } else {
        a.id - b.id
      }
    LongestJobFirst =>
      if a.service_time > b.service_time {
        -1
      } else if a.service_time < b.service_time {
        1
      } else {
        a.id - b.id
      }
    EarliestDeadlineFirst => {
      let dl_a = match a.deadline {
        None => 1.0e300
        Some(d) => d
      }
      let dl_b = match b.deadline {
        None => 1.0e300
        Some(d) => d
      }
      if dl_a < dl_b {
        -1
      } else if dl_a > dl_b {
        1
      } else {
        a.id - b.id
      }
    }
  }
}

///|
/// Enqueue a job in the position determined by the discipline.
pub fn JobQueue::enqueue(self : JobQueue, job : Job) -> Unit {
  let mut insert_idx = self.jobs.length()
  for i = 0; i < self.jobs.length(); i = i + 1 {
    if self.compare_jobs(job, self.jobs[i]) < 0 {
      insert_idx = i
      break
    }
  }
  self.jobs.insert(insert_idx, job)
}

///|
/// Dequeue the highest-priority job according to the current discipline.
/// Returns `None` if the queue is empty.
pub fn JobQueue::dequeue(self : JobQueue) -> Job? {
  if self.jobs.is_empty() {
    None
  } else {
    Some(self.jobs.remove(0))
  }
}

///|
/// Peek at the next job to be dequeued without removing it.
pub fn JobQueue::peek(self : JobQueue) -> Job? {
  if self.jobs.is_empty() {
    None
  } else {
    Some(self.jobs[0])
  }
}

///|
/// Remove a specific job by id. Returns `true` if found and removed.
pub fn JobQueue::remove_by_id(self : JobQueue, job_id : Int) -> Bool {
  let mut idx = 0
  let mut found = false
  while idx < self.jobs.length() {
    if self.jobs[idx].id == job_id {
      let _ = self.jobs.remove(idx)
      found = true
      break
    } else {
      idx = idx + 1
    }
  }
  found
}
