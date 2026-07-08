///|
pub(all) struct NetworkTopology[T] {
  mgr : @event.EventManager
  priv nodes : Map[Int, NodeStatus]
  priv links : Map[String, NetworkLink]
  priv mailboxes : Map[Int, Array[Packet[T]]]
  mut next_seed : Int
}

///|
fn link_key(src : Int, dst : Int) -> String {
  "\{src}->\{dst}"
}

///|
pub fn[T] NetworkTopology::new(
  mgr : @event.EventManager,
  seed : Int,
) -> NetworkTopology[T] {
  {
    mgr,
    nodes: Map::from_array([]),
    links: Map::from_array([]),
    mailboxes: Map::from_array([]),
    next_seed: if seed <= 0 {
      1234567
    } else {
      seed
    },
  }
}

///|
fn[T] NetworkTopology::deterministic_random(
  self : NetworkTopology[T],
) -> Double {
  self.next_seed = (self.next_seed * 1103515245 + 12345) & 0x7FFFFFFF
  Double::from_int(self.next_seed) / 2147483648.0
}

///|
pub fn[T] NetworkTopology::add_node(
  self : NetworkTopology[T],
  node_id : Int,
) -> Unit {
  self.nodes.set(node_id, Online)
  self.mailboxes.set(node_id, [])
}

///|
pub fn[T] NetworkTopology::set_node_status(
  self : NetworkTopology[T],
  node_id : Int,
  status : NodeStatus,
) -> Unit {
  self.nodes.set(node_id, status)
}

///|
pub fn[T] NetworkTopology::get_node_status(
  self : NetworkTopology[T],
  node_id : Int,
) -> NodeStatus? {
  self.nodes.get(node_id)
}

///|
pub fn[T] NetworkTopology::add_link(
  self : NetworkTopology[T],
  src : Int,
  dst : Int,
  latency : Double,
  drop_probability : Double,
) -> Unit {
  let link = NetworkLink::new(src, dst, latency, drop_probability)
  self.links.set(link_key(src, dst), link)
}

///|
pub fn[T] NetworkTopology::get_link(
  self : NetworkTopology[T],
  src : Int,
  dst : Int,
) -> NetworkLink? {
  self.links.get(link_key(src, dst))
}

///|
pub fn[T] NetworkTopology::send_packet(
  self : NetworkTopology[T],
  src : Int,
  dst : Int,
  payload : T,
  priority : Int,
  on_deliver : (Packet[T]) -> Unit,
) -> Bool {
  match (self.nodes.get(src), self.nodes.get(dst)) {
    (Some(Online), Some(Online)) => ()
    _ => return false
  }

  let key = link_key(src, dst)
  match self.links.get(key) {
    None => false
    Some(link) => {
      link.packets_sent = link.packets_sent + 1
      let rand_val = self.deterministic_random()
      if rand_val < link.drop_probability {
        link.packets_dropped = link.packets_dropped + 1
        false
      } else {
        let send_time = self.mgr.clock().now_seconds()
        let pkt = { src, dst, payload, send_time }
        let _ = self.mgr.schedule_action(link.latency, priority, fn() {
          match self.nodes.get(dst) {
            Some(Online) => {
              link.packets_delivered = link.packets_delivered + 1
              match self.mailboxes.get(dst) {
                Some(box_arr) => box_arr.push(pkt)
                None => ()
              }
              on_deliver(pkt)
            }
            _ => link.packets_dropped = link.packets_dropped + 1
          }
        })
        true
      }
    }
  }
}

///|
pub fn[T] NetworkTopology::get_mailbox(
  self : NetworkTopology[T],
  node_id : Int,
) -> Array[Packet[T]] {
  match self.mailboxes.get(node_id) {
    None => []
    Some(arr) => arr
  }
}

///|
pub fn[T] NetworkTopology::pop_mailbox(
  self : NetworkTopology[T],
  node_id : Int,
) -> Packet[T]? {
  match self.mailboxes.get(node_id) {
    None => None
    Some(arr) =>
      if arr.is_empty() {
        None
      } else {
        let pkt = arr[0]
        let _ = arr.remove(0)
        Some(pkt)
      }
  }
}
