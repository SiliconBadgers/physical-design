# Pick a track

Each track runs the flow with one set of tools and lives in its own folder under `tracks/`: its flow scripts, its config and constraint files for each design, and its pages in `track/`. The RTL and testbenches in `designs/` at the repo root are shared.

| Track | Tools | Folder |
|---|---|---|
| A | open-source | [`tracks/a`](a/track/README.md) |
| B1 | Cadence | [`tracks/b1`](b1/track/README.md) |
| B2 | Synopsys | [`tracks/b2`](b2/track/README.md) |

Run every command from your track's folder; build output goes to its `build/` folder:

```
cd tracks/a           # or tracks/b1, tracks/b2
```

Setup and commands: `track/README.md` in that folder ([Track A](a/track/README.md), [Track B1](b1/track/README.md), [Track B2](b2/track/README.md)).

Back: [README.md](../README.md)
