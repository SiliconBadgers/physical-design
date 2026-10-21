# Pick a track

Each track runs the flow with one set of tools and lives in its own folder under `flows/`: its flow scripts, its config and constraint files for each design, and its pages in `track/`. The RTL and testbenches in `flows/designs/` are shared.

| Track | Tools | Folder |
|---|---|---|
| A | open-source | [`flows/open`](open/track/README.md) |
| B1 | Cadence | [`flows/cadence`](cadence/track/README.md) |
| B2 | Synopsys | [`flows/synopsys`](synopsys/track/README.md) |

Run every command from your track's folder; build output goes to its `build/` folder:

```
cd flows/open           # or flows/cadence, flows/synopsys
```

Setup and commands: `track/README.md` in that folder ([Track A](open/track/README.md), [Track B1](cadence/track/README.md), [Track B2](synopsys/track/README.md)).

Back: [README.md](README.md)
