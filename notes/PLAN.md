# fiktive — locked plan (2026-09-01, catch-up 2026-09-06)

Canonical project plan. Locked with Ole Schwartz. Agents follow this; do not invent a second product.

Repo: https://github.com/sara-schwartz/fiktive (private). **Only write target.** `steno-aarhus/registers-guide`, fakeregs, osdc, fastreg, and everything else are **read-only**.

---

## End goal

An R package that **creates** structurally valid **fictitious Danish register data** so researchers can write and AI-check analysis/pipeline code **outside Statistics Denmark**, then upload **only the code** to the researcher machine.

- Title: Fictitious Danish Register Data
- Description: Generate structurally valid fictitious Danish register data, for writing and checking analysis code outside Statistics Denmark.
- The data is **created**, not pulled. Never call outputs “extracts.”
- Never install or vendor this package **inside** DST.
- Licenses: MIT (code), CC-BY-4.0 (generated datasets).

DST forbids putting actual forskermaskine data in email or copying it off the machine; examples must be fictitious. That is why this product exists:
https://www.dst.dk/da/TilSalg/data-til-forskning/regler-og-datasikkerhed/regler-for-arbejdet-med-mikrodata

---

## Use cases (locked)

| Use case | In scope? |
|---|---|
| Pipeline rehearsal (dplyr/arrow at home matches DST ids, grains, keys, types) | **Yes — primary product** |
| Custom/external-register joins (structure/metadata only; never raw rows) | **Yes** |
| Methods / teaching oracle (known DGP, truth key) | **Yes**, opt-in |
| AI-analysis eval (does the model recover a known association?) | **Yes**, opt-in |
| DST-vendored / installed on the researcher machine | **No** |
| Real microdata, synthpop-style from live extracts | **No** |

Default generation is **structural noise that joins** (`scenario = NULL` = independence). Signal/truth is a second layer.

---

## Schema contract

- Source **every run** from live [`steno-aarhus/registers-guide`](https://github.com/steno-aarhus/registers-guide) `schema/` (registers, code-systems, families). Never freeze YAML into the package as the source of truth.
- Stamp outputs with the schema git SHA. Pin by SHA for reproducibility. Local schema root allowed for offline use.
- Cover **every register in the YAML**, plus user-described custom registers from **structure only** (names, types, join key, grain, optional code lists/marginals — never raw rows).
- Generate what the YAML specifies. Flag **SCHEMA GAP** instead of inventing undocumented columns, formats, or code lists.
- A new register of a **known grain** follows the schema. A **new grain** is a gap — do not invent it.
- Schema is structure only. No scenario coefficients / DGP equations in YAML. Optional `value_domain` ranges and small `sample_values` stubs (guide aids) are not a substitute for published clinical catalogues.
- Format authority when WHO and DST disagree: registers-guide (e.g. LPR ICD-10 = WHO code with Danish `D` prefix: `E11` → `DE11`).

### Registers in YAML (as of 2026-09-06)

Present (including recent adds): BEF, UDDA, AKM, DOD*, LMDB, VNDS*, LPR2/LPR3 somatic, `t_psyk_*`, FAIK, SSSY, SYSI, **cancer**, **mfr**, **lab_dm_forsker**, plus cause-of-death variants.

Still missing from YAML (not invented here): IND (person income), DREAM, BFL. Thin lookups: LMDB/AKM class columns without enumerations.

Empty-on-purpose clinical/geo code systems (`enumerated: false`, no full lookup): `icd10`, `atc`, `sks`, `hfaudd`, `kom`, `kont_type`. fiktive must sample published external catalogues (not invent lists). Exception: `kom` can be enumerated from DST’s amt-kom CSV (98 municipalities) when the schema provides that lookup.

---

## Clinical catalogues (locked 2026-09-01)

| Domain | Sampler | Not |
|---|---|---|
| LPR diagnoses (`code_system: icd10`) | WHO ICD-10 2019, then Danish `D` prefix | `sksr`, `decoder` ICD, D+random |
| LPR surgery/procedures (`code_system: sks`) | `sksr` (`K` for surgery; other prefixes for examinations) | ICD-10 |
| LMDB ATC | WHOCC Oslo ATC/DDD | `decoder::atc`, sprintf pattern noise |
| NPU / lab | LabTerm when generating `lab_dm_forsker` | Homemade lists |

Stamp catalogue + version on outputs. Schema `sample_values` stubs (if any) are not the source of truth.

---

## Grains

A few generators, not one function per register:

1. **Status snapshot** — person × reference date (BEF; then UDDA, AKM)
2. **Event-from-person** — DOD, LMDB, VNDS, … (empty event tables are valid)
3. **Expand-from-parent** — LPR diagnoses/procedures off the **same** contact table that was written; psych LPR (`t_psyk_*`) is its own pair
4. **FAIK** — fourth grain, **unknown**: household-year on `familie_id`, not a person snapshot. Do not fake a person-level grain.

`year` is fastreg hive **tooling**, not a DST variable.

---

## Population model (ours, not schema)

Internal stable persons: `pnr`, `foed_dag`, `koen`. Same pnr ⇒ same birth/sex. **Not** fakeregs’ yearly random pool.

- BEF: one row per (`pnr`, `referencetid`) if resident. Quarterly Mar/Jun/Sep/Dec **since 2008**; December-only before. `alder` derived. No BEF before birth.
- Exit later: death via `dod.doddato`; emigration via VNDS `U` at `haend_dato`. Never mix `vnds` with `{vnds_hist, vnds_ind, vnds_ud}`.
- Household keys: structural noise until a family-graph scenario. Residents must not carry `civst = D`.
- `pnr` is a joinable id, **no CPR-validity claim**.

---

## Choosing registers

Do **not** dump all schema registers. The user names what they want. Skip an id and it is not created.

- Current API: `generate_register(id, ...)` one table. Same `population` + window so tables join.
- Do **not** add `generate_registers()` until the write-out/docs step (Ole, 2026-09-01).
- Before calling the package usable: README and user instructions must make this opt-in choice obvious. LPR diagnoses/procedures require the parent contact table that was generated.

---

## Scenario and truth API

- `generate_register(..., scenario = NULL)` = independence. A later `generate_registers(registers = c(...), scenario = NULL)` is the same, still opt-in, not “all registers”.
- `fiktive_scenario`: `id`, `version`, empty `associations` / `confounders` / `biases`, `backend = "core"`. Column refs = schema ids (`bef.koen`). Coefficients never in YAML.
- `fiktive_truth` **always** returned, even under independence. A bias claim is invalid unless it names: estimand, naive_estimator, adjusted_estimator, expected_naive, expected_adjusted. Independence: expected association 0 within MC error.
- Confounding/bias scenarios only if the naive estimator is named.

---

## Build sequence

1. Skeleton + schema-driven BEF — done (main)
2. Snapshot grain: UDDA, AKM — done (main)
3. Event-from-person: DOD, LMDB, VNDS — done (main); fix `ym_start`/`ym_end` quarter off-by-one if still open
4. Expand-from-parent: LPR2 then LPR3; psych LPR as its own pair — in flight (WHO ICD-10 + D, sksr SKS)
5. FAIK (household-year; grain still unknown — do not guess)
6. New schema registers of known grain: cancer, mfr, `lab_dm_forsker`, … then custom structure-only
7. Write-out — CSV always; parquet + hive `year=` via arrow; stamp schema commit + seed. **Also:** README and user instructions so choosing a few registers is obvious.
8. Scenario + truth — independence first; then one known association; then confounding/bias only with named estimators

Do not wait for per-step sign-off unless Ole’s input is blocking.

---

## Prior art — learn from (do not copy, do not depend)

| Source | What to steal | What not to do |
|---|---|---|
| [fakeregs](https://github.com/steno-aarhus/fakeregs) (Anders Aasted Isaksen) | Prior art that fictitious Danish register tables exist | Not a blueprint. No yearly random pool, no hardcoded columns, no join bug, no missing tests. Not an ancestor. |
| `osdc::simulate_registers` | Independent n-row tables as a *bad* contrast | Do not use as engine (tables do not join as a population) |
| `osdc::edge_cases` | 23 classifier fixtures | Fixtures, not a DGP |
| fastreg | Hive `year=` parquet layout; lowercase names | SAS wrapper only; not a generator |
| UK CeLSIUS LIDS | Closest **product shape**: metadata → structural fakes for pipeline practice | No truth key there; we add one as opt-in |
| [regkit](https://github.com/amslala/regkit) (Alejandra Martinez Sanchez; was regtools) | Filler/invariant/varying split, `withr::with_seed`, live klass codes, call-as-metadata | Reads **real** Norwegian registers; `simulate_data()` is a side door. Do not depend. |
| heaven (tagteam) `simPop` / `simAdmissionData` | Toy 1:n pattern | pnr is 1:n; learn, don’t depend |
| Roche respectables | 1:N pattern | Learn, don’t depend |
| cprr | Parses CPR | Does not generate; we write `gen_pnr` as joinable id only |

DST publishes **no** synthetic microdata. Closest Danish “just invent fictitious examples” is the DST rule, not a dataset.

---

## Backends — write vs call vs forbid

**We write:** schema loader, population model, grains, custom-register spec, fastreg parquet layout, scenario/truth objects, `gen_pnr`, catalogue loaders (WHO ICD-10, WHOCC ATC).

**Imports:** yaml, arrow, withr, uuid, dplyr/tibble/purrr/lubridate/rlang, truncnorm.

**Suggests:** simstudy, simDAG, fabricatr, simsurv, **sksr** (SKS procedures). Optional helpers for other catalogues as needed. Do **not** use `decoder` for Danish ICD-10 or as the ATC source of truth (WHOCC Oslo instead).

**Do not use:** synthpop, simPop, FakeDataR, fakeregs/osdc generators as engine, wakefield, DeclareDesign/simpr, duckdb in the generator, dawaR at runtime, WebR as a design driver.

---

## Team

| Role | Owns |
|---|---|
| Chief of Staff | Sequence, plan, pull Ole in only at blocking decisions |
| Package | R package on this repo |
| Schema | Live YAML contract, grain map, SCHEMA GAPs. Notes about the guide live **here**, never as writes to registers-guide |
| Methods | Population model, scenarios, truth |
| Review | PRs against this plan |

---

## Fail a PR if it

- Writes to any repo other than `sara-schwartz/fiktive`
- Hardcodes register structure instead of walking schema columns
- Uses fakeregs’ yearly random pool
- Calls output extracts
- Invents SCHEMA GAPs / DST code lists (including hardcoded `koen` 1/2 when schema is absent)
- Silent format-noise for clinical nomenclatures (ICD-10 / ATC / SKS) instead of published catalogues or SCHEMA GAP
- Puts SKS codes in ICD-10 diagnosis columns, or ICD-10 in SKS surgery columns
- Vendors schema YAML as the source of truth
- Puts scenario coefficients in the YAML schema
- Uses synthpop or real microdata
