///|
pub(all) struct Simulation {
  clock : @clock.Clock
  event_manager : @event.EventManager
  priv resources : Map[String, @resource.Resource]
  priv summaries : Map[String, @stats.TimeWeightedSummary]
  priv sla_monitors : Map[String, @stats.SlaMonitor]
  priv percentile_trackers : Map[String, @stats.PercentileTracker]
  priv rolling_summaries : Map[String, @stats.RollingSummary]
}

///|
pub fn Simulation::new() -> Simulation {
  let clock = @clock.Clock::new()
  let event_manager = @event.EventManager::new(clock)
  {
    clock,
    event_manager,
    resources: Map::from_array([]),
    summaries: Map::from_array([]),
    sla_monitors: Map::from_array([]),
    percentile_trackers: Map::from_array([]),
    rolling_summaries: Map::from_array([]),
  }
}

///|
pub fn Simulation::clock(self : Simulation) -> @clock.Clock {
  self.clock
}

///|
pub fn Simulation::events(self : Simulation) -> @event.EventManager {
  self.event_manager
}

///|
pub fn Simulation::now(self : Simulation) -> Double {
  self.clock.now_seconds()
}

///|
pub fn Simulation::active_event_count(self : Simulation) -> Int {
  self.clock.active_count()
}

///|
pub fn Simulation::schedule(
  self : Simulation,
  delta_seconds : Double,
  priority : Int,
  action : () -> Unit
) -> @clock.EventId {
  self.event_manager.schedule_action(delta_seconds, priority, action)
}

///|
pub fn Simulation::schedule_at(
  self : Simulation,
  target_time : Double,
  priority : Int,
  action : () -> Unit
) -> @clock.EventId {
  let delta = target_time - self.now()
  let safe_delta = if delta < 0.0 { 0.0 } else { delta }
  self.event_manager.schedule_action(safe_delta, priority, action)
}

///|
pub fn Simulation::register_process(
  self : Simulation,
  name : String,
  steps : Array[(@event.ProcessContext) -> Double?]
) -> Int {
  self.event_manager.register_process(name, steps)
}

///|
pub fn Simulation::start_process(
  self : Simulation,
  proc_id : Int,
  delay : Double,
  priority : Int
) -> @clock.EventId? {
  self.event_manager.start_process(proc_id, delay, priority)
}

///|
pub fn Simulation::create_resource(
  self : Simulation,
  name : String,
  capacity : Int
) -> @resource.Resource {
  let res = @resource.Resource::new(name, capacity)
  self.resources.set(name, res)
  res
}

///|
pub fn Simulation::get_resource(self : Simulation, name : String) -> @resource.Resource? {
  self.resources.get(name)
}

///|
pub fn Simulation::create_summary(
  self : Simulation,
  name : String,
  initial_value : Double
) -> @stats.TimeWeightedSummary {
  let sum = @stats.TimeWeightedSummary::new(name, self.now(), initial_value)
  self.summaries.set(name, sum)
  sum
}

///|
pub fn Simulation::get_summary(self : Simulation, name : String) -> @stats.TimeWeightedSummary? {
  self.summaries.get(name)
}

///|
pub fn Simulation::create_sla_monitor(
  self : Simulation,
  name : String,
  threshold : Double
) -> @stats.SlaMonitor {
  let mon = @stats.SlaMonitor::new(name, threshold)
  self.sla_monitors.set(name, mon)
  mon
}

///|
pub fn Simulation::create_percentile_tracker(
  self : Simulation,
  name : String
) -> @stats.PercentileTracker {
  let tracker = @stats.PercentileTracker::new(name)
  self.percentile_trackers.set(name, tracker)
  tracker
}

///|
pub fn Simulation::create_rolling_summary(
  self : Simulation,
  name : String,
  window_size : Double
) -> @stats.RollingSummary {
  let roll = @stats.RollingSummary::new(name, window_size)
  self.rolling_summaries.set(name, roll)
  roll
}

///|
pub fn[T] Simulation::create_network_topology(
  self : Simulation,
  seed : Int
) -> @network.NetworkTopology[T] {
  @network.NetworkTopology::new(self.event_manager, seed)
}

///|
pub fn Simulation::step(self : Simulation) -> Bool {
  self.event_manager.step()
}

///|
pub fn Simulation::run_until(self : Simulation, target_seconds : Double) -> Unit {
  self.event_manager.run_until(target_seconds)
}

///|
pub fn Simulation::run(self : Simulation) -> Unit {
  self.event_manager.run()
}

///|
pub fn Simulation::reset(self : Simulation) -> Unit {
  self.clock.reset()
}
