# BPCheck Console Automation


A Windows console wrapper for Microsoft's SQL Server BPCheck. Start a CMD
launcher, accept the documented defaults, explicitly approve execution, and
receive local HTML, text and JSON reports. No SSMS, sqlcmd or additional
PowerShell module is required.

**Independent community wrapper, not a Microsoft product or support offering.**
It runs a pinned upstream diagnostic procedure; it does not modernize every
upstream recommendation for SQL Server 2025.

## Before running in production

> Diagnostic does not mean zero-impact or strictly read-only.
> Obtain change approval, check storage health, select an appropriate window,
> and start with a small database scope. The defaults are lower-load, not
> risk-free. Do not repeatedly retry a failing server.

| Risk | What to expect / mitigation |
|---|---|
| CPU, I/O, memory and tempdb | Metadata/DMV queries, temporary objects and cross-database checks consume resources even with extended performance checks off. |
| Broad scope | Empty `DatabaseIds` means **all eligible databases**, not just the current database. Instance and some system-database checks still run with an explicit scope. |
| Longer execution or blocking | Metadata locks and workload interactions are possible. Index scans and extended checks add load. Use a smaller scope first; monitor from another connection. |
| First installation | Creates `msdb.dbo.usp_bpcheck`. Interactive installation requires a separate explicit confirmation; `-Install` is the equivalent command-line authorization. Existing procedures are never overwritten. |
| High privileges | Full upstream coverage requires elevated SQL privileges; checks may fail or be skipped otherwise. Do not grant sysadmin merely to suppress a warning. Running CMD as Administrator does not grant SQL sysadmin. |
| Sensitive output | Reports can reveal database names, configuration, file paths, query/module text and operational details. Store them in an access-controlled folder. The tool does not set restrictive ACLs or redact reports for you. |
| Encryption and identity | Encryption and certificate validation are on. Fix certificate trust/name problems rather than disabling validation in production. |
| Upstream defects / old guidance | A diagnostic query may fail on particular data or metadata. Failed reports are partial; completion is not a compliance or health certification. |

The wrapper always passes `0` for `allow_xpcmdshell`, `diskfrag`,
`bpool_consumer`, `spn_check`, `gen_scripts` and `logdetail`. It does not enable
xp_cmdshell/OLE Automation or apply remediation. This intentionally skips
some OS, disk, SPN and deeper checks. No automated index rebuild/drop/create,
server restart, database repair, or scheduled-task creation is performed.

## Requirements

- Windows and Windows PowerShell **5.1** (`powershell.exe`).
- Network access and suitable SQL permissions, including access to `msdb`.
- A writable package directory for the pinned SQL download/cache and a writable,
  appropriately secured report directory.
- HTTPS access to `raw.githubusercontent.com` when the source is not cached.
  For offline use, place the exact pinned file beside the PS1 in advance.
- Compliance with your organization's script-signing/execution policy. Launchers
  do not bypass or modify it. Review downloaded scripts before approving them.
- Trusted SQL Server certificate matching the connection name. A deliberately
  selected certificate exception is available for trusted test systems only.

**Validated environment:** SQL Server 2025, version 17.0.5045.3, Windows
Authentication with sysadmin. Other versions, remote servers, SQL
Authentication and restricted-permission execution have not been integration
tested here. See [validation scope](VALIDATION.md).

## Quick start

1. Download and extract the release ZIP.
2. In the EN package, double-click **`BPCheck-Start.cmd`**.
   The separate TR package uses **`BPCheck-Baslat.cmd`**.
3. Enter your instance, for example `SQLHOST\INSTANCE` or `tcp:SQLHOST,1433`.
   If left blank, the target is **`localhost`**, the local default instance.
   Named instances are not auto-discovered and no alternate target is tried.
4. Accept defaults or choose a narrow database ID list.
5. Review the displayed target, scope and options. Type **Y** (or **E**) to
   execute. Enter alone cancels **before opening a SQL connection**.
6. If the procedure is missing, approve its installation separately.
7. Open `Rapor.html` in the printed report directory and review `Ozet.json`.

**There is no zero-input promise of a successful run.** Defaults remove optional
configuration, not connection/permission requirements or safety approvals.
Pressing Enter at every prompt cancels. No automatic certificate bypass,
installation, authentication downgrade, alternate-server fallback, or repair
is used.

### Defaults

| Setting | Default |
|---|---|
| Target | `localhost` (default instance) |
| Engine language | Package language (`EN` or `TR`); `-Language` can override it |
| Authentication | `Windows`, current process identity |
| Sampling interval | `60` seconds; **not total runtime** |
| Extended performance checks | Off (`H` / `N`) |
| Index fragmentation | Off (`H` / `N`) |
| Index scan mode | `LIMITED` (only relevant when fragmentation is on) |
| Database scope | All eligible databases; instance checks still apply |
| Command timeout | `1800` seconds; not an overall job deadline |
| TLS / certificate validation | Both on |
| Reports | `Raporlar` beside the script; unique subfolder for each run |
| Run / first-install confirmation | No; explicit approval required |

### Command-line parameters

All settings are optional; prerequisites and explicit execution approval remain.
Interactive mode prompts using supplied values as defaults.

| Parameter | Values and meaning |
|---|---|
| `-Server` | `localhost`, `HOST\INSTANCE`, or `tcp:HOST,PORT`. A port alone is not a host address. |
| `-Language` | `EN` or `TR`; console and wrapper report headings. Upstream SQL content and provider exceptions are not translated. |
| `-Authentication` | `Windows` or `SQL`. SQL mode asks for username and a hidden password interactively. Passwords are never accepted as command-line parameters. |
| `-Username` | Optional SQL login name; not a password. |
| `-Duration` | Integer `10..255`, upstream measurement interval. |
| `-Performance` | `Y/N` or `E/H`, case-insensitive. Enables/disables extended upstream performance/index/statistics checks; default off. |
| `-IndexFragmentation` | `Y/N` or `E/H`. Additional index analysis; enable `Performance` as well, because upstream checks may be nested under it. |
| `-IndexScanMode` | `LIMITED`, `SAMPLED`, `DETAILED`. More detailed scans can be substantially more expensive. |
| `-DatabaseIds` | Quoted comma-separated positive integer IDs, e.g. `"5,7"`. Not database names. Each must exist, be ONLINE and accessible. Empty means all eligible databases. |
| `-OutputDirectory` | Destination root. Ensure free space and appropriate access controls. |
| `-CommandTimeout` | Integer `30..86400` seconds for SQL commands, not a total-run SLA. Cancellation/cleanup can take additional time. |
| `-TrustServerCertificate` | Explicitly skips server certificate validation; encryption stays on. Not a production default. |
| `-Install` | Explicit first-install permission; does not replace an existing procedure. |
| `-NonInteractive` | Explicitly authorizes execution without prompts. Windows Authentication only; combine with `-Install` only when installation is approved. |

For example, obtain database IDs with an authorized query:

```sql
SELECT database_id, name, state_desc
FROM sys.databases
ORDER BY database_id;
```

### Examples

Interactive, English; lower-load defaults and explicit confirmations:

```powershell
.\BPCheck-Calistir.ps1 -Server "SQLHOST\INSTANCE" -DatabaseIds "5,7"
```

Turkish, optional additional performance and LIMITED index checks:

```powershell
.\BPCheck-Calistir.ps1 -Language TR -Server "SQLHOST\INSTANCE" `
    -DatabaseIds "5" -Performance E -IndexFragmentation E -Duration 30
```

Approved first installation and unattended execution using a trusted certificate:

```powershell
powershell.exe -NoProfile -File ".\BPCheck-Calistir.ps1" `
    -Server "SQLHOST\INSTANCE" -DatabaseIds "5" `
    -OutputDirectory "D:\RestrictedReports\BPCheck" -Install -NonInteractive
```

For later Task Scheduler use, call the PS1 with `-NonInteractive` under an
approved Windows task identity. Omit `-Install` after setup. Do not schedule
the CMD launcher: it pauses at the end. Protect the script, cached SQL and
report locations against unauthorized modification. Overlapping scheduled runs
are not prevented by this tool; configure the scheduler not to overlap.
Do not run either language package concurrently against the same SQL instance.
Upstream BPCheck uses global temporary tables (for example `##tmpdbsizes`);
overlapping sessions can fail with an "object already exists" error.

## What will you learn?

Actual sections vary with version, permissions, upstream applicability and
selected parameters. An absent/skipped section is **not** a passed check.

| Area | Examples of information and interpretation |
|---|---|
| Instance / OS / HA | Version, uptime, configuration, visible HA topology and inventory; establish context, not a complete support assessment. |
| CPU / memory | MAXDOP/NUMA-related observations, memory configuration and allocation signals; review against workload and current vendor guidance. |
| Database / tempdb / files | Compatibility and database options, growth configuration, VLF and tempdb observations; identify candidates for follow-up. Some volume checks are unavailable with xp_cmdshell off. |
| Maintenance / integrity history | Backup, CHECKDB-history, suspect-page, alert and error-log observations where available. This is **not** a fresh full DBCC CHECKDB or a restore test. |
| Performance (opt-in) | Wait/latch and counter samples, I/O and workload signals, blocking and cached-plan observations where applicable. These are point-in-time/since-restart clues, not root-cause proof. |
| Indexes / statistics (opt-in) | Upstream missing/duplicate/unused-index and statistics observations; optional fragmentation scan. Validate workload, uptime, overlap and write cost before changing indexes. |
| Naming / security / monitoring | Applicable upstream conventions and monitoring/security observations; **not** a comprehensive security audit. |

The tool does not supply a production-safe remediation plan, business-impact
score, complete SQL2025 feature audit, or guarantee that every listed category
will produce a result set.

## Reports and exit codes

Each run that reaches report setup creates `BPCheck_<timestamp>_<unique-id>`:

| File | Purpose |
|---|---|
| `Rapor.html` | All result tables, findings highlighting, summary and SQL messages. Cells are HTML-encoded. |
| `Sonuclar.txt` | Tab-separated values, grouped by result set; embedded tabs/newlines escaped. |
| `Mesajlar.log` | SQL messages and exceptions. |
| `Ozet.json` | Status, failure stage, options, timing, result counts, skipped-message count and source verification. Stable machine-readable field names are English. |

| Status / exit | Meaning |
|---|---|
| `Completed` / `0` | Execution completed; not a health certification. |
| `CompletedWithFindings` / `0` | Execution completed with text-matched findings/messages. Review them. |
| `Failed` / `1` | Connection, permissions, source verification, SQL, output or upstream failure. Reports may be partial. Parameter-binding errors also return nonzero, before report creation. |
| `Cancelled` / `2` | Interactive run approval was not given; no SQL connection/report folder created. |

`FindingRows` uses a simple `WARNING/ERROR/FAIL` text match, not a severity
classifier. `SqlErrorRows=0` does not mean no SQL error: a failure can occur
before any row is read. Always examine **Status + Error + Stage** first.
`SkippedMessages` counts upstream messages containing `skipped`/`bypassed`;
it is not a full inventory of every disabled check.

## Troubleshooting and known limits

- **Certificate error:** configure a trusted certificate with the correct
  server name. Do not silently downgrade transport security.
- **Storage error / OS error 21 / severe I/O error:** stop diagnostic retries.
  Investigate SQL ERRORLOG and Windows/storage logs. Restarting SQL alone does
  not establish that storage health or database integrity is restored.
  After storage is stable, arrange DBA-led integrity checks and recovery.
  Never blindly use `REPAIR_ALLOW_DATA_LOSS`.
- **Statistics sampling / divide by zero (8134):** observed in the pinned
  upstream code against a particular database. Its sampling expression divides
  by a row count without a zero guard. The wrapper reports failure, does not
  hide it, alter statistics or patch the Microsoft procedure. Use
  `-Performance N` for a reduced diagnostic scope, or investigate/review a
  future upstream fix. This avoids that check; it does not fix its cause.
- **Existing procedure differs:** execution stops without overwriting it.
  This includes ALTER/CREATE OR ALTER versions with different module text.
  Have a DBA review the existing definition and the pinned source; never
  automatically drop a production procedure to force a match.
- **Timeout / partial report:** reduce scope, disable expensive options and
  inspect resource usage. Do not merely raise timeout indefinitely.

## Source, publication and licensing

Upstream: [microsoft/tigertoolbox BPCheck](https://github.com/microsoft/tigertoolbox/tree/master/BPCheck).
The wrapper downloads only the pinned SQL source over HTTPS; it does not upload
SQL data or reports. First-use downloading contacts GitHub.

- Commit: `0b0c137ff2809c086e6a9ae65e9e69ceca13e475`
- SHA256: `357B11A121B3AE0DAEAB2125CE8AAE8C2F49FEC3561A6A974779C9862C302B72`

Before installation/execution the cached source hash is checked and the
installed module is compared with the pinned definition (line endings
normalized). SQL text is not rewritten. This protects the intended execution
path, not against an administrator or concurrent actor modifying it after the
check.

Wrapper code is [MIT licensed](LICENSE). Microsoft BPCheck is a separate
third-party work; see [third-party notice](THIRD-PARTY-NOTICES.txt).

**Do not initialize/push this working folder wholesale:** it contains local
reports and test evidence. Build a clean allowlisted distribution:

```powershell
.\Build-Release.ps1
```

The resulting `dist\BPCheck-Console-Automation-EN.zip` and
`dist\BPCheck-Console-Automation-TR.zip` each contain the corresponding launcher,
localized main README and default language, plus the shared wrapper,
tests, build script, license, validation and third-party notices and ignore rules.
Shared technical notices/tests may contain English and Turkish.
A single-language release rebuilds only its own ZIP.
The packages omit SQL
source, report data, server-specific test results and credentials. Extract it
to a **new folder**, review the contents, and initialize your GitHub repository
there. The included `.gitignore` is defense-in-depth, not a substitute for
reviewing staged files. This project does not publish to GitHub automatically.

## Testing

No live SQL diagnostics:

```powershell
.\Test-Paket.ps1
```

Opt-in live SQL2025 integration test (existing pinned installation required):

```powershell
.\Test-Paket.ps1 -RunSqlTest -Server ".\SQL2025" -DatabaseId 51
```

Replace the example target/ID with your authorized test environment. Live
tests run diagnostics and explicitly allow a certificate exception for that
test environment. They never install or replace the procedure.
