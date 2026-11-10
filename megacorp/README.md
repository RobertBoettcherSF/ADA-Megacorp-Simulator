# Megacorp Simulator 0.5.0

Headless Ada core for Megacorp Simulator. Version 0.5.0 adds A*
pathfinding on the city map (design items 1–5). Later packages are
still specs. FreeSynd stays elsewhere in the repository as a logic
reference and is not built here.

A browser page draws maps the Ada program has already exported. It
does not run the simulation. After this branch is on `master`:

<https://raw.githack.com/RobertBoettcherSF/ADA-Megacorp-Simulator/master/web/index.html>

The design, including Robert's decisions of 10 November 2026, is
[`../docs/DESIGN.md`](../docs/DESIGN.md).

## Requirements

- GNAT 12.3 (`gnat` / `gcc-12` reporting `12.3`)
- gprbuild
- Linux x86_64, for the binary the script packages

The executable links against the GNAT 12 runtime (`libgnat-12` and
`libgnarl-12`). `Ada.Real_Time` pulls in the tasking runtime library.
The core creates no tasks and no protected objects.

On Ubuntu 24.04 the 12.3 compiler is the original noble package
`gnat-12=12.3.0-17ubuntu1` (the noble-updates package is 12.4). Pin
`gcc-12`, `cpp-12`, `libgcc-12-dev`, `gcc-12-base`, and `libgnat-12`
to `12.3.0-17ubuntu1` as well. gprbuild itself may be linked with a
newer runtime; it still drives GNAT 12.3 when that compiler is the
`gnat` on `PATH`.

## Build and run

From this directory:

```sh
./build.sh
```

That builds with `gprbuild -P megacorp.gpr -p`, regenerates the
tileset with `tools/gen_tileset.py`, runs `bin/megacorp` and
`bin/megacorp_smoke`, and rewrites `../web/data/` from the Ada map
export, including precomputed walk and drive paths. It also writes
`dist/megacorp_v0.5.0.zip` for local use; that archive is not a
deliverable.

The same steps by hand:

```sh
gprbuild -P megacorp.gpr -p
./bin/megacorp
./bin/megacorp_smoke
```

`megacorp.gpr` builds the static library (`megacorp_lib.gpr`) and both
executables. `bin/megacorp` prints the version, the generator
parameters, and a text sample of seed 42. `bin/megacorp --export DIR`
writes `index.json` and one JSON map per fixed seed (1, 42, 100).
`bin/megacorp_smoke` exits 0 when the smoke checks pass.

Assertions and contracts are compiled in. Warnings and GNAT style
checks are errors. The switch list is `switches.gpr`:

- `-gnat2012` Ada 2012
- `-gnata` assertions, preconditions, postconditions, type invariants
- `-gnato` overflow checks
- `-gnatwa` warnings
- `-gnatwe` warnings and style checks are errors
- `-gnaty` GNAT style
- `-g` debug information

## Package

Build products (`obj/`, `lib/`, `bin/`) are not committed. The
exported JSON under `web/data/` is committed so the page can be opened
without a local build.

## What 0.5.0 contains

Real code: version, generator parameters (defaults 4 corporations,
40 regions, 128 by 128 city maps), the play-mode re-roll rule, a
monotonic clock, a log, `Megacorp.RNG`, and `Megacorp.Map`.

The RNG is xoshiro256\*\* seeded by SplitMix64. Child streams come
from the parent seed and a key (world, region, city, block, mission).

The map is one city. Each tile stores terrain, height, and walkable
and drivable flags. `Test_Layout` fills a road grid, pavement,
building blocks, and a river from the city-1 child of the given seed.
That layout is a stand-in until the city-block generator.

`Megacorp.Data.Virtual_FS` reads logical paths. The disk backend is
`Virtual_FS.Native`. `Megacorp.Assets.Placeholder` loads
`web/assets/tiles.json` through that interface and maps terrain plus
height to a tile id. The pictures are original, produced by
`tools/gen_tileset.py`. See `web/assets/LICENCE.txt`.

`Megacorp.Path` is A* with integer costs (10 orthogonal, 14 diagonal).
Walk uses the walkable flag. Drive uses the drivable flag. A diagonal
step is refused when it would cut a blocked corner. The result is a
tile list, `No_Path`, or `Budget_Exceeded`. Tie-breaking is fixed, so
the same query repeats the same path.

`web/index.html` draws the exported seeds. Flat view is one colour per
terrain. Isometric view uses the atlas and the exported tile id, back
to front, with building stacks. Each seed includes Ada-computed walk
and drive paths, plus a walk into the river that has no path. The
page only draws those paths. Zoom and hover work in both views.

Shells only, for later items: `Types`, `Assets`,
`Assets.Placeholder`, `Data.Virtual_FS`, `World`, `World.Gen`,
`Map.Gen`, `Path`, `Peds`, `Actions`, `Behaviour`, `Weapons`, `Shots`,
`Vehicles`, `Mission`, `Mission.Gen`, `Agents`, `Research`, `Session`,
`Save`, `API`. There is no Syndicate asset package.

## Licence

GPL-2-or-later. See `COPYING`. The setting and the art are original.
The choice between GPL-2-only and GPL-2-or-later is still open in the
design; these headers follow FreeSynd's "or later" file headers until
that is closed.
