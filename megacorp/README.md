# Megacorp Simulator 0.2.0

Headless Ada core for Megacorp Simulator. Version 0.2.0 is the
skeleton plus a deterministic RNG (design items 1 and 2). Later
packages are still specs. FreeSynd stays elsewhere in the repository
as a logic reference and is not built here.

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

That configures nothing, builds with `gprbuild -P megacorp.gpr -p`,
runs `bin/megacorp` and `bin/megacorp_smoke`, and writes
`dist/megacorp_v0.2.0.zip`.

The same steps by hand:

```sh
gprbuild -P megacorp.gpr -p
./bin/megacorp
./bin/megacorp_smoke
```

`megacorp.gpr` builds the static library (`megacorp_lib.gpr`) and both
executables. `bin/megacorp` prints the version and the generator
parameters. `bin/megacorp_smoke` exits 0 when the smoke checks pass.

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

`dist/megacorp_v0.2.0.zip` contains the sources and the Linux x86_64
binaries `bin/megacorp` and `bin/megacorp_smoke`. Build products
(`obj/`, `lib/`, `bin/`) are not committed.

## What 0.2.0 contains

Real code: version, generator parameters (defaults 4 corporations,
40 regions, 128 by 128 city maps), the play-mode re-roll rule, a
monotonic clock, a log, and `Megacorp.RNG`.

The RNG is xoshiro256\*\* seeded by SplitMix64. Child streams come
from the parent seed and a key (world, region, city, block, mission),
so re-deriving one region does not move any other stream. Draws are
unbiased integers, a boolean with a rational probability, an integer
picked from a range, and a Fisher-Yates shuffle. Reference vectors
are in `docs/DESIGN.md`.

Shells only, for later items: `Types`, `Assets`,
`Assets.Placeholder`, `Data.Virtual_FS`, `World`, `World.Gen`, `Map`,
`Map.Gen`, `Path`, `Peds`, `Actions`, `Behaviour`, `Weapons`, `Shots`,
`Vehicles`, `Mission`, `Mission.Gen`, `Agents`, `Research`, `Session`,
`Save`, `API`. There is no Syndicate asset package.

## Licence

GPL-2-or-later. See `COPYING`. The setting and the art are original.
The choice between GPL-2-only and GPL-2-or-later is still open in the
design; these headers follow FreeSynd's "or later" file headers until
that is closed.
