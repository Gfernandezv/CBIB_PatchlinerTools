# Project Context — CBIB_PatchlinerTools

Condensed technical context for resuming work or briefing a collaborator ahead of the IgorExchange submission. See `README.md` for the full user-facing documentation and `CHANGELOG.md` for version history.

---

## What it is

Igor Pro procedure package for analyzing automated patch-clamp data acquired with the **Nanion Patchliner** system (PatchMaster software). Targets the electrophysiology research community; intended for submission to [IgorExchange](https://www.wavemetrics.com/forum/igorexchange) (WaveMetrics).

**Requirements:** Igor Pro 8+, data exported as Igor binary waves.

## Architecture (9 `.ipf` modules, v0.2)

| File | Responsibility |
|---|---|
| `Analysis_Menus.ipf` | Main panel, tabs, entry point |
| `Analysis_Utils.ipf` | Logger, global variable helpers, path helpers, wave utilities |
| `Analysis_Common.ipf` | Signal preprocessing, `sorting_hat` (organization), `pasivas` (passive properties) |
| `Analysis_Ramp.ipf` | Ramp protocol (`tempresponse`) |
| `Analysis_IV.ipf` | IV protocol (`AnalizarIVporCanal`) — **tab disabled in v0.2, under development** |
| `Analysis_Amplitude.ipf` | Amplitude extraction, result wave management |
| `Analysis_IVCurves.ipf` | V_rev, chord conductance, G-V curve, Boltzmann fit |
| `Analysis_Kinetics.ipf` | Q10 and Arrhenius (temperature dependence) |
| `Analysis_NMExport.ipf` | **New in v0.2** — exports channels to NeuroMatic |

## Key design conventions (relevant for the lint pass)

- **R1–R5** folder-handling rules: administrative folders created only by `sorting_hat`/`prefix_detector`; result folders created by `CheckDataFolder`; **R4 — functions receive folder paths as parameters, no internal path resolution** (already applied in v0.1 to `boltzmann_fit`).
- Cursors: the active wave's full path is stored in `root:Packages:[graph_name]_wave_path` (workaround because `CsrWave()` fails with hosted subgraphs `#`).
- `nvar_storer()` uses `NaN` as the retrieve-mode sentinel.
- Cursor placement always uses the `/P` (point-based) flag to avoid XY-axis scaling mismatches.

## Version status

- **v0.0** — baseline, 8-module structure established.
- **v0.1** — refactor: `SubtractBaseline()` and `Extract2DColumn()` added as shared helpers (removed duplicated code), fixed `SetDimLabel` redundantly re-executing inside loops, `boltzmann_fit` brought into R4 compliance.
- **v0.2** (2026-07-02, in progress) — added `Analysis_NMExport.ipf` and "Export" tab; IV tab temporarily disabled; **pending:** voltage command export reconstruction from `_Amp`/`_Dur` segment pairs.

## Outstanding before IgorExchange submission

- 🔲 `#include` wiring between modules (currently manual per README)
- 🔲 IPT lint + format pass
- 🔲 NM export of voltage command (reconstruction from `_Amp`/`_Dur`)
- 🔲 `nT`, `t0`, `dt` hardcoded in `amp_saver`/`amp_retreiver` → should read from Packages globals
- ⚠️ Q10/Arrhenius and NM export of current traces: functional but "under review"
- License to be defined

## Repo state (as of 2026-07-02)

Branch `v0.2`, with `CHANGELOG.md` and `README.md` modified (uncommitted) documenting the new NM export module, and the full `v0.2/` folder still untracked.
