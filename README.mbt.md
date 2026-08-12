# MoonSim

MoonSim is a deterministic discrete-event and distributed-network simulation
framework written in MoonBit. It models virtual time, stable event ordering,
resource contention, deadlines, packet loss, bandwidth queues, SLA metrics,
and trace export.

## Quick start

Run `moon check`, then `moon test`. Runnable scenarios are available under
`examples/`, including `examples/acceptance_benchmark`.

The benchmark suite uses fixed inputs: 10,000 event callbacks, 2,000 network
packets, and 1,000 scheduled jobs. It is intended for regression comparison,
not as a claim about physical hardware or public-network performance.

The public API is exposed by the `wcx789ll/moonsim` module. The root license is
Apache License 2.0; see `LICENSE` and `THIRD_PARTY.md` for compliance notes.
