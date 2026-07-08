///|
pub const PRIORITY_CRITICAL : Int = 0

///|
pub const PRIORITY_HIGH : Int = 5

///|
pub const PRIORITY_NORMAL : Int = 10

///|
pub const PRIORITY_LOW : Int = 20

///|
pub const PRIORITY_BACKGROUND : Int = 100

///|
pub fn clamp_priority(p : Int) -> Int {
  if p < 0 {
    0
  } else {
    p
  }
}
