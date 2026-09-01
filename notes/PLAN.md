# fiktive — locked plan (2026-09-01)

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
- Schema is structure only. No distributions, DGP, or coefficients in YAML.

Missing from YAML (not invented here): LAB, IND (person income), cancer, MFR, DREAM, BFL. Thin: LMDB, AKM. `t_psyk` has no family file.

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
- Before calling the package usable: README and user instructions must make this opt-in choice obvious (examples with a few registers, not a 24-table dump). LPR diagnoses/procedures require the parent contact table that was generated.

---

## Scenario and truth API

- `generate_register(..., scenario = NULL)` = independence. A later `generate_registers(registers = c(...), scenario = NULL)` is the same, still opt-in, not “all registers”.
- `fiktive_scenario`: `id`, `version`, empty `associations` / `confounders` / `biases`, `backend = "core"`. Column refs = schema ids (`bef.koen`). Coefficients never in YAML.
- `fiktive_truth` **always** returned, even under independence. A bias claim is invalid unless it names: estimand, naive_estimator, adjusted_estimator, expected_naive, expected_adjusted. Independence: expected association 0 within MC error.
- Confounding/bias scenarios only if the naive estimator is named.

---

## Build sequence

1. Skeleton + schema-driven BEF
2. Snapshot grain: UDDA, AKM
3. Event-from-person: DOD, LMDB, VNDS (empty tables valid)
4. Expand-from-parent: LPR2 then LPR3; psych LPR as its own pair
5. FAIK (household-year; grain still unknown — do not guess)
6. Custom registers — structure only
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

**We write:** schema loader, population model, grains, custom-register spec, fastreg parquet layout, scenario/truth objects, `gen_pnr`.

**Imports:** yaml, arrow, withr, uuid, dplyr/tibble/purrr/lubridate/rlang, truncnorm.

**Suggests (optional DGP / lists):** simstudy, simDAG, fabricatr, simsurv, sksr (SKS), decoder/codeCollection (ICD/ATC lists — not Swedish `kommun`), mice::ampute only.

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
- Vendors schema YAML as the source of truth
- Puts DGP/coefficients in the YAML schema
- Uses synthpop or real microdata
