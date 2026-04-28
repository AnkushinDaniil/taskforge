# TaskForge

A local task tracker built as four Delphi binaries from a single repository:

| Binary | Purpose |
| --- | --- |
| `TaskForge.Worker.exe` | Background worker — scans overdue tasks, publishes events |
| `TaskForge.Api.exe` | Indy-based REST API + SSE event stream |
| `TaskForge.Admin.exe` | VCL admin client (master-detail, dark-mode) |
| `TaskForge.Tests.exe` | DUnitX runner — unit + integration tests |

E2E tests (`tests/e2e/`) drive the real binaries from PowerShell.

---

## Repository layout

```
src/
  Core/    shared library (compiled into each exe)
  Worker/  background worker
  Api/     REST + SSE
  Admin/   VCL client
  Tests/   DUnitX project
migrations/  SQL files embedded as resources
tests/e2e/   PowerShell E2E orchestrator + scenarios
build.bat    invokes dcc64 directly
test.bat     build → unit/integration → e2e
```

---

## Required RAD Studio components

- **Delphi 11.3 (Alexandria) or Delphi 12 (Athens)**, **Pro edition or
  higher**. Pro ships with FireDAC, Indy, VCL Styles, and DUnitX —
  everything we use.
- **Community Edition** can compile this code in the IDE for non-
  commercial use, but it does not grant rights to distribute the
  resulting binaries. Building from the command-line with `dcc64` works
  on Community in our testing, but read the licence yourself.
- **No third-party libraries are required.** The plan originally called
  for `TVirtualStringTree`; we shipped with the built-in `TListView` to
  keep the build self-contained. Swap to VirtualTreeView via GetIt if
  you want virtualisation past ~10k rows.

### Files needed from a RAD Studio install

The `build.bat` shells out to `dcc64.exe` and depends on:

- `bin\rsvars.bat` (sets `BDS`, `PATH`, library search paths)
- `bin\dcc64.exe` (the 64-bit command-line compiler)
- `lib\Win64\release\*.dcu` for `System.*`, `Vcl.*`, `Winapi.*`,
  `Data.*`, `Data.Win.*`, `FireDAC.*`, `IdGlobal.*`, `IdHTTPServer.*`,
  `DUnitX.*`
- `bin\rc.exe` (or any Windows SDK `rc.exe` on PATH) for compiling
  `migrations.rc → migrations.res`

The build script auto-locates RAD Studio 11 (`Studio\22.0`) or 12
(`Studio\23.0`). Override by setting `BDS` before invoking it.

---

## What is impossible without a paid Delphi licence

Be explicit:

- `dcc64.exe` and the FireDAC/Indy/VCL `.dcu` libraries are **not
  redistributable**. There is no FOSS replacement that produces
  byte-equivalent binaries from this source.
- The Admin client uses VCL — VCL is **Windows-only** and bundled with
  RAD Studio. There is no cross-platform compile path for it.
- macOS and Linux developers can read and edit the source, but
  **cannot build the binaries** without a Windows host with RAD Studio
  installed.

---

## Building

### If you have Delphi 12 Pro / Enterprise / Architect

`build.bat` works directly from `cmd.exe`. It calls `dcc64` for each
`.dpr` and `brcc32` for the resource files, dropping all four EXEs in
`bin\`:

```cmd
build.bat
```

### If you have Delphi 12 Community Edition (free)

**Important — CE blocks command-line compilation.** Direct `dcc64`,
`MSBuild` via the Delphi targets, and `bds.exe -b` headless mode all
return:

```
This version of the product does not support command line compiling.
```

This is intentional Embarcadero policy in CE; no script can route
around it. `build.bat` will fail at the `dcc64` step on a CE install.

**The CE workflow is IDE-driven**:

1. Open Delphi 12 (Start menu → **Embarcadero RAD Studio 12** → **Delphi 12**).
2. Register your CE serial when prompted (one-time, on first launch).
3. **File → Open Project** → pick a `.dproj` from `src\Worker\`,
   `src\Api\`, `src\Admin\`, or `src\Tests\`.
4. **Project → Build** (or `Shift+F9`). Output lands in `bin\`.
5. Repeat for the other three projects.

After all four are built, the binaries themselves run without any
licence check — `test.bat` (or its individual phases) drives them
normally from `cmd.exe` or over SSH.

When source changes, you only need to rebuild the affected `.dproj` in
the IDE. Non-Pascal changes (build script, `.ini`, `.ps1`, `.sql`,
README, migrations) require no rebuild.

### Output

```
bin\
├── TaskForge.Worker.exe
├── TaskForge.Api.exe
├── TaskForge.Admin.exe
└── TaskForge.Tests.exe
```

---

## Testing

Two layers, by where they run:

| Layer | Runs in | Cost | Catches |
| --- | --- | --- | --- |
| **Lint** (`.github/workflows/ci.yml`) | GitHub Actions, free Linux runners | $0, auto on push/PR | structural drift, SQL parse errors, PowerShell parse errors, malformed `.dproj`, `.pas`/file-name mismatches, no SQL string-concat, no absolute local paths |
| **Build + Unit + Integration + E2E** (`test.bat`) | Local Windows machine or VM with Delphi 12 CE installed | $0 (CE is free for individuals + small orgs) | actual Delphi compile errors, runtime correctness across the worker / API / IPC stack |

### Running the full suite locally (macOS host)

The Delphi compiler (`dcc64`) and FireDAC/Indy/VCL libraries are
Windows-only. To run the full suite on a Mac you need a Windows VM —
this is genuinely free, takes ~2 hours of setup once, and runs
indefinitely.

#### Apple Silicon (M1 / M2 / M3 / M4) — UTM + Windows 11 ARM

```bash
brew install --cask utm
```

1. In UTM: **Create a new Virtual Machine → Virtualize → Windows**.
   UTM offers to download the official Windows 11 ARM installer.
2. After Windows is up, install **Delphi 12 Community Edition** —
   register at https://www.embarcadero.com/products/delphi/starter
   (free per-developer licence, annual renewal still free). x64
   `dcc64.exe` runs under Microsoft's built-in x64-on-ARM emulation.
3. In UTM: **Settings → Sharing → Directory Share** → point to the
   `taskforge/` folder on your Mac. Inside Windows it appears at
   `\\Mac\Home\…` or via the mounted SPICE drive.

#### Intel Mac — VirtualBox + Windows 11

```bash
brew install --cask virtualbox
```

1. Download Windows 11 ISO from microsoft.com.
2. Create a Windows 11 VM in VirtualBox (8 GB RAM, 60 GB disk
   recommended). Run unactivated indefinitely — the only cosmetic
   limitations are a watermark and a locked wallpaper.
3. Install Delphi 12 Community Edition (same link as above).
4. Use **Devices → Shared Folders** to expose `taskforge/` to the VM.

#### Inside the Windows VM, once Delphi is installed

Open a `cmd.exe` shell in the repo directory:

```cmd
build.bat                                         REM compile all 4 EXEs
test.bat                                          REM build → unit → integration → e2e
```

Or run a single layer when isolating a failure:

```cmd
bin\TaskForge.Tests.exe -include:Tests.Unit.*        -exit:Continue
bin\TaskForge.Tests.exe -include:Tests.Integration.* -exit:Continue
powershell -NoProfile -ExecutionPolicy Bypass -File tests\e2e\run_e2e.ps1 -Bin .\bin
powershell -File tests\e2e\scenarios\03_overdue_sse_stream.ps1 -Bin .\bin
```

### What CI does *not* catch

The lint workflow is fast and zero-cost but cannot prove that Pascal
code compiles. Any change that touches `.pas`, `.dpr`, `.dproj`, or the
`migrations.rc` resource scripts must be verified locally on the
Windows VM before merging. Lint is a regression net for the
non-Pascal parts; it is not a green light to ship.

---

## Configuration

Each binary reads `config.ini` from its working directory. Every key has
an environment-variable override (used by E2E for isolation):

| INI                                  | Env var                          |
| ------------------------------------ | -------------------------------- |
| `[storage] db_path`                  | `TASKFORGE_DB_PATH`              |
| `[api] port`                         | `TASKFORGE_API_PORT`             |
| `[ipc] pipe_name`                    | `TASKFORGE_PIPE_NAME`            |
| `[worker] scan_interval_sec`         | `TASKFORGE_SCAN_INTERVAL_SEC`    |
| `[worker] pool_size`                 | `TASKFORGE_POOL_SIZE`            |
| `[worker] queue_capacity`            | `TASKFORGE_QUEUE_CAPACITY`       |

---

## Known weaknesses

See [`docs/PLAN.md`](docs/PLAN.md) for the full architectural plan and a
detailed weaknesses list. Honest summary of APIs most likely to need
verification against the official Embarcadero docs before shipping:

- Indy SSE streaming via `AContext.Connection.IOHandler` after
  `AResponseInfo.WriteHeader` — pattern is plausible but Indy versions
  vary in how aggressively they auto-close. Verify against
  `IdHTTPServer.pas` before relying on it under load.
- `TFDScript` accepting multi-statement SQLite scripts split by `;`.
- `TStyleManager.TrySetStyle('Windows10 Dark')` — exact style name
  varies between Delphi versions. Inspect `TStyleManager.StyleNames` at
  runtime if the toggle does nothing.
- Named-pipe overlapped I/O semantics for graceful drop-on-slow-consumer
  — current implementation is synchronous and back-pressures the worker
  via a bounded queue, which is good enough for the local single-machine
  use case but won't tolerate a wedged API.
- DUnitX `[Ignore]` attribute syntax — see `Tests.Integration.Sse.pas`.
- PowerShell delivering a real Ctrl+C to a console child — scenario
  `05_worker_graceful_shutdown.ps1` uses `taskkill` without `/F`, which
  delivers `WM_CLOSE`; the Pascal handler treats that as a graceful
  shutdown signal, but a true `CTRL_C_EVENT` test would need a
  P/Invoke `GenerateConsoleCtrlEvent` helper.

When something doesn't compile or behave as written, the bug is almost
certainly in one of the items above — start there.
