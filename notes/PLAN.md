# fiktive — locked plan (2026-09-01, catch-up 2026-09-06, catalogue lock 2026-09-06, ICD split 2026-09-06, STEP 7 lock 2026-09-09, STEP 8a lock 2026-09-09, STEP 8b–8d lock 2026-09-09, full-review catch-up 2026-09-09)

Canonical project plan. Locked product decisions. Agents follow this; do not invent a second product.

Repo: https://github.com/sara-schwartz/fiktive (private). **Only write target.** `steno-aarhus/registers-guide`, fakeregs, osdc, fastreg, and everything else are **read-only**.

---

## End goal

An R package that **creates** structurally valid **fictitious Danish register data** so researchers can write and AI-check analysis/pipeline code **outside Statistics Denmark**, then upload **only the code** to the researcher machine.

- Title: Fictitious Danish Register Data
- Description: Generate structurally valid fictitious Danish register data, for writing and checking analysis code outside Statistics Denmark.
- The data is **created**, not pulled. Never call outputs "extracts."
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
- Prefer register/family `one_row_per` and code-system `values_from` from live YAML when present.
- Schema is structure only. No scenario coefficients / DGP equations in YAML. Optional `value_domain` ranges and small `sample_values` stubs (guide aids) are not a substitute for published clinical catalogues.
- Format authority when sources disagree: **registers-guide**. Branch on `code_system` id — do not assume every diagnosis column is D-prefixed SKS.
- **Column coverage:** if a column has no `coverage`, inherit the register (or family) coverage. Do not treat a missing stamp as "column absent forever."

### Registers in YAML (as of 2026-09-06; guide tip assessed 8079ab8e on 2026-09-09; STEP 6c lab_dm_forsker)

Present (including recent adds): BEF, UDDA, AKM, DOD*, LMDB, VNDS*, LPR2/LPR3 somatic, `t_psyk_*`, FAIK, SSSY, SYSI, **cancer**, **mfr**, **lab_dm_forsker**, plus cause-of-death variants.

Thin lookups: LMDB class columns without enumerations. AKM: tip 8079ab8e wires beskst/beskst02/branche_77/disco*/nace*/discotyp/nystgr/omfang (+ socio*); honour lookup or values_from csv|none (no invent).

Empty-on-purpose clinical/geo/occupation code systems (`enumerated: false`, `values_from` set): `icd10`, `icd10_sks`, `icd8`, `atc`, `sks`, `hfaudd`, `kom`, `kont_type`, `disco08`, `nace_db07`, `branche_77`, `nystgr`, `disco_old`, `nace_old`, …. fiktive **reads** `values_from` (`package` / `csv` / `none`) and samples the pointed catalogue — it does not invent lists and does not ignore the field. No parallel `values_from.reason` enum (`kind` already branches).

`kom`: schema CSV may set `mixes_eras: true` (pre- and post-2007 in one file). Do not emit abolished municipalities into recent years; prefer validity-aware sampling or a later `kom` / `kom_pre2007` split when the guide lands it.

---

## Clinical catalogues (locked 2026-09-06, ICD split same day)

| Domain | Sampler | Not |
|---|---|---|
| LPR / psych diagnoses (`code_system: icd10_sks`) | `sksr::SKS_labels` with `Prefix == "dia"` (already `DE119`) | Plain WHO `E119`, mapping all `icd10` → D-prefix, `decoder`, D+random |
| Cancer / cause-of-death diagnoses (`code_system: icd10`) | Plain WHO via `codeCollection::ICD10Koodit` (honour `values_from`) | sksr dia / D-prefix |
| Historical ICD-8 (`code_system: icd8` / `previous_code_system` until 1993) | Honour schema when present; else SCHEMA GAP | Inventing ICD-8 lists |
| LPR surgery/procedures (`code_system: sks`) | `sksr` with `Prefix == "opr"` (surgery); other prefixes for examinations | ICD diagnosis codes; wrong examples (KJDB00 ≠ appendectomy; KJEA00 is) |
| Contact type (`kont_type`) | Honour schema (SKS adm and/or MiniPAS pattype digits by era) | Invent |
| LMDB ATC | WHO ATC form (`C09AA05`); runtime `codeCollection::ATCKoodit` (or WHOCC-aligned) | `decoder::atc`, sprintf noise, `sksr` ATC (`MC09…`) |
| NPU / lab | LabTerm when generating `lab_dm_forsker` | Homemade lists |

Stamp catalogue + version on outputs. Schema `sample_values` stubs (if any) are not the source of truth. Honour live `values_from` when it matches these locks.

---

## Grains

A few generators, not one function per register:

1. **Status snapshot** — person × reference date (BEF; then UDDA, AKM) — schema `person_reference_date`
2. **Event-from-person** — DOD, LMDB, VNDS, … (empty event tables are valid)
3. **Expand-from-parent** — LPR diagnoses/procedures off the **same** contact table that was written; psych LPR (`t_psyk_*`) is its own pair (`lpr2_psychiatric`)
4. **FAIK / household_year** — schema `one_row_per: household_year` (household-year on `familie_id`, not a person snapshot)

`year` is fastreg hive **tooling**, not a DST variable.

Custom/external registers may use **any existing** schema grain above (including `household_year`). A grain the schema does not have is a **SCHEMA GAP** — stop; do not invent.

---

## Population model (ours, not schema)

Internal stable persons: `pnr`, `foed_dag`, `koen`. Same pnr ⇒ same birth/sex. **Not** fakeregs' yearly random pool.

- BEF: one row per (`pnr`, `referencetid`) if resident. Quarterly Mar/Jun/Sep/Dec **since 2008**; December-only before. `alder` derived. No BEF before birth.
- Exit later: death via `dod.doddato`; emigration via VNDS `U` at `haend_dato`. Never mix `vnds` with `{vnds_hist, vnds_ind, vnds_ud}`.
- Household keys: structural noise until a family-graph scenario. Residents must not carry `civst = D`.
- `pnr` is a joinable id, **no CPR-validity claim**.

---

## Choosing registers

Do **not** dump all schema registers. The user names what they want. Skip an id and it is not created.

- Schema path: `generate_register(id, ...)` one table. Same `population` + window so tables join.
- Batch path (STEP 7): `generate_registers(registers = c(...), ...)` — **`registers` is required**; never a silent default of every implemented id. Not "all registers."
- Custom/external path (STEP 7): `generate_custom_register(...)` — see below. Not overloaded into `generate_register("bef")`.
- Before calling the package usable: README and user instructions must make this opt-in choice obvious. LPR diagnoses/procedures require the parent contact table that was generated.

---

## STEP 7 — write-out, batch opt-in, custom external (locked 2026-09-09)

### Write-out

- Primary return value remains in-memory tables.
- **Default on-disk format: CSV.** Parquet (and optional hive `year=` via arrow) are **opt-in**, not the default.
- Stamp schema commit, seed, package version, and catalogue stamps when catalogues were used.
- Never call outputs extracts.

### Batch schema generation

- `generate_registers(registers = c("bef", "lmdb", ...), population, schema, ...)` builds the named schema registers only.
- Missing / unknown ids → clear error (or SCHEMA GAP), not silent skip-all.

### Custom / external registers (structure only)

**Purpose:** researcher-described tables that are **not** in the guide YAML, so pipeline code that joins an external register can be rehearsed. **Never raw rows. Never coefficients. Never prevalences.**

**API (easiest path):**

- Register metadata = **R function arguments** on `generate_custom_register()`: at least `id`, `one_row_per`, `join_keys`, plus `population` / `schema` / window like schema generators.
- Columns = **CSV path or tibble** with: `name`, `type`, optional `min`, `max`, `values` (small allowed set for structural noise — user stubs, not DST catalogues).
- YAML is **not** required for the normal path.
- `generate_custom_register()` is the front door; it wraps the **same engine** as schema generation. `generate_register(id)` stays **schema ids only**.

**Defaults / rules:**

- Default `join_keys` for person-side grains: `pnr` (shared population spine — no second person spine).
- If `one_row_per = "household_year"`, `join_keys` must be household-side (e.g. `familie_id`) — do **not** silently default to `pnr`.
- Types limited to what we already emit (`character` / `integer` / `numeric` / `date` / `logical`) unless schema later expands.
- Optional ranges / `values` describe structural noise only; signal/DGP stays in scenarios (STEP 8).
- Empty event-grain custom tables remain valid.
- `expand_from_parent` customs require an explicit already-generated parent table; do not invent parents.
- Custom columns become referenceable as `register.column` once in the run (for later scenarios); coefficients never live in the column CSV.

**Non-goals:** new grains; synthpop-from-real / raw extracts; dumping all schema registers; batch of many customs inside `generate_registers` in STEP 7 (customs stay one-at-a-time unless later extended).

### README / docs (same step)

Document: pick registers → generate → write CSV → join; LPR parent/child; one custom-external example (CSV columns + R args).

---

## Scenario and truth API

- `generate_register(..., scenario = NULL)` = independence. `generate_registers(registers = c(...), scenario = NULL)` is the same, still opt-in, not "all registers".
- `fiktive_scenario`: `id`, `version`, empty `associations` / `confounders` / `biases`, `backend = "core"`. Column refs = schema ids (`bef.koen`) or custom `register.column` once declared. Coefficients never in YAML / column CSV.
- `fiktive_truth` **always** returned, even under independence. A bias claim is invalid unless it names: estimand, naive_estimator, adjusted_estimator, expected_naive, expected_adjusted. Independence: expected association 0 within MC error.
- Confounding/bias scenarios only if the naive estimator is named.

### STEP 8a — independence path + opt-in fidelity (locked 2026-09-09)

**First ship of STEP 8.** Wire the independence path and opt-in data-quality fidelity only. Informative MAR/MNAR, biasing outliers, confounding, and known associations are **not** in 8a — see STEP 8b–8d lock below.

#### Independence (default)

- `scenario = NULL` remains the default on `generate_register` / `generate_registers` / `generate_custom_register`.
- Always return `fiktive_truth`, even under independence.
- Under independence: expected association **0 within MC error**; bias fields null/empty as appropriate.
- Coefficients never in YAML or custom column CSV.
- No synthpop / real microdata.

#### Opt-in fidelity (data quality) — NOT default association/bias

Fidelity is **data quality** (MCAR-ish NA + rare numeric extremes), **not** informative missingness or confounding.

- **API:** `fidelity = "clean" | "messy"` plus optional `na_rate` / `outlier_rate` overrides (each in [0, 1]).
- **Default:** `fidelity = "clean"` (effective rates 0).
- **`messy`:** small fixed MCAR-ish rates — document e.g. ~1–5% NA on eligible columns; rare numeric extremes. **Never invent DST rates from real microdata.**
- **Overrides win** when set; stamp **preset + effective rates** on outputs.
- **Column eligibility:**
  - NA on **non-key, non-derived** columns only.
  - Outliers **only** on numeric/date columns.
  - Join keys, presence flags, and derived columns (e.g. `alder`) stay **COMPLETE**.
- Same knobs on `generate_register` / `generate_registers` / `generate_custom_register`.

#### Explicitly out of 8a (covered by STEP 8b–8d)

- Informative MAR / MNAR missingness
- Biasing outliers / confounding / known associations
- Named estimands and naive/adjusted estimators beyond the independence truth stub

### STEP 8b–8d — association, confounding, named biases (locked 2026-09-09)

**Full first 8b+ ship** covers **8b–8d in one PLAN lock**. Do not reshape `fiktive_scenario` — **fill** the existing `associations` / `confounders` / `biases` slots. Wire `scenario=` through `generate_register` / `generate_registers` / `generate_custom_register`. **Core backend first**; simDAG/simstudy optional Suggests later OK to mention as optional. No synthpop / real microdata. Coefficients **never** in YAML or custom column CSV.

#### 8b Association

- `fiktive_scenario.associations` list; each element: `exposure`, `outcome` (`register.column`), `link` (`identity` | `logit` | `log`), `coefficient` (numeric; **only here**, never YAML).
- For **pure association** scenarios: `confounders` / `biases` stay **empty lists**.
- Truth: `scenario_id`; `causal_effect` `{estimand, parameter, value=coefficient, scale=link}`; estimand named; `naive_estimator` recovers it; `adjusted_estimator` **SAME** as naive in pure 8b; `expected_naive` = `expected_adjusted` = coefficient within MC/CI.
- **No bias claim** in pure association.

#### 8c Confounding

- One confounder scenario: fill `confounders`; known E→Y effect; confounder affects E and Y.
- Truth: naive ≠ adjusted; `expected_naive` ≠ `expected_adjusted`; **all four bias fields required** (`estimand`, `naive_estimator`, `adjusted_estimator`, `expected_naive`, `expected_adjusted`).

#### 8d Named biases (small catalogue)

- **IN:** MNAR missingness; complete-case selection bias.
- **OUT / deferred:** immortal time, left truncation, code misclassification, open bias DSL.
- Fill `biases` slot; full truth with distinct naive vs adjusted.
- Cosmetic MCAR fidelity stays **orthogonal** (8a); must **not** silently move estimands; default clean under scenarios.

#### Cross-cutting (8b–8d)

- Do not reshape `fiktive_scenario` — fill `associations` / `confounders` / `biases` slots.
- Wire `scenario=` through `generate_register` / `generate_registers` / `generate_custom_register`.
- Customs: `register.column` once in run; shared population; existing grain only.
- Coefficients never in YAML or custom column CSV.
- No synthpop / real microdata.
- Core backend first; simDAG/simstudy optional Suggests later OK to mention as optional.
- README: independence → association → confounding → MNAR/complete-case examples.

---

## STEP 9 — time-to-event grain: immortal time bias + left truncation (locked 2026-09-09)

Unparks 2 of the 4 deferred-bias items (open bias DSL stays gated per the
proposal above; this is the "different order of work" item flagged there).
Both are fundamentally survival-analysis biases, not a tweak to the
existing linear/logit association DGP — no existing grain (snapshot /
event / household-year / expand-from-parent) carries entry-censoring-hazard
structure, so this adds a **new grain**, custom-register-only (no schema
register currently has this shape; a schema register could adopt it later
without any change here — same rule as every other grain).

**Important asymmetry discovered during design, driving the sequencing
below:** immortal time bias needs only a time-varying exposure on a
constant-hazard (exponential) survival time — standard, well-understood.
Left truncation, however, produces **no bias to demonstrate** under a
constant hazard: the exponential distribution is memoryless, so "time
since delayed entry" and "age, properly left-truncated" give the *same*
unbiased answer regardless of how late entry is. Left truncation bias only
exists when the hazard is **age-varying** (Weibull/Gompertz-shaped), so it
needs a genuinely different hazard model, not a truncation wrapper around
the same exponential machinery immortal time uses. These are sequenced as
two phases for that reason, not because one is unimportant.

### New grain: `time_to_event`

- Added to `.KNOWN_GRAINS` (`R/generate.R`), custom-register-only via
  `generate_custom_register(one_row_per = "time_to_event", ...)` — same
  status as every other grain (a schema register could use it once
  registers-guide documents one shaped this way; not invented into the
  live schema here).
- Fixed column shape (not user-described via a columns CSV/tibble, unlike
  ordinary customs — the whole feature is the *correlation* between these
  columns, which a user-supplied independent-column spec can't express):
  `pnr`, `entry_time` (numeric, cohort entry on the risk time scale),
  `exit_time` (numeric, event-or-censoring time), `event` (0/1 indicator).
  Immortal-time custom registers add `exposure_start_time` (numeric,
  `NA` if never exposed before `exit_time`) and `ever_exposed` (0/1
  convenience flag).
- Requires the `survival` package (`Surv()`, `coxph()`) for both the
  generator's own truth simulation and for the examples a user would write
  against the generated data. `survival` ships as part of every standard R
  installation (an R "Recommended" package, not an optional extra) — add
  to `Imports`, no new install burden in practice.

### Phase 1 — immortal time bias — done (2026-09-10)

`scenario_immortal_time()` (`R/truth.R`) + `generate_immortal_time_cohort()`
/ `draw_immortal_time()` (`R/generate-survival.R`) + a `time_to_event`
branch in `generate_custom_register()` (`R/generate-api.R`). Built
essentially as designed below, with two refinements found during
execution:

- Added `horizon_years` to the scenario (not in the original design) after
  discovering the naive HR is meaningfully sensitive to follow-up length
  (0.635 at 2yr vs. 0.273 at 20yr for the same true HR=1.5, in early
  testing) — bigger than the corresponding sensitivity for
  MNAR/complete-case/misclassification's reference-exposure
  approximation. Since the user already knows their intended
  `from`/`to` window, having them pass its length lets `expected_naive`
  be computed exactly for their case instead of guessed from a fixed
  reference, unlike the other bias types (which have no equally cheap
  fix available).
- `apply_fidelity()` is skipped entirely for this grain: its column
  eligibility isn't scoped to `spec$columns`, so with none declared it
  would have treated `exit_time`/`event`/`exposure_start_time` as fair
  game for NA/outlier injection under `fidelity = "messy"` — corrupting
  `Surv()` rather than rehearsing anything meaningful. Caught before
  shipping by tracing the eligibility function rather than assuming.

Verified empirically (not just asserted): the naive fixed-baseline-
covariate analysis shows spurious protection (HR ~0.52 at true HR=1.5,
HR ~0.36–0.52 at true HR=1 depending on parameters) matching stamped
`expected_naive` within ~0.01–0.05; a correctly time-varying analysis via
`survival::tmerge()` recovers the true HR (1.49 vs. true 1.5; 1.53 vs.
true 1.5 in a second run) matching stamped `expected_adjusted` exactly (by
construction, but the *recovery* was verified, not assumed). 33 new
tests, `R CMD check` 0/0/0, README section added, `survival` added to
Imports (confirmed already present in every standard R install before
committing to it).

Original design (for reference):

- `scenario_immortal_time(baseline_hazard, true_hazard_ratio, exposure_rate, ...)`.
- DGP (piecewise-exponential, the standard technique for a time-varying-
  covariate survival simulation): draw an unexposed-clock event time at
  `baseline_hazard`; draw an independent exposure-start time at
  `exposure_rate`. If the unexposed clock fires first, the event happens
  unexposed. If exposure would start first, re-draw the *remaining* time
  from exposure start using hazard `baseline_hazard * true_hazard_ratio`
  (memoryless property makes this exact, not approximate). Censor at the
  requested window end.
- Truth: `expected_adjusted` = `true_hazard_ratio` (log scale internally,
  reported on the hazard-ratio scale) — what a correctly time-varying Cox
  model (`coxph(Surv(tstart, tstop, event) ~ exposed)` with the exposure
  window split via `survival::tmerge`/`survSplit`) recovers.
  `expected_naive` = simulated (same deterministic-simulation pattern as
  the MNAR/complete-case/misclassification hardening: fixed internal seed,
  large N, single `coxph()` fit — not a closed form, since the naive bias
  size depends on the baseline hazard and exposure-rate shape) from
  treating `ever_exposed` as a **fixed baseline** covariate in
  `coxph(Surv(entry_time, exit_time, event) ~ ever_exposed)` — the classic
  immortal-time mistake. Expect `expected_naive < true_hazard_ratio`
  (spurious protection) even when `true_hazard_ratio = 1`.

### Phase 2 — left truncation

- `scenario_left_truncation(shape, scale, age_effect, ...)` (Weibull
  hazard: age-varying, needed for the bias to exist at all — see above).
- DGP: draw each person's TRUE age-at-event via inverse-CDF from a Weibull
  hazard; draw an independent `entry_age` (delayed entry); a person is
  only observed at all if `entry_age < true_age_at_event` (left truncation
  is a survivorship condition, not just a later time-zero) — same
  selection-mechanic *shape* as `complete_case`, different scale (age, not
  a linear outcome).
- Truth: `expected_adjusted` = the true Weibull age-effect, recovered by
  `coxph(Surv(entry_age, exit_age, event) ~ 1)` with truncation correctly
  declared. `expected_naive` = simulated from the common mistake:
  `coxph(Surv(exit_age - entry_age, event) ~ 1)`, i.e. treating time since
  entry as time zero and discarding truncation entirely.

### Non-goals (this lock)

- No general time-varying-covariate framework beyond what immortal time
  needs — not building a `tmerge`-style public API surface, just what the
  two scenarios require internally.
- No competing risks, no recurrent events.
- Not wired into `generate_registers()` for schema ids (no schema register
  has this grain yet) — `generate_custom_register()` only, same as every
  other grain-gated feature.

---

## Build sequence

1. Skeleton + schema-driven BEF — done (main)
2. Snapshot grain: UDDA, AKM — done (main)
3. Event-from-person: DOD, LMDB, VNDS — done (main); `ym_start`/`ym_end` quarter digit fixed
4. Expand-from-parent: LPR2 then LPR3; psych LPR as its own pair — done (main); harden for `icd10` vs `icd10_sks` split
5. FAIK (household-year) — done (main)
6. New schema registers of known grain: cancer, mfr / Levendefødte, lab_dm_forsker — done (main); lookup hardens for FAIK/AKM/periodised codes — done
7. **Write-out + batch opt-in + custom external + README** — STEP 7 — done (main)
8. Scenario + truth:
   - **8a:** independence path (`scenario = NULL`); always return `fiktive_truth`; opt-in fidelity (`clean`/`messy` + rate overrides); eligibility rules — **done (main)**
   - **8b–8d (this lock):** association (`associations` + pure-assoc truth); confounding (one confounder; naive ≠ adjusted; full bias fields); named biases (MNAR + complete-case; immortal time / left truncation / code misclassification / open bias DSL deferred); wire `scenario=` through generators; core backend first; README progression independence → association → confounding → MNAR/complete-case

Do not wait for per-step sign-off unless a product decision is blocking.

---

## Full-review catch-up (2026-09-09)

Build sequence steps 1–8d above are all **done and verified**: 633 passing
tests, `R CMD check` clean (0 errors/warnings/notes), and a full-package
review (8 finder passes: correctness, missing-guards, cross-file
consistency, reuse, simplification, efficiency, altitude, conventions)
found and fixed several real bugs, most severe being a cross-register
scenario join that silently degraded from `pnr` to a coincidental shared
column (e.g. `year`) whenever a third, unrelated register lacking `pnr`
was batched into the same `generate_registers()` call — corrupting the
planted association instead of raising an error. README rewritten for
new users (plain language, one worked example per feature, every code
block verified to run end-to-end).

The **end goal** (pipeline rehearsal outside DST + custom-register joins +
opt-in scenario/truth oracle) is functionally reached for every register
currently in `registers-guide`. Open items below are extensions/hardening
on top of that, not blockers to the core product.

### Resolved — MNAR / complete-case `expected_naive` was a fixed heuristic, now simulated (2026-09-09)

Was: `make_truth_from_scenario()` stamped `expected_naive <- beta * 0.5` —
a constant 50% attenuation — regardless of the actual
`mnar_coefficient`/`selection_coefficient` strength. Confirmed empirically
at the time: with `coefficient = 2.0`, the real naive OLS fit moved from
2.02 (weak, `mnar_coefficient = 0.1`) to 1.78 (`= 1.2`) to 1.53 (`= 5`)
while the stamp stayed frozen at 1.0 throughout.

Fix: for identity link with `on` targeting the exposure or outcome (the
common case — self-censoring on Y, or on the exposure), `expected_naive`
is now computed by `simulate_expected_naive_selection()` in `R/truth.R` —
a deterministic Monte Carlo simulation (fixed internal seed, N=200k) of
the *exact* generator mechanism (`draw_outcome_from_exposure()` +
`invlogit()` selection) against a **standard-normal reference exposure**.
Verified against real generated data (`Uniform(-2, 2)` exposure, not the
reference distribution): now within ~0.01–0.02 of the actual naive fit
across weak/medium/strong `mnar_coefficient`/`selection_coefficient`,
versus being off by up to 1.0 before.

Known remaining limitation: still an approximation, not exact, since
`make_truth_from_scenario()` has no visibility into the real exposure's
actual distribution (only the scenario, not the generated data) — accuracy
is best for roughly symmetric, unit-scale exposures and degrades for
exposures far from that (e.g. a narrow uniform range, or a
skewed/bounded schema column). Non-identity links (`logit`/`log`) and an
`on` column that references neither the exposure nor outcome still fall
back to the old fixed-offset heuristic (no closed form / no simulatable
info in those cases either way) — same as before, not a regression.

Adjusted estimate was never affected (`expected_adjusted` was, and
remains, correctly pinned to `beta`). Regression tests added:
`tests/testthat/test-step8b-8d-scenarios.R` ("MNAR expected_naive tracks
mnar_coefficient strength, not a fixed offset").

### Deferred biases — unpark status

Still out of scope per the 8d lock unless noted done below; inventing any
remaining item without a PLAN lock stays a fail-a-PR condition.

- **Code misclassification — done (2026-09-09).** `scenario_misclassification()`
  (`R/truth.R`) + a `"misclassification"` branch in `apply_biases()`
  (`R/scenario-apply.R`): with probability `p`, a coded column's value is
  swapped for a **different value already occurring elsewhere in that same
  column** (a cyclic shift within the flagged rows — never an invented
  code, no schema/code-system access needed). `on` defaults to the
  **exposure**, unlike `mnar`/`complete_case` (which default to the
  outcome) — code misclassification is normally about the exposure/
  diagnosis code. `misclass_coefficient = 0` (default) is non-differential
  (flat rate); non-zero makes it differential (rate depends on the
  outcome's value, always — not on `on`'s own value, which is what makes
  it a genuinely different mechanic from `mnar`/`complete_case` rather
  than a copy with a new name). `expected_naive` uses the same
  deterministic-simulation approach as the MNAR/complete-case hardening
  fix; verified against real generated data: non-differential within
  ~0.001–0.05 of the actual naive fit, differential within ~3–5% relative
  (same known approximation limitation as MNAR/complete-case — exact bias
  depends on the real exposure's distribution, which truth computation
  can't see). 3 new tests, `R CMD check` 0/0/0.
- **Immortal time bias** / **left truncation** — locked and in progress,
  see `## STEP 9` below for the full design (new `time_to_event` grain,
  phased: immortal time first, left truncation second since it needs a
  different, age-varying hazard model to have any bias to demonstrate).
- **Open bias DSL** — recommend leaving this gated indefinitely, not just
  deferred. A formula-based "define your own bias" mechanism conflicts
  with what makes the AI-eval use case trustworthy: every named bias
  ships a derivable, honest `expected_naive`/`expected_adjusted`. An open
  DSL either needs a general symbolic bias solver (a research project of
  its own) or ships biases with no truth guarantee, quietly breaking the
  one thing that makes the truth oracle worth trusting.

No change to scope has actually happened — this section exists so a
future "should we add these" has a ready answer instead of re-deriving
this split from scratch.

### Polish / ship

- README: done (rewritten for new users, table of contents added).
- Renamed `zz-step8a-wire.R` -> `generate-api.R` and `write_registers()` ->
  `write_all_registers()` — done.
- Vignette: not started — no `vignettes/` directory, no `knitr`/`rmarkdown`
  in `DESCRIPTION` yet. Optional; the rewritten README may already cover
  most of what a vignette would.

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
| heaven (tagteam) `simPop` / `simAdmissionData` | Toy 1:n pattern | pnr is 1:n; learn, don't depend |
| Roche respectables | 1:N pattern | Learn, don't depend |
| cprr | Parses CPR | Does not generate; we write `gen_pnr` as joinable id only |

DST publishes **no** synthetic microdata. Closest Danish "just invent fictitious examples" is the DST rule, not a dataset.

---

## Backends — write vs call vs forbid

**We write:** schema loader, population model, grains, custom-register spec (`generate_custom_register` + CSV/tibble columns), write-out helpers (CSV default; parquet opt-in), `generate_registers`, scenario/truth objects, `gen_pnr`, catalogue adapters that honour `values_from`.

**Imports:** yaml, arrow, withr, uuid, dplyr/tibble/purrr/lubridate/rlang, truncnorm.

**Suggests:** simstudy, simDAG, fabricatr, simsurv, **sksr** (`icd10_sks` Prefix `dia`, procedures Prefix `opr`, adm), **codeCollection** (ATC `ATCKoodit`, WHO `ICD10Koodit`) as needed. Do **not** use `decoder` for Danish ICD-10 or as the ATC source of truth.

**Do not use:** synthpop, simPop, FakeDataR, fakeregs/osdc generators as engine, wakefield, DeclareDesign/simpr, duckdb in the generator, dawaR at runtime, WebR as a design driver.

---

## Team

| Role | Owns |
|---|---|
| Chief of Staff | Sequence, plan, pull the project lead in only at blocking decisions |
| Package | R package on this repo |
| Schema | Live YAML contract, grain map, SCHEMA GAPs. Notes about the guide live **here**, never as writes to registers-guide |
| Methods | Population model, scenarios, truth |
| Review | PRs against this plan |

---

## Fail a PR if it

- Writes to any repo other than `sara-schwartz/fiktive`
- Hardcodes register structure instead of walking schema columns
- Uses fakeregs' yearly random pool
- Calls output extracts
- Invents SCHEMA GAPs / DST code lists (including hardcoded `koen` 1/2 when schema is absent)
- Silent format-noise for clinical nomenclatures (ICD / ATC / SKS) instead of published catalogues or SCHEMA GAP
- Maps plain `icd10` through sksr dia / D-prefix, or emits bare WHO into `icd10_sks` LPR columns, or puts SKS surgery codes in diagnosis columns / ICD in surgery columns, or `sksr` ATC (`MC09…`) into ATC columns
- Vendors schema YAML as the source of truth
- Puts scenario coefficients in the YAML schema or in custom column CSV
- Uses synthpop or real microdata
- Implements `generate_registers()` that dumps all schema registers by default
- Invents a new grain for custom/external registers
- Defaults `fidelity` to `"messy"` (must default `"clean"` / rates 0)
- Applies NA to join keys, presence flags, or derived columns (e.g. `alder`) under fidelity
- Treats fidelity outliers as inventing invalid clinical catalogue codes
- Bakes missingness rates into registers-guide YAML
- Ships a "bias" claim without full truth fields (estimand, naive_estimator, adjusted_estimator, expected_naive, expected_adjusted)
- Puts coefficients in YAML (or custom column CSV) instead of only in `fiktive_scenario.associations`
- Treats fidelity `messy` (cosmetic MCAR) as MNAR / informative missingness or silently moves estimands under scenarios
- Invents immortal-time, left truncation, code misclassification, or an open bias DSL without a PLAN lock
- Reshapes `fiktive_scenario` instead of filling `associations` / `confounders` / `biases` slots
- Omits wiring `scenario=` through `generate_register` / `generate_registers` / `generate_custom_register` when shipping 8b–8d
