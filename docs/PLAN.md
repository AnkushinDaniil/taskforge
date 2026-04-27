# TaskForge — Delphi 11/12 Athens Multi-Binary Project Plan

## Context

The user wants a fully compilable, idiomatic-2026 Delphi project with **four
binaries from one repo**: Core library, console worker, Indy REST API, VCL
admin client, plus DUnitX tests. The spec is opinionated and prescribes the
architecture (custom RTTI attributes, generic repository, advanced-record
`Result<T>`, hand-rolled thread pool, attribute-routed Indy server, SSE,
IPC). The plan's job is to (a) translate the spec into a concrete directory
tree and per-file responsibilities, (b) pick 2026-current Delphi idioms
(managed records, inline vars, `class operator`, `TThreadedQueue<T>`, VCL
Styles dark mode), (c) be honest about which APIs need human verification.

> **macOS reality check**: this conversation is running on Darwin. `dcc64`
> ships only with RAD Studio on Windows. The plan produces a buildable
> source tree and a `build.bat`; the binaries themselves can only be
> produced on a Windows host with a paid RAD Studio Pro+ license. No part of
> this plan can be executed end-to-end here. Compilation must be verified on
> Windows.

---

## Architecture overview

Five Delphi project files (`.dpr/.dproj`) sharing one runtime package-free
core library compiled as units:

| Binary                     | Type                     | Depends on Core | Notes                              |
| -------------------------- | ------------------------ | --------------- | ---------------------------------- |
| `TaskForge.Core`           | unit collection (no exe) | —               | Compiled directly into each exe    |
| `TaskForge.Worker.exe`     | console                  | yes             | Custom thread pool, JSON logging   |
| `TaskForge.Api.exe`        | console                  | yes             | Indy server, attribute router, SSE |
| `TaskForge.Admin.exe`      | VCL                      | yes             | Master-detail, MVVM helper         |
| `TaskForge.Tests.exe`      | DUnitX console           | yes             | Repository, Result<T>, JSON, pool  |

**Communication topology**

```
+----------------+   named pipe   +------------+   SSE   +----------+
|  Worker.exe    |--------------->|  Api.exe   |-------->| Browser /|
|  (producer)    |  TTaskOverdue  |  (relay)   |         | curl     |
+----------------+   JSON lines   +------------+         +----------+
        |                                |
        v                                v
   SQLite (FireDAC, shared file, WAL mode)
```

**IPC choice — named pipe (justified)**: only one consumer (the API), so a
single `TPipe` is simpler than a memory-mapped ring buffer. Pipe is in
**message mode** (`PIPE_TYPE_MESSAGE`), each event is one JSON line. Worker
is server, API is client; API reconnects on EOF. MMF would be needed only
if we expected multiple API instances or non-Windows portability — neither
is required.

**VCL grid choice — `TVirtualStringTree` (justified)**: virtualised model
keeps memory flat at 100k+ tasks, native VCL Styles support is excellent,
column sort/header drag are first-class. Open-source (BSD/MPL), installed
via GetIt Package Manager — **not paid, but not built-in**, so `build.bat`
must add its source path to `dcc64 -U`. If the user prefers zero
third-party deps, swap to `TListView` in `vsReport` mode (works but won't
scale past ~10k rows comfortably).

---

## Directory tree

```
taskforge/
├── README.md
├── build.bat
├── .gitignore
├── bin/                          # output (gitignored)
├── packages/
│   └── VirtualTreeView/          # vendored or referenced via env var
├── src/
│   ├── Core/
│   │   ├── TaskForge.Core.Attributes.pas
│   │   ├── TaskForge.Core.Result.pas
│   │   ├── TaskForge.Core.EventBus.pas
│   │   ├── TaskForge.Core.Logging.pas
│   │   ├── TaskForge.Core.Config.pas
│   │   ├── TaskForge.Core.Json.pas
│   │   ├── TaskForge.Core.Rtti.pas
│   │   ├── TaskForge.Core.Repository.pas
│   │   ├── TaskForge.Core.Migrations.pas
│   │   ├── TaskForge.Core.Domain.Tasks.pas
│   │   └── TaskForge.Core.Ipc.NamedPipe.pas
│   ├── Worker/
│   │   ├── TaskForge.Worker.dpr
│   │   ├── TaskForge.Worker.dproj
│   │   ├── TaskForge.Worker.ThreadPool.pas
│   │   ├── TaskForge.Worker.OverdueJob.pas
│   │   ├── TaskForge.Worker.Pipe.pas
│   │   ├── TaskForge.Worker.Signals.pas
│   │   └── config.ini
│   ├── Api/
│   │   ├── TaskForge.Api.dpr
│   │   ├── TaskForge.Api.dproj
│   │   ├── TaskForge.Api.Server.pas
│   │   ├── TaskForge.Api.Router.pas
│   │   ├── TaskForge.Api.Controllers.Tasks.pas
│   │   ├── TaskForge.Api.Controllers.Events.pas
│   │   ├── TaskForge.Api.Sse.pas
│   │   ├── TaskForge.Api.ETag.pas
│   │   └── config.ini
│   ├── Admin/
│   │   ├── TaskForge.Admin.dpr
│   │   ├── TaskForge.Admin.dproj
│   │   ├── TaskForge.Admin.Main.pas       # + .dfm
│   │   ├── TaskForge.Admin.ViewModels.pas
│   │   ├── TaskForge.Admin.HttpClient.pas
│   │   ├── TaskForge.Admin.Mvvm.pas
│   │   └── TaskForge.Admin.Theme.pas
│   └── Tests/
│       ├── TaskForge.Tests.dpr            # DUnitX runner — unit + integration
│       ├── TaskForge.Tests.dproj
│       ├── Unit/
│       │   ├── Tests.Unit.Result.pas
│       │   ├── Tests.Unit.Json.pas
│       │   ├── Tests.Unit.ThreadPool.pas
│       │   ├── Tests.Unit.Attributes.pas
│       │   ├── Tests.Unit.Config.pas
│       │   └── Tests.Unit.Router.pas
│       ├── Integration/
│       │   ├── Tests.Integration.Migrations.pas
│       │   ├── Tests.Integration.Repository.pas
│       │   ├── Tests.Integration.HttpServer.pas
│       │   ├── Tests.Integration.Sse.pas
│       │   └── Tests.Integration.Pipe.pas
│       └── Support/
│           ├── Tests.Support.Db.pas       # :memory: SQLite fixture helper
│           ├── Tests.Support.Http.pas     # in-process Indy host helper
│           └── Tests.Support.Ports.pas    # ephemeral-port allocator
├── tests/
│   └── e2e/
│       ├── run_e2e.ps1                    # PowerShell orchestrator (Win)
│       ├── run_e2e.cmd                    # cmd.exe wrapper for run_e2e.ps1
│       ├── scenarios/
│       │   ├── 01_create_list_get.ps1
│       │   ├── 02_optimistic_lock_409.ps1
│       │   ├── 03_overdue_sse_stream.ps1
│       │   ├── 04_etag_304.ps1
│       │   └── 05_worker_graceful_shutdown.ps1
│       └── lib/
│           ├── Assert.psm1                # tiny assertion helpers
│           └── Bin.psm1                   # spawn/kill/health-check helpers
├── test.bat                               # orchestrator: unit→integration→e2e
└── migrations/
    ├── 0001_init.sql
    └── 0002_add_version_column.sql       # for optimistic locking
```

`migrations/*.sql` is embedded via a `.rc`/`.res` step in each binary that
needs the schema (Worker + Api). See `Migrations` section below.

---

## Per-area design

### 1. Shared Core (`TaskForge.Core.*`)

- **`Attributes.pas`** — declares `TableAttribute`, `ColumnAttribute`,
  `JsonNameAttribute`, `JsonIgnoreAttribute`, `PrimaryKeyAttribute`,
  `RouteAttribute`. All inherit from `TCustomAttribute`. Single-property
  constructors so `[Table('tasks')]` syntax works.
- **`Result.pas`** — advanced record:
  ```pascal
  Result<T> = record
    class function Ok(const V: T): Result<T>; static;
    class function Err(const Msg: string; Code: Integer = 0): Result<T>; static;
    function IsOk: Boolean;
    function Unwrap: T;                        // raises EResultUnwrap if Err
    function UnwrapOr(const Default: T): T;
    function ErrorMessage: string;
    class operator Implicit(const V: T): Result<T>;
    class operator Equal(const A, B: Result<T>): Boolean;
  end;
  ```
  Stores `FState: (rsOk, rsErr)`, `FValue: T`, `FError: string`,
  `FCode: Integer`. No exceptions for control flow inside business code.
  `EResultUnwrap` is the only exception, and only `Unwrap` raises it.
- **`EventBus.pas`** — `TEventBus = class(TInterfacedObject, IEventBus)`
  with internal `TDictionary<PTypeInfo, TList<TProc<TValue>>>` guarded by
  `TMonitor.Enter(Self)`. `Subscribe<T>(handler: TProc<T>)` wraps the
  typed proc in a `TProc<TValue>` thunk. `Publish<T>(const Event: T)`
  copies the subscriber list under the monitor, then dispatches outside
  the lock to avoid handler→Publish reentrancy deadlocks.
- **`Logging.pas`** — `TJsonLogger` writes one JSON line per call to
  stdout. Uses `System.JSON.TJSONObject` (avoid TJSONWriter quirks). Adds
  ISO-8601 UTC timestamp, `level`, `msg`, plus a `TArray<TPair<string,
  TValue>>` context. Thread-safe via a `TLightweightMREW`.
- **`Config.pas`** — `TConfig.Load(const IniPath: string): TConfig`. Each
  property reads `TIniFile.ReadString(...)`, then `GetEnvironmentVariable`
  overrides if set. Unknown env vars fall back to ini default.
- **`Json.pas` + `Rtti.pas`** — pair of helpers driven by the same
  attributes used for SQL mapping. `TJsonMapper.ToJson<T>(const Rec: T):
  TJSONObject` and `TJsonMapper.FromJson<T>(const Obj: TJSONObject): T`.
  Honours `[JsonName]` for renaming, skips `[JsonIgnore]`, and supports
  the primitive types used by `TTask` (string, Integer, TDateTime, Boolean,
  Nullable<T>).
- **`Repository.pas`** — `TRepository<T: record>` with:
  `function GetById(Id: Int64): Result<T>;`
  `function List(const Filter: TQueryFilter): Result<TArray<T>>;`
  `function Insert(const Rec: T): Result<Int64>;`
  `function Update(const Rec: T; ExpectedVersion: Integer): Result<Boolean>;`
  `function Delete(Id: Int64): Result<Boolean>;`
  Internally uses `TFDQuery` with `Params.ParamByName(...)` — never string
  concatenation. SQL is built from RTTI by reading `[Table]` and column
  attributes. Update bumps `version` and returns `Ok(False)` on
  optimistic-lock conflict (mapped to HTTP 409 by the API layer).
- **`Migrations.pas`** — `TMigrationRunner.Run(const Conn: TFDConnection)`.
  Looks for embedded RT_RCDATA resources named `MIGRATION_NNNN`, sorts
  numerically, opens a transaction per migration, executes the SQL via
  `TFDScript`, then writes to `schema_version(version, applied_at)`.
- **`Domain.Tasks.pas`** — the `TTask` record:
  ```pascal
  [Table('tasks')]
  TTask = record
    [PrimaryKey][Column('id')]      Id: Int64;
    [Column('title')]               Title: string;
    [Column('status')]              Status: TTaskStatus;
    [Column('due_at')][JsonName('due_at')] DueAt: TDateTime;
    [Column('version')][JsonIgnore] Version: Integer;
    [Column('created_at')][JsonName('created_at')] CreatedAt: TDateTime;
  end;
  ```
- **`Ipc.NamedPipe.pas`** — `TPipeServer` (worker side, accepts one client,
  writes line-delimited JSON) and `TPipeClient` (API side, blocking read
  with reconnect). Built on raw Win32: `CreateNamedPipeW`,
  `ConnectNamedPipe`, `WriteFile`, `ReadFile`. Pipe name
  `\\.\pipe\TaskForge.Events`.

### 2. Persistence

- FireDAC connection in WAL mode (`PRAGMA journal_mode=WAL`) so reads in
  the API don't block writes in the Worker on the same DB file.
- `TFDPhysSQLiteDriverLink` is added once globally per process.
- Connection string is built from config: `Database=...`, `OpenMode=CreateUTF8`,
  `LockingMode=Normal`, `Synchronous=Normal`.
- Each repository call creates a short-lived `TFDQuery` owned via
  `try…finally Free` (or `IInterface`-wrapped helper). No global query
  reuse across threads.

### 3. Worker

- **`Signals.pas`** — `SetConsoleCtrlHandler` installs a callback that
  signals a global `TEvent`. Main loop awaits `Event.WaitFor(JobInterval)`;
  on signal, drains the pool gracefully (`Pool.Shutdown(WaitMs := 5000)`).
- **`ThreadPool.pas`** — fixed `N` `TThread` workers + a
  `TThreadedQueue<TProc>` (bounded). `Submit` blocks (or returns false)
  when full. `Shutdown` posts `N` poison pills and joins. Implemented on
  raw `TThread` per spec — `TTask` is not used.
- **`OverdueJob.pas`** — every `Config.ScanIntervalSec`, queries
  `SELECT id, title, due_at FROM tasks WHERE status='open' AND due_at < ?`,
  publishes `TTaskOverdue` per row to the event bus and to the pipe server.
- **`Pipe.pas`** — pipe server wrapper that subscribes to the bus and
  writes events as JSON lines. Drops on slow consumer rather than blocking
  the worker.

### 4. API

- **`Server.pas`** — wraps `TIdHTTPServer`, binds port from config,
  installs `OnCommandGet` → forwards to router.
- **`Router.pas`** — at startup, scans registered controller classes via
  RTTI, finds methods decorated with `[Route('GET','/tasks/{id}')]`,
  precompiles a regex per route, builds a dispatch table. On request,
  matches method+path, extracts `{id}` named groups into a
  `TDictionary<string,string>`, and invokes the controller method via
  `TRttiMethod.Invoke`.
- **`Controllers.Tasks.pas`** — `TTasksController` with `List`, `Get`,
  `Create`, `Patch`, `Delete`. Uses `TJsonMapper` for body→record→JSON
  round-trips, the repository for storage. Returns 200/201/204/400/404/409
  as appropriate.
- **`Sse.pas`** — `TSseStream` writes `event:` / `data:` lines, flushes
  per event. `TIdHTTPServer`'s response context lets you write to
  `AContext.Connection.IOHandler.Write(...)` directly while keeping the
  socket open. **(Verify this against Indy 10's documented streaming
  behaviour — see Known weaknesses.)**
- **`Controllers.Events.pas`** — `GET /events`. Sets
  `Content-Type: text/event-stream`, `Cache-Control: no-cache`. Connects
  to the worker's pipe, reads JSON lines, forwards each as one SSE event.
- **`ETag.pas`** — computes ETag as `W/"<id>-<version>"`. On `GET /tasks/{id}`,
  returns 304 if `If-None-Match` matches.

### 5. Admin (VCL)

- **`Mvvm.pas`** — minimal MVVM: `TObservable<T> = class` with `OnChanged:
  TProc<T>`, plus `TBindings.BindList(Source: TObjectList<TVM>; Tree:
  TVirtualStringTree)` that wires `OnGetText`/`OnInitNode` from VM
  properties. No third-party MVVM lib.
- **`HttpClient.pas`** — `TApiClient` wraps `TNetHTTPClient`. Each call
  runs on a `TThread.CreateAnonymousThread`, with a shared
  `TCancellationToken` (a `TEvent` plus cooperative checks). Form's
  `FormCloseQuery` signals the token and joins.
- **`ViewModels.pas`** — `TTaskVM = class` mirrors `TTask` plus UI-only
  fields (`IsDirty`, `IsLoading`).
- **`Main.pas/.dfm`** — VirtualStringTree on the left (list), DetailPanel
  on the right (TEdit/TDateTimePicker/TComboBox bound to selected VM). A
  `TEdit` for filter + `TTimer(Interval=250)` debounce. Toolbar with
  "Light/Dark" toggle calling `TStyleManager.SetStyle('Windows10 Dark')`.
- **`Theme.pas`** — registers two styles at startup, persists choice in
  `HKCU\Software\TaskForge\Theme`.

### 6. Testing strategy — three explicit layers

Spec called for DUnitX coverage of `Result<T>`, repository CRUD, JSON
round-trip, and pool shutdown. We exceed that with a layered pyramid:
**unit → integration → e2e**, each runnable independently and chained by
`test.bat`.

#### Layer 1 — Unit (DUnitX, `[TestFixture]` per file, no I/O)

Pure-CPU tests, milliseconds each, target ~80% line coverage of Core.

- `Tests.Unit.Result.pas` — Ok/Err round-trip, `Implicit`, `Equal`,
  `UnwrapOr`, `Unwrap` raises `EResultUnwrap` on Err, default-init record
  is treated as Err.
- `Tests.Unit.Json.pas` — `TTask` round-trip preserves `[JsonName]` keys,
  `[JsonIgnore]` fields are absent on serialise and ignored on
  deserialise, missing optional fields decode to defaults, malformed
  JSON returns `Result.Err`.
- `Tests.Unit.ThreadPool.pas` — submit 1000 jobs, request shutdown,
  assert all completed within timeout, no jobs lost, pool refuses new
  work after shutdown, bounded queue back-pressures `Submit` when full,
  poison-pill drain in order.
- `Tests.Unit.Attributes.pas` — RTTI returns expected attributes for
  `TTask`, `[Column]` name overrides field name, `[PrimaryKey]` exactly
  one per record (assertion).
- `Tests.Unit.Config.pas` — env var overrides ini, missing key falls
  back to default, type coercion (`Integer`/`Boolean`) works.
- `Tests.Unit.Router.pas` — route regex extracts `{id}` correctly,
  collision detection (two routes match same path) raises at startup,
  unknown method/path returns 404 sentinel.

#### Layer 2 — Integration (DUnitX, real subsystems, in-process)

Spin up real FireDAC/Indy/pipe inside the test runner; no separate exe.

- `Tests.Integration.Migrations.pas` — fresh `:memory:` DB, runs all
  embedded migrations, `schema_version` rows match resource count, idem-
  potent on re-run.
- `Tests.Integration.Repository.pas` — `:memory:` SQLite, full
  insert→get→update→delete cycle, optimistic-lock collision returns
  `Ok(False)`, parameter binding rejects SQL-injection attempt
  (`title := "');DROP TABLE tasks;--"` survives unscathed and round-trips
  as a literal).
- `Tests.Integration.HttpServer.pas` — boots `TIdHTTPServer` on an
  ephemeral port (helper in `Tests.Support.Ports.pas`), drives via
  `TIdHTTP` client through the **real router and controllers** against
  an `:memory:` repo. Asserts: 201 on POST, Location header, 200 on
  GET, 404 on missing, 409 on stale `If-Match`, 304 on matching ETag.
- `Tests.Integration.Sse.pas` — same in-process Indy host, opens
  `/events` with a chunked-reader, publishes one `TTaskOverdue`
  in-process via the bus, asserts the SSE frame arrives within 500 ms
  with the expected `event:` and `data:` lines.
- `Tests.Integration.Pipe.pas` — `TPipeServer` and `TPipeClient` in
  separate threads of the same process, server writes 10k JSON lines,
  client reads them in order, no truncation across boundaries.
- `Tests.Support.*` — shared fixtures: a `TDbFixture` that creates a
  unique `:memory:` connection per test, a `THttpFixture` that wires
  router→controllers→repo without sockets where possible, and
  `TPortAllocator.NextFree` for sockets when needed.

#### Layer 3 — E2E (PowerShell orchestrator, real binaries)

Lives in `tests/e2e/`. Out-of-process; black-box. Each scenario script
spawns `bin\TaskForge.Worker.exe` and `bin\TaskForge.Api.exe` with a
**temp data dir** and **ephemeral port** (the binaries accept
`TASKFORGE_DB_PATH`, `TASKFORGE_API_PORT`, `TASKFORGE_PIPE_NAME` env
vars — added to `Config.pas`), drives them via `Invoke-WebRequest` /
`curl.exe`, asserts on HTTP responses, on JSON log lines captured from
the worker's stdout, and on SSE chunks.

Scenarios:

1. `01_create_list_get.ps1` — create a task, list, get-by-id, delete.
2. `02_optimistic_lock_409.ps1` — two concurrent PATCHes, one returns
   409.
3. `03_overdue_sse_stream.ps1` — insert a task with `due_at` in the
   past, open `/events`, assert `task.overdue` arrives within
   `ScanIntervalSec + 1` second.
4. `04_etag_304.ps1` — GET returns ETag, second GET with `If-None-Match`
   returns 304 with empty body.
5. `05_worker_graceful_shutdown.ps1` — send Ctrl+C (`taskkill /PID
   <pid>` with no `/F`, or `GenerateConsoleCtrlEvent` via P/Invoke
   helper), assert worker emits `"msg":"shutting down"` then exits
   within 5 s with code 0.

Cleanup is per-scenario: each script tracks PIDs and kills children in
`finally`, deletes the temp data dir. `run_e2e.ps1` enumerates
`scenarios/*.ps1`, runs them serially, prints a summary table, exits
non-zero on any failure.

#### Test orchestrator — `test.bat`

```bat
@echo off
setlocal
call build.bat || exit /b 1

echo [1/3] Unit + Integration (DUnitX)
"%~dp0bin\TaskForge.Tests.exe" -exit:Continue -fixturename:* || exit /b 1

echo [2/3] (DUnitX runs unit + integration in one exe; split by fixture filter if needed)

echo [3/3] E2E (PowerShell)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\e2e\run_e2e.ps1" ^
  --bin "%~dp0bin" || exit /b 1

echo All tests passed.
```

Unit and integration share the `TaskForge.Tests.exe` runner because
both are DUnitX; they're separated by folder + fixture-name prefix
(`Tests.Unit.*` vs `Tests.Integration.*`) so DUnitX's `-include` /
`-exclude` flags can run them independently when you want to.

**No GUI E2E for Admin.exe**: Windows UI Automation testing of VCL
windows requires either commercial tools (TestComplete, Ranorex) or a
hand-rolled UIA harness, both out of scope. Admin gets manual smoke
verification only — listed in step 9 of the verification flow.

### 7. `build.bat`

```bat
@echo off
setlocal
if not defined BDS ( call "%PROGRAMFILES(X86)%\Embarcadero\Studio\23.0\bin\rsvars.bat" )
set OUT=%~dp0bin
if not exist "%OUT%" mkdir "%OUT%"

set SRC=%~dp0src
set VTV=%~dp0packages\VirtualTreeView\Source

set COMMON=-Q -B -NSSystem;System.Win;Vcl;Winapi;Data;Data.Win;Data.Win.ADODB;FireDAC ^
  -U"%SRC%\Core" -I"%SRC%\Core" -E"%OUT%" -N"%OUT%\dcu"

dcc64 %COMMON% -U"%SRC%\Worker" "%SRC%\Worker\TaskForge.Worker.dpr"  || goto :err
dcc64 %COMMON% -U"%SRC%\Api"    "%SRC%\Api\TaskForge.Api.dpr"        || goto :err
dcc64 %COMMON% -U"%SRC%\Admin;%VTV%" "%SRC%\Admin\TaskForge.Admin.dpr" || goto :err
dcc64 %COMMON% -U"%SRC%\Tests"  "%SRC%\Tests\TaskForge.Tests.dpr"    || goto :err
echo Build OK
exit /b 0
:err
echo BUILD FAILED & exit /b 1
```

`-NS` (namespace prefixes), `-U` (unit search), `-N` (DCU output), `-E`
(EXE output). Adjust BDS path if RAD Studio is installed elsewhere.

### 8. README

Sections:
1. What this is.
2. Required RAD Studio components: Delphi 11.3+ or 12 Athens, **Pro
   edition or higher** (the IDE itself is paid; FireDAC, Indy, VCL Styles
   ship with Pro). Community Edition is technically usable for non-
   commercial work but lacks command-line `dcc64` redistribution rights.
3. Required files from a RAD Studio install: `rsvars.bat`, `dcc64.exe`,
   `lib\win64\release\*.dcu` (for `System.*`, `Vcl.*`, `Winapi.*`,
   `Data.*`, `IdGlobal.*`, `FireDAC.*`).
4. Steps to install VirtualTreeView via GetIt Package Manager, OR clone
   `JAM-Software/Virtual-TreeView` into `packages/VirtualTreeView`.
5. **Hard truth**: nothing in this project compiles on macOS or Linux.
   `dcc64` is Windows-only. Cross-platform `dccosx64` exists but VCL is
   Windows-only, so the Admin client is Windows-bound regardless.

---

## 2026-current Delphi idioms applied

- `inline var` declarations everywhere (Delphi 10.3+).
- Generic constraints (`class`, `record`, `constructor`) where useful.
- `class operator Implicit/Equal` for `Result<T>`.
- `TThreadedQueue<T>` for the bounded job queue (avoid hand-rolled CV).
- `TLightweightMREW` for low-contention reader-writer locks.
- `TJSONObject.ParseJSONValue` over deprecated `TJSONObject.ParseJSON`.
- VCL Styles for dark mode; runtime switch via `TStyleManager.SetStyle`.
- WAL mode on SQLite for reader/writer concurrency.
- DUnitX `[TestFixture]` / `[Test]` attributes (modern, replaces DUnit).

---

## Critical files to be created (touch list)

All files under `taskforge/` listed in the **Directory tree** above. None
exist yet — this is a true greenfield project.

---

## Verification

All steps **must run on Windows** with RAD Studio installed. Order
matters: build → unit → integration → e2e → manual GUI smoke.

**A. One-shot orchestrated run**

1. `git add . && git commit -m "initial"` (also fixes the `/ultraplan`
   blocker for future runs).
2. From `cmd.exe`: `test.bat`. Expect:
   - `build.bat` produces four EXEs in `bin\`.
   - `TaskForge.Tests.exe` PASS for every `Tests.Unit.*` and
     `Tests.Integration.*` fixture.
   - `run_e2e.ps1` PASS for all five scenarios.
   - Final line: `All tests passed.`

**B. Per-layer manual run (when isolating a failure)**

3. Unit only: `bin\TaskForge.Tests.exe -include:Tests.Unit.*
   -exit:Continue`.
4. Integration only: `bin\TaskForge.Tests.exe
   -include:Tests.Integration.* -exit:Continue`.
5. E2E only: `powershell -File tests\e2e\run_e2e.ps1 --bin .\bin`.
6. Single E2E scenario: `powershell -File
   tests\e2e\scenarios\03_overdue_sse_stream.ps1 --bin .\bin`.

**C. Manual GUI smoke (Admin — not automated)**

7. In one terminal: `bin\TaskForge.Worker.exe`. Expect JSON log lines on
   stdout, `taskforge.db` created, migrations applied.
8. In another terminal: `bin\TaskForge.Api.exe`. Expect `listening on
   :8080`.
9. `curl -X POST http://localhost:8080/tasks -d '{"title":"buy milk",
   "due_at":"2026-04-26T12:00:00Z"}' -H 'content-type: application/json'`
   → 201 with body and `Location` header.
10. `curl -N http://localhost:8080/events` → SSE stream stays open;
    overdue insert produces `event: task.overdue` within `ScanIntervalSec`.
11. Run `bin\TaskForge.Admin.exe`. Visual checks: live list refresh,
    edit-and-save round-trip, filter debounce ~250 ms, dark-mode toggle
    repaints without flicker, closing the form cancels in-flight HTTP.
12. Send Ctrl+C to worker — JSON log shows `"msg":"shutting down"`,
    exits within 5 s with code 0.

**D. Static / quality gates**

- `dcc64` emits zero warnings (treat `H2077` unused params as zero
  tolerance).
- All SQL goes through `Params.ParamByName` — grep the codebase for
  `' + ' ` and `Format(` near `SQL.Text`; expect zero hits.
- DUnitX summary shows coverage of Result, Repository, JSON, ThreadPool,
  Migrations, HttpServer, Sse, Pipe, Attributes, Config, Router fixtures
  (everything green; no `[Ignore]` skips merged to main).
- `tests/e2e` scripts exit 0 and clean up temp dirs (no orphaned
  `bin\TaskForge.Worker.exe` or `TaskForge.Api.exe` processes after the
  run — checked via `tasklist`).

---

## Known weaknesses (honest list — verify before shipping)

1. **Indy SSE streaming**: I am not certain that writing repeatedly to
   `AContext.Connection.IOHandler` from inside `OnCommandGet` keeps the
   response open without Indy auto-flushing or terminating the request.
   Some Indy versions buffer headers until `ResponseInfo.WriteContent`
   is called and then close. The cleanest pattern may be to set
   `ResponseInfo.FreeContentStream := False`, write headers manually with
   `ResponseInfo.WriteHeader`, then loop on the IOHandler. **Verify
   against `IdHTTPServer.pas` source / official Indy docs before relying
   on this.**
2. **Attribute constructor syntax** in Delphi: `[Table('tasks')]` requires
   `TableAttribute = class(TCustomAttribute)` with a `constructor
   Create(const AName: string)`. RTTI then surfaces the args. I am
   confident in this, but Delphi's attribute constructor argument support
   has historically been picky about types — only ordinals, strings, and
   sets are reliably supported as compile-time literals. Don't try to
   pass records or arrays.
3. **`TThreadedQueue<TProc>`** — I'm fairly sure the generic accepts
   reference types including method references, but DCU naming for
   `TProc` (in `System.SysUtils`) vs `TThreadedQueue` (in
   `System.Generics.Collections`) sometimes confuses the linker for
   anonymous-method captures. May need a wrapper record or a typed
   `TJob = reference to procedure`.
4. **VCL Styles dark mode at runtime** — `TStyleManager.SetStyle` can
   leak GDI handles across many switches; cap the toggle to the two
   registered styles only. Style names (`'Windows10 Dark'`) must match
   exactly what `TStyleManager.StyleNames` returns; the canonical name
   varies between Delphi versions. Verify in your installed IDE.
5. **`TFDScript` for migration SQL** — I assume each migration file may
   contain multiple statements separated by `;`. If FireDAC's script
   engine doesn't split SQLite scripts cleanly, fall back to splitting
   manually before `ExecSQL`.
6. **Embedded resources** — the `.rc` syntax I have in mind is
   `MIGRATION_0001 RCDATA "..\\..\\migrations\\0001_init.sql"`. Filename
   resource IDs must be ASCII; this should work, but verify the
   `brcc32` / `rc` tool you use is on PATH and accepts this syntax.
7. **Named pipe non-blocking semantics on Windows** — `WriteFile` to a
   pipe can block when the buffer is full. Either use overlapped I/O
   (`FILE_FLAG_OVERLAPPED`) or accept that a slow API will back-pressure
   the worker. The plan says "drop on slow consumer" — that requires
   overlapped I/O with a timeout. Implementing that correctly is
   non-trivial; a simpler first cut is **synchronous + bounded queue,
   drop oldest** in front of the pipe writer thread.
8. **VirtualStringTree dark-mode** — VirtualTreeView has its own painting
   pipeline that doesn't always honour VCL Styles automatically. May
   need to set `TreeOptions.PaintOptions := [...,toThemeAware,...]` and
   handle `OnBeforeCellPaint` to draw style-aware backgrounds.
9. **`TLightweightMREW`** — I'm using the name from memory. The unit is
   `System.SyncObjs`. If unavailable in your specific Delphi build, use
   `TMultiReadExclusiveWriteSynchronizer` (longer name, same intent).
10. **`SetConsoleCtrlHandler` and FireDAC shutdown** — if FireDAC has
    open transactions when Ctrl+C fires, the cleanup order matters
    (signal → drain pool → close connections → unload driver). Get this
    wrong and you leak the SQLite WAL file. Add an explicit ordered
    teardown in the worker's finally block.
11. **DUnitX in-memory SQLite tests** — FireDAC opens `:memory:` only
    while the connection lives; sharing across test cases needs a
    fixture-scoped connection. Make sure the test fixture uses
    `[Setup]`/`[TearDown]` rather than per-test connections.
12. **In-process Indy integration tests** — booting `TIdHTTPServer` in
    the test runner and connecting to `127.0.0.1:<ephemeral>` is
    standard, but `IdStack.TIdStack.Active` is a process-global; if
    multiple `[TestFixture]`s start/stop servers in parallel (DUnitX
    `[TestFixture(Parallel)]`), expect intermittent socket-binding
    races. Default to serial execution for the integration project.
13. **PowerShell Ctrl+C delivery to a Windows console child** — there is
    no clean cross-process Ctrl+C in PowerShell. Options: P/Invoke
    `GenerateConsoleCtrlEvent(CTRL_C_EVENT, processGroupId)`, or run
    the worker in its own console with `Start-Process -NoNewWindow:$false`
    and call `AttachConsole` from a small helper. Scenario
    `05_worker_graceful_shutdown.ps1` will need this helper; budget
    real time for it. Falling back to `taskkill /F` defeats the purpose
    of testing graceful shutdown.
14. **E2E port collisions on a busy CI box** — `Tests.Support.Ports`
    grabs an ephemeral port by binding `0` and reading back the port,
    but there's a TOCTOU window between release and the worker's
    re-bind. Add a single retry-on-`EADDRINUSE` in the spawn helper.
15. **Coverage measurement** — Delphi has no first-party coverage tool
    in 11/12. Free options (DelphiCodeCoverage on GitHub) work but are
    a separate install, output is OpenCover XML. Plan does not include
    a coverage gate; if you want one, budget setup time and add a step
    to `test.bat`.
16. **GUI E2E for Admin.exe** — explicitly **not** included. UIA-driven
    VCL tests are fragile and tooling is either commercial or
    hand-rolled. Manual smoke (verification step 11) is the documented
    contract.

---

## Out of scope (intentionally)

- Authentication / authorization.
- Cross-platform builds (Linux/macOS).
- Docker / CI.
- Telemetry beyond JSON-line logging.
- Multi-user concurrency stress testing.
- Localization.

These are all reasonable next steps but explicitly excluded from this
plan.
