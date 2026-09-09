# fiktive

Fictitious Danish Register Data

Generate structurally valid fictitious Danish register data, for writing and
checking analysis code outside Statistics Denmark.

Code is MIT. Generated datasets are CC-BY-4.0. This package creates data; it
does not extract rows from real registers.

Author: Sara Schwartz.

## Licenses

- Package code: MIT
- Generated datasets: [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/)

This package **creates** fictitious tables. It does not extract from real
Danish registers.

## Schema

**What:** column layouts and join keys for known registers.
**Why:** so generated tables look like the real Danish register shapes your
analysis code expects.
**How:** structure comes from the live
[`steno-aarhus/registers-guide`](https://github.com/steno-aarhus/registers-guide)
schema directory (`schema/registers/`, `schema/code-systems/`,
`schema/families/`). Each call to `load_registers_schema()` stamps the git
commit used as `schema_commit`. The YAML is consumed at runtime and is not
vendored into this package as the source of truth. Pass a local schema root
(a directory that contains `registers/`) for offline use.

## Prior art

[fakeregs](https://github.com/steno-aarhus/fakeregs) by Anders Aasted Isaksen
is prior art for fictitious Danish register data. fiktive is **not** a
fakeregs clone: people are a stable spine (not a yearly random pool), columns
are driven from the live schema, and this package does not copy fakeregs
architecture.

## Usage

**What:** pick the registers you need, generate them, write CSV, then join.
**Why:** nothing is dumped by default — you opt in to each table id.
**How:** load schema → build a background population → call
`generate_registers()` → `write_register()` / `write_registers()` (CSV by
default).

```r
library(fiktive)

# Load the live registers-guide schema (stamps schema_commit on every table)
schema <- load_registers_schema()
schema$schema_commit

# Stable person spine: n people, shared across every register you generate
pop <- generate_background_population(
  n = 100,          # how many fictitious persons
  seed = 1,         # reproducible draws
  schema = schema   # stamps / validation against the loaded schema
)

# Opt-in batch: registers= is required (never a silent dump of all schema ids)
tables <- generate_registers(
  registers = c("bef", "lmdb"),  # only these two ids
  population = pop,              # join spine (pnr / foed_dag / ...)
  schema = schema,
  from = as.Date("2008-01-01"),  # window start
  to = as.Date("2009-12-31"),    # window end
  seed = 1                       # same seed → same structural draws
)

# Default on-disk format is CSV; parquet / hive year= are opt-in
write_register(tables$bef, "out/bef")       # → out/bef.csv (+ meta sidecar)
write_registers(tables, "out/registers")    # one file per name under the dir

# Join on shared population keys (pnr is the usual person key)
dplyr::inner_join(tables$bef, tables$lmdb, by = "pnr")
```

### LPR parent then child

**What:** hospital contact rows, then diagnoses (or procedures) that hang off
those contacts.
**Why:** LPR diagnoses/procedures expand from the **same** contact table that
was written — the child needs the parent's `recnum`s.
**How:** generate the parent contact register first (or include it in
`registers=`), then the child.

```r
# Parent (lpr_adm) and child (lpr_diag) in one call — parent is drawn first
lpr <- generate_registers(
  registers = c("lpr_adm", "lpr_diag"),  # parent before / with child
  population = pop,
  schema = schema,
  from = as.Date("2010-01-01"),
  to = as.Date("2010-12-31"),
  seed = 1
)
# lpr$lpr_diag joins to lpr$lpr_adm on recnum (schema join_keys)
dplyr::inner_join(lpr$lpr_diag, lpr$lpr_adm, by = "recnum")
```

### Custom / external register (structure only)

**What:** a researcher-described table that is **not** in the guide YAML.
**Why:** study-specific scores, groups, or covariates you still want to join
to BEF / other registers.
**How:** describe columns with a CSV (or tibble) of `name`, `type`, and
optional `min` / `max` / `values`. No raw rows; **no coefficients** in the
column CSV — signal goes in `scenario=` (see below).

Create a column description file first (path is whatever you pass to
`columns=` — here `columns.csv` in the working directory):

```r
# Write a full columns.csv next to your script (path must exist for generate)
writeLines(
  c(
    "name,type,min,max,values",
    "score,integer,0,10,",
    "grp,character,,,A|B|C"
  ),
  "columns.csv"
)

# Read it back if you want to inspect — this is the full file contents:
# name,type,min,max,values
# score,integer,0,10,
# grp,character,,,A|B|C

ext <- generate_custom_register(
  id = "ext_score",                       # custom register id (not in YAML)
  one_row_per = "person_reference_date",  # grain: one row per person × date
  join_keys = "pnr",                      # how it joins to BEF / population
  columns = "columns.csv",                # path to the CSV above (or a tibble)
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2009-12-31"),
  seed = 1,
  cadence = "annual"                      # snapshot dates within from/to
)

write_register(ext, "out/ext_score")  # CSV by default

# Join the custom table to BEF on pnr
dplyr::inner_join(tables$bef, ext, by = "pnr")
```

Household-year customs must pass household-side `join_keys` (e.g.
`familie_id`), never a silent `pnr` default. Expand-from-parent customs need
an already-generated `parent` table.

## Truth, scenarios, and fidelity

Three related ideas — easy to mix up. They are **not** three separate
post-processing steps.

| Idea | When | Role |
|---|---|---|
| **Scenario** | optional argument **into** `generate_*` (`scenario=`) | the signal / DGP (association, confounding, MNAR, …). Default `NULL` = independence |
| **Fidelity** | optional argument **into the same** `generate_*` call (`fidelity=`, or `na_rate` / `outlier_rate`) | cosmetic data quality (MCAR NA, rare extremes), applied **inside** generate **after** the scenario DGP |
| **Truth** | always attached to the result; retrieve with `get_truth()` **after** generate | machine-readable oracle (estimands, `expected_naive`, `expected_adjusted`). You do **not** pass truth as an input |

**One generate call.** Do **not** run a separate post-process after
`write_register()` / `write_registers()` to “add” scenario, fidelity, or
truth. Pass `scenario=` and `fidelity=` (if you want them) to
`generate_register()`, `generate_registers()`, or
`generate_custom_register()`, then read truth from the returned object.

### Why each exists

- **Why scenarios:** teaching / oracle / AI-eval. You know the β, the
  confounder, or the MNAR mechanism, and you can check whether an analysis
  recovers `expected_naive` / `expected_adjusted`.
- **Why fidelity:** pipeline rehearsal — does your code handle `is.na()`,
  extreme numerics/dates? Rates are package constants, **never** claimed DST
  rates from real microdata, and never stored in schema YAML.
- **Why truth:** know what the data should imply. Under independence,
  expected association is 0 within MC error. Under scenarios, compare your
  fit to the stamped expectations.

### Scenario vs fidelity vs truth (rules of thumb)

1. **Scenario = signal** passed **in** via `scenario=`. Omit it (or pass
   `scenario_independence()`) for structurally valid noise that joins.
2. **Fidelity = quality** passed **in** on the **same** call. Default
   `"clean"` (effective NA/outlier rates 0). `"messy"` is for pipeline
   stress only.
3. **Truth = oracle** retrieved **out** with `get_truth(x)` (and
   `get_scenario(x)` for the attached scenario object). Always present —
   including under independence.

Under scenarios, prefer `fidelity = "clean"` for oracle checks. `messy` is
for pipeline stress and **must not** be read as moving estimands (cosmetic
MCAR does not change the stamped truth).

Coefficients live **only** on the scenario object (`associations` /
confounder / bias fields), never in schema YAML or the custom column CSV.
Core backend first (no synthpop); optional Suggests such as simDAG /
simstudy may appear later for alternate backends.

### Progression: independence → association → confounding → MNAR / CC

Customs are the easiest DGP surface: describe numeric columns structurally,
then pass `scenario=` with `register.column` refs (e.g. `"study.x"`).

```r
# Structural columns only — ranges for noise; NO coefficients here
cols <- tibble::tibble(
  name = c("x", "y", "u"),
  type = c("numeric", "numeric", "numeric"),
  min = c(-2, -2, -2),
  max = c(2, 2, 2)
)

# --- Independence (default) -------------------------------------------------
# What: no planted signal. Why: joinable noise for pipeline wiring.
# How: omit scenario= (same as scenario_independence()).
study0 <- generate_custom_register(
  id = "study",
  one_row_per = "person_reference_date",
  columns = cols,
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2008-12-31"),
  seed = 1,
  cadence = "annual"
  # scenario = NULL,          # default: independence
  # fidelity = "clean"        # default: no cosmetic NA / outliers
)
get_truth(study0)$expected_naive  # 0 within MC error

# --- Association (8b) -------------------------------------------------------
# What: pure E→Y link. Why: recover a known β with an unadjusted fit.
# How: scenario_association() → pass as scenario= (fidelity stays clean).
sc <- scenario_association(
  exposure = "study.x",   # register.column ref (id + column name)
  outcome = "study.y",
  link = "identity",      # identity → OLS recovers coefficient
  coefficient = 1.5       # lives ONLY on the scenario object
)
study <- generate_custom_register(
  id = "study",
  one_row_per = "person_reference_date",
  columns = cols,
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2008-12-31"),
  seed = 1,
  scenario = sc,            # DGP overlay applied inside generate
  fidelity = "clean",       # prefer clean for oracle / AI-eval checks
  cadence = "annual"
)
tr <- get_truth(study)      # truth is an output attribute, not an input
tr$expected_naive           # 1.5
tr$expected_adjusted        # 1.5 (same as naive — no bias claim)

# --- Confounding (8c) -------------------------------------------------------
# What: U affects both E and Y. Why: naive ≠ adjusted; teach adjustment.
sc_c <- scenario_confounding(
  exposure = "study.x",
  outcome = "study.y",
  confounder = "study.u",
  coefficient = 1.0,          # E→Y causal coefficient
  affects_exposure = 1.5,     # U→E
  affects_outcome = 1.5       # U→Y
)
study_c <- generate_custom_register(
  id = "study",
  one_row_per = "person_reference_date",
  columns = cols,
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2008-12-31"),
  seed = 1,
  scenario = sc_c,
  fidelity = "clean",
  cadence = "annual"
)
get_truth(study_c)$expected_naive     # ≠ adjusted under confounding
get_truth(study_c)$expected_adjusted  # = coefficient (1.0)

# --- MNAR missingness (8d) --------------------------------------------------
# What: informative NA on a column. Why: complete-case fit ≠ full-data β.
sc_m <- scenario_mnar(
  exposure = "study.x",
  outcome = "study.y",
  coefficient = 2.0,
  mnar_coefficient = 1.2   # logit slope for P(missing)
)
study_m <- generate_custom_register(
  id = "study",
  one_row_per = "person_reference_date",
  columns = cols,
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2008-12-31"),
  seed = 1,
  scenario = sc_m,
  fidelity = "clean",      # MNAR is the scenario bias — keep fidelity clean
  cadence = "annual"
)
get_truth(study_m)$expected_naive
get_truth(study_m)$expected_adjusted

# --- Complete-case selection (8d) -------------------------------------------
# What: rows dropped with selection depending on a column.
# Why: selected-sample estimand ≠ population estimand.
sc_s <- scenario_complete_case(
  exposure = "study.x",
  outcome = "study.y",
  coefficient = 1.8,
  selection_coefficient = 1.5
)
study_s <- generate_custom_register(
  id = "study",
  one_row_per = "person_reference_date",
  columns = cols,
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2008-12-31"),
  seed = 1,
  scenario = sc_s,
  fidelity = "clean",
  cadence = "annual"
)
get_truth(study_s)$expected_naive
get_truth(study_s)$expected_adjusted
```

Quick map of constructors → truth claim:

| Scenario | Constructor | Truth claim |
|---|---|---|
| Independence | `scenario = NULL` / `scenario_independence()` | expected association **0** within MC error |
| Association | `scenario_association()` | `expected_naive` = `expected_adjusted` = coefficient; no bias claim |
| Confounding | `scenario_confounding()` | naive ≠ adjusted; full estimand / estimator fields |
| MNAR | `scenario_mnar()` | informative missingness; complete-case ≠ full-data |
| Complete-case selection | `scenario_complete_case()` | selected-sample ≠ population estimand |

### Fidelity only (pipeline stress)

**What:** MCAR-ish NA and rare numeric/date extremes.
**Why:** rehearse `is.na()` / outlier handling without claiming real DST
rates.
**How:** pass `fidelity = "messy"` (or explicit `na_rate` /
`outlier_rate` in `[0, 1]`) on the **same** `generate_*` call. Applied
after any scenario DGP inside generate — not a second user step.

- `fidelity = "clean"` (default) — effective rates 0; **prefer under
  scenarios** (truth expects clean).
- `fidelity = "messy"` — small fixed package rates; **never** DST rates;
  never stored in schema YAML. Messy + scenarios = pipeline stress only —
  do not read cosmetic MCAR as moving estimands.
- Optional `na_rate` / `outlier_rate` overrides win when set; outputs stamp
  **preset + effective rates** via `register_stamps()`.

NA is applied only to non-key, non-derived columns. Outliers only on
numeric/date (never inventing invalid clinical catalogue codes). Join keys,
presence flags, and derived columns (e.g. `alder`) stay complete.

```r
# Independence + messy fidelity: stress-test NA / extremes in one call
bef <- generate_register(
  "bef",
  pop,
  schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2009-12-31"),
  seed = 1,
  fidelity = "messy"   # applied inside generate after the (null) scenario
)
get_truth(bef)$expected_naive   # 0 under independence
register_stamps(bef)$fidelity   # "messy"
register_stamps(bef)$na_rate    # effective rate used
```
