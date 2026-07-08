///|
pub(all) struct Simulation {
  clock : @clock.Clock
  event_manager : @event.EventManager
  priv resources : Map[String, @resource.Resource]
  priv summaries : Map[String, @stats.TimeWeightedSummary]
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
pub fn Simulation::schedule(
  self : Simulation,
  delta_seconds : Double,
  priority : Int,
  action : () -> Unit,
) -> @clock.EventId {
  self.event_manager.schedule_action(delta_seconds, priority, action)
}

///|
pub fn Simulation::register_process(
  self : Simulation,
  name : String,
  steps : Array[(@event.ProcessContext) -> Double?],
) -> Int {
  self.event_manager.register_process(name, steps)
}

///|
pub fn Simulation::start_process(
  self : Simulation,
  proc_id : Int,
  delay : Double,
  priority : Int,
) -> @clock.EventId? {
  self.event_manager.start_process(proc_id, delay, priority)
}

///|
pub fn Simulation::create_resource(
  self : Simulation,
  name : String,
  capacity : Int,
) -> @resource.Resource {
  let res = @resource.Resource::new(name, capacity)
  self.resources.set(name, res)
  res
}

///|
pub fn Simulation::get_resource(
  self : Simulation,
  name : String,
) -> @resource.Resource? {
  self.resources.get(name)
}

///|
pub fn Simulation::create_summary(
  self : Simulation,
  name : String,
  initial_value : Double,
) -> @stats.TimeWeightedSummary {
  let sum = @stats.TimeWeightedSummary::new(name, self.now(), initial_value)
  self.summaries.set(name, sum)
  sum
}

///|
pub fn Simulation::get_summary(
  self : Simulation,
  name : String,
) -> @stats.TimeWeightedSummary? {
  self.summaries.get(name)
}

///|
pub fn[T] Simulation::create_network_topology(
  self : Simulation,
  seed : Int,
) -> @network.NetworkTopology[T] {
  @network.NetworkTopology::new(self.event_manager, seed)
}

///|
pub fn Simulation::step(self : Simulation) -> Bool {
  self.event_manager.step()
}

///|
pub fn Simulation::run_until(
  self : Simulation,
  target_seconds : Double,
) -> Unit {
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
