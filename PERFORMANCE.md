# Combat performance

The September 21 optimization preserves particle counts, draw order, lifetimes,
resolution, and effect quality. Particle expiry now compacts the array in a single
stable pass instead of shifting its contents on each removal. Stationary particles
skip velocity integration and exponential drag. Fully transparent fire and smoke
skip draw submission; cooling smoke and ember wakes still render independently.

## CPU measurement

Godot 4.7.2, Linux, headless, same machine, before/after the changes. Each case
has five warmup iterations and 30 timed iterations. Fixture creation and rendering
are excluded. Results are medians, not end-to-end frame times:

| Particles | Expiring this update | Before | After | Reduction |
| --- | --- | --- | --- | --- |
| 500 | None | 491 µs | 382 µs | 22% |
| 500 | Alternating half | 566 µs | 436 µs | 23% |
| 4,000 | None | 4,025 µs | 3,035 µs | 25% |
| 4,000 | Alternating half | 5,224 µs | 3,488 µs | 33% |

These synthetic stationary-fire workloads isolate the changed paths; they are
not a claim about typical gameplay particle counts or iPhone FPS. Timing varies
with system load. GPU and sustained iPhone performance remain unmeasured.

Run from the repository root (substitute your Godot executable):

```sh
godot --headless --path . --script tests/performance/particles.gd --log-file /tmp/starfall-perf.log
```

The regression suite checks survivor ordering, moving and stationary particles,
exactly-once lifetime updates, all-expired and empty arrays. Existing tests cover
fragment cooling, bounded trails, attachment, and ember-to-smoke transitions.

Next device validation: replay the reference encounter on an iPhone, measure
CPU/GPU frame times at its target rendering resolution, and repeat after 15
minutes. Removing zero-alpha draws does not establish a measured GPU speedup.
