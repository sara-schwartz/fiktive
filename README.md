# fiktive

Generate realistic **fake** Danish register data — so you can write, test,
and teach analysis code without needing real access to Statistics Denmark
(DST).

The data isn't real. It's shaped exactly like the real thing (same column
names, same codes, same join keys), but every value is randomly generated.
Nothing in it comes from an actual person.

## Contents

- [Why would I use this?](#why-would-i-use-this)
- [Install](#install)
- [The 5-minute quickstart](#the-5-minute-quickstart)
- [What registers can I generate?](#what-registers-can-i-generate)
- [Saving your data to files](#saving-your-data-to-files)
- [Joining tables together](#joining-tables-together)
- [Hospital data needs two tables](#hospital-data-needs-two-tables)
- [Making up your own columns](#making-up-your-own-columns)
- [Checking whether your analysis code is actually correct](#checking-whether-your-analysis-code-is-actually-correct)
- [Testing for immortal time bias (advanced)](#testing-for-immortal-time-bias-advanced)
- [Making data messier (to test your pipeline's robustness)](#making-data-messier-to-test-your-pipelines-robustness)
- [Where the data model comes from](#where-the-data-model-comes-from)
- [Licenses](#licenses)
- [Available registers](#available-registers)

## Why would I use this?

- **Write your analysis script before you have DST access.** Get your
  pipeline working end-to-end on fake data with the right shape, so it's
  ready to run the moment you're inside the real DST environment.
- **Check that your analysis code is actually correct.** fiktive can
  secretly bake a known, true relationship into the data (e.g. "X causes a
  2-point increase in Y") and hand you back that true answer. Run your
  analysis and check whether it finds the number you were told to expect.
- **Teach or demo register-based analysis** without touching real,
  sensitive data.
- **Stress-test your code** against missing values and extreme outliers,
  without needing real messy data to do it.

## Install

```r
install.packages("remotes")   # if you don't already have it
remotes::install_github("sara-schwartz/fiktive")
```

Everything fiktive needs (dplyr, tibble, sksr, codeCollection, etc.)
installs automatically — no extra steps.

## The 5-minute quickstart

Every fiktive script follows the same three steps: **load the schema → make
a population of fake people → generate the registers you want.**

```r
library(fiktive)

# 1. Load the rulebook: column names, types, and codes for real Danish registers
schema <- load_registers_schema()

# 2. Make some fake people (the same people appear in every table you generate)
pop <- generate_background_population(
  n = 100,        # however many people you want -- 100 is just an example
  seed = 1,       # any number; the same seed always gives the same people
  schema = schema
)

# 3. Generate the registers you want, for those people
tables <- generate_registers(
  registers = c("bef", "lmdb"),   # "population register" + "prescriptions" -- pick any ids from the table below
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),   # window start -- these dates are just an example, use your own
  to = as.Date("2009-12-31"),     # window end
  seed = 1                        # any number; same seed -> same fake data every time
)

tables$bef    # a tibble: fake population snapshots
tables$lmdb   # a tibble: fake dispensed prescriptions
```

`tables$bef` and `tables$lmdb` are ordinary tibbles — inspect them, filter
them, join them, just like any other data frame.

`seed = 1` makes it reproducible: run this exact code again and you get
back the exact same fake data.

## What registers can I generate?

Anything Statistics Denmark actually has a register for, as long as
[`registers-guide`](https://github.com/steno-aarhus/registers-guide) (the
project fiktive reads its rulebook from) has documented its columns. See the
full, current list at the bottom of this page:
**[Available registers](#available-registers)**.

A few common ones to get started:

| id | What it is |
|---|---|
| `bef` | Population register — who's alive, where they live, marital status |
| `lmdb` | Prescriptions dispensed at pharmacies |
| `lpr_adm` / `lpr_diag` | Hospital contacts and their diagnoses (see [below](#hospital-data-needs-two-tables)) |
| `dod` | Deaths |
| `udda` | Education |
| `akm` | Employment status |
| `mfr` | Births |

You ask for a register by putting its id in `registers = c(...)` — that's
the whole interface, no matter which register it is.

## Saving your data to files

`write_register()` saves **one** table. `write_all_registers()` saves **every**
table in a named list (like `tables` from `generate_registers()`) in one
call — it's just a shortcut for calling `write_register()` on each one
yourself.

```r
write_register(tables$bef, "out/bef")      # one table -> writes out/bef.csv
write_all_registers(tables, "out/registers")   # whole list -> writes out/registers/bef.csv, out/registers/lmdb.csv, ...
```

CSV is the default. For parquet instead, add `format = "parquet"` to either
function:

```r
write_register(tables$bef, "out/bef", format = "parquet")    # writes out/bef.parquet
write_all_registers(tables, "out/registers", format = "parquet") # same, for every table
```

Either way, each file also gets a small `.meta.yaml` sidecar recording
exactly how it was generated, so you can always prove later which schema
version and seed made a given file.

## Joining tables together

Every table generated from the same `pop` shares the same people (via
`pnr`, the person-id column), so you join them just like real register
data:

```r
joined <- dplyr::inner_join(
  tables$bef, tables$lmdb,
  by = "pnr", relationship = "many-to-many"
)
```

`relationship = "many-to-many"` is there because `bef` has several
snapshots per person and `lmdb` has several prescriptions per person — a
genuinely many-rows-to-many-rows join, same as in real register data.

## Hospital data needs two tables

Hospital registers work a little differently: one table holds the
**contact** (the hospital visit itself), and a separate table holds the
**diagnoses** attached to that visit, because in real life one visit can
have several diagnoses. So the diagnosis table has no `pnr` of its own — it
only points back to its visit.

Ask for both in the same call, and join them on `recnum` instead of `pnr`:

```r
lpr <- generate_registers(
  registers = c("lpr_adm", "lpr_diag"),   # lpr_adm = the visit, lpr_diag = its diagnoses
  population = pop,
  schema = schema,
  from = as.Date("2010-01-01"),   # this call can use its own window -- doesn't have to match other calls
  to = as.Date("2010-12-31"),
  seed = 1
)
diagnoses_with_visits <- dplyr::inner_join(lpr$lpr_diag, lpr$lpr_adm, by = "recnum")
```

A couple of things worth knowing:

- Order in `registers=` doesn't matter — just make sure both ids are in the
  list, or you won't get the one you left out back to join to.
- `lpr`/`tables` came from two separate `generate_registers()` calls with
  different windows, but they share the same `pop`, so `tables$bef` and
  `lpr$lpr_adm` still join on `pnr` if you need both together.

## Making up your own columns

Sometimes you need a column that isn't a real DST register — a study
score, a group label. `generate_custom_register()` makes one up
structurally (you describe the columns; fiktive fills in plausible fake
values) and it joins to everything else via `pnr`:

```r
# Describe your columns: a type, plus either a min/max range or a set of values
cols <- tibble::tibble(
  name   = c("score", "grp"),
  type   = c("integer", "character"),
  min    = c(0, NA),
  max    = c(10, NA),
  values = c(NA, "A|B|C")
)

ext <- generate_custom_register(
  id = "my_study",   # any name you want for this table
  one_row_per = "person_reference_date",   # one row per person per snapshot date
  columns = cols,
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),   # dates are just an example, use your own window
  to = as.Date("2009-12-31"),
  seed = 1,
  cadence = "annual"   # one snapshot per year ("quarterly" is the other option)
)

joined <- dplyr::inner_join(tables$bef, ext, by = "pnr", relationship = "many-to-many")
```

## Checking whether your analysis code is actually correct

Normally when you test analysis code, you don't actually know what the
right answer is supposed to be — you're just checking that it runs and the
output looks plausible. fiktive lets you flip that around: you tell it a
real, exact relationship to secretly build into the data ("increasing `x`
by 1 always increases `y` by 1.5, on average"), it generates fake data with
that relationship baked in, and it hands you back that true number. You
then run **your own** analysis code on the fake data and check whether it
finds the same number. If it doesn't, the bug is in your code — not the
data.

Three steps: **describe the relationship to plant → generate data with
it → compare your analysis against fiktive's true answer.**

**Step 1 — describe the relationship.** `scenario_association()` says
"column `x` affects column `y`, and here's the true effect size":

```r
# "increasing x by 1 increases y by 1.5, on average" -- the true, known answer
sc <- scenario_association(exposure = "study.x", outcome = "study.y", coefficient = 1.5)
```

`exposure` is the column doing the affecting, `outcome` is the column
being affected, `coefficient` is the true effect size (change this to
whatever number you want to test against). `"study.x"` means "column `x`
on the table called `study`" — the table you generate next.

**Step 2 — generate the data with that relationship.** Same
`generate_custom_register()` as in [Making up your own
columns](#making-up-your-own-columns) above, just with `scenario = sc`
added:

```r
cols <- tibble::tibble(
  name = c("x", "y"), type = c("numeric", "numeric"),
  min = c(-2, -2), max = c(2, 2)
)

study <- generate_custom_register(
  id = "study", one_row_per = "person_reference_date", columns = cols,
  population = pop, schema = schema,
  from = as.Date("2008-01-01"), to = as.Date("2008-12-31"),
  seed = 1, scenario = sc, cadence = "annual"
)
```

**Step 3 — run your own analysis, then compare it to the true answer.**
`get_truth()` gives you back the answer fiktive planted — it comes free
with anything you generate, you never pass it in yourself:

```r
fit <- lm(y ~ x, data = study)
coef(fit)[["x"]]                  # your analysis's answer -- should come out close to 1.5

get_truth(study)$expected_naive   # fiktive's true answer: 1.5
```

If those two numbers are close, your analysis code works. If they're way
off, something in your code needs fixing — not the data.

Beyond a plain association, fiktive can plant trickier situations, so you
can test whether your code handles them correctly too:

| Function | Plants... | Use it to test... |
|---|---|---|
| `scenario_association()` | a straight X → Y effect | your basic model recovers the right coefficient |
| `scenario_confounding()` | a third variable biasing the naive estimate | your code actually adjusts for confounders |
| `scenario_mnar()` | missing values that depend on the value itself | your code doesn't ignore informative missingness |
| `scenario_complete_case()` | rows dropped depending on a column's value | your "complete case" analysis isn't secretly biased |
| `scenario_misclassification()` | a coded column's values swapped for other real codes | your code isn't thrown off by mislabeled diagnosis/drug codes |

All five work the same way as the example above: build the scenario, pass
it as `scenario=`, then compare your own fit against
`get_truth(x)$expected_naive` (the answer a straightforward analysis
should find) and `$expected_adjusted` (the answer after doing it
properly — e.g. adjusting for the confounder). For a plain association
those two are the same number; for the trickier scenarios they're
deliberately different, which is exactly what lets you test whether your
code does the adjustment correctly. Run `?scenario_confounding`,
`?scenario_mnar`, `?scenario_complete_case`, or `?scenario_misclassification`
for each one's full parameter list and a runnable example.

Leave `scenario=` out entirely (or generate any ordinary register like
`bef`) and you get **independence** — no planted relationship;
`get_truth(x)$expected_naive` comes back `0`.

## Testing for immortal time bias (advanced)

This one works differently from the scenarios above: instead of adding a
bias on top of an ordinary table, it generates a **survival cohort** —
people with an entry time, an exposure that starts at some point during
follow-up (or never), and an event (or censoring) time. Immortal time bias
is a classic mistake: treating "ever exposed" as if it were true from the
start, which credits exposed people with survival time before their
exposure actually began — making the exposure look protective even when it
does nothing.

```r
sc <- scenario_immortal_time(
  baseline_hazard = 0.1,     # unexposed event rate per year
  true_hazard_ratio = 1,     # 1 = exposure truly does nothing -- isolates the bias
  exposure_rate = 0.2,       # how quickly people who ever get exposed, do
  horizon_years = 5          # match this to your to - from window below
)

cohort <- generate_custom_register(
  id = "cohort",
  one_row_per = "time_to_event",   # fixed shape: entry_time, exit_time, event, exposure_start_time, ever_exposed
  population = pop,
  schema = schema,
  from = as.Date("2010-01-01"),
  to = as.Date("2015-01-01"),      # 5 years, matching horizon_years above
  seed = 1,
  scenario = sc
)

# The mistake: exposure treated as fixed from the start
survival::coxph(survival::Surv(entry_time, exit_time, event) ~ ever_exposed, data = cohort)
# -> hazard ratio well below 1, even though true_hazard_ratio = 1

get_truth(cohort)$expected_naive     # the biased answer the mistake above produces
get_truth(cohort)$expected_adjusted  # 1 -- the true answer, recovered by correctly
                                      # treating exposure as time-varying (see ?scenario_immortal_time
                                      # for a worked example using survival::tmerge())
```

`one_row_per = "time_to_event"` always needs a `scenario_immortal_time()`
— there's no independence version of this grain, and `columns=`/`fidelity=`
don't apply to it (its shape is fixed, not user-described).

## Making data messier (to test your pipeline's robustness)

Real data has missing values and the occasional wild outlier. To rehearse
how your code handles that, ask for `fidelity = "messy"` on any generate
call:

```r
bef_messy <- generate_register(
  "bef", pop, schema,
  from = as.Date("2008-01-01"), to = as.Date("2009-12-31"),
  seed = 1,
  fidelity = "messy"   # sprinkles in some NAs and extreme values
)
```

Default is `fidelity = "clean"` (no artificial noise) — use that whenever
you're checking `get_truth()` against a scenario, so cosmetic messiness
doesn't get mixed up with the relationship you actually planted.

## Where the data model comes from

fiktive doesn't invent what a Danish register looks like — it reads the
column layouts live from
[`steno-aarhus/registers-guide`](https://github.com/steno-aarhus/registers-guide),
a project that documents the real DST register structures. That means:

- The schema can be updated any time, without a new fiktive release.
- To work offline, pass a local copy instead of fetching live:
  `load_registers_schema(source = "path/to/local/registers-guide/schema")`.
- If fiktive doesn't know how to fill in a value safely, it stops with a
  clear error rather than guessing — see below.

### "SCHEMA GAP" errors

If you see an error starting with `SCHEMA GAP:`, fiktive is telling you it
deliberately refused to make something up, rather than risk giving you
subtly wrong fake data. This usually means either a column needs
information the live schema doesn't have yet, or (for a few registers) the
real-world code list mixes two eras of history with no way to tell them
apart safely — for example, Danish municipality codes were reorganized in
2007, and some old codes were reused for entirely different, unrelated
municipalities. This isn't something to work around in your own code — it's
a gap in the schema itself, worth reporting upstream.

## Licenses

- Package code: MIT
- Generated (fake) datasets: [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/)

fiktive **creates** fictitious tables. It never extracts rows from a real
Danish register.

## Available registers

Pass any `id` below to `registers=` in `generate_register()` /
`generate_registers()` — no `generate_custom_register()` step needed. That
function is only for columns the guide doesn't define (see [Making up your
own columns](#making-up-your-own-columns) above).

This reflects the live schema at the time of writing (27 registers). Since
fiktive loads the schema live rather than vendoring it, the guide can add or
change registers between releases — run
`names(load_registers_schema()$registers)` for the current, definitive set.

| id | Register | Grain | Notes |
|---|---|---|---|
| `akm` | Arbejdsklassifikationsmodulet (labour classification) | person_reference_date | Socioeconomic status per person per year (employed, unemployed, pensioner, …) |
| `bef` | Befolkningen (population register) | person_reference_date | Quarterly population snapshot: demographics, municipality, marital status |
| `cancer` | Cancerregisteret | event_from_person | One row per incident cancer diagnosis |
| `dod` | Døde i Danmark (deaths) | event_from_person | One row per death; date of death |
| `dodsaars` | Dødsårssagsregistret | event_from_person | Cause of death 1970–2001. Closed |
| `dodsaasg` | Dødsårsagsregister | event_from_person | Cause of death 2002–2022. Closed |
| `dodsaarsager` | Dødsårsagsregister | event_from_person | Cause of death 2022–. Current |
| `faik` | Familieindkomster (family income) | household_year | Household-level income, keyed on household not person |
| `lab_dm_forsker` | Laboratoriedatabasens Forskertabel | event_from_person | Lab test results per request |
| `lmdb` | Lægemiddeldatabasen (prescription register) | event_from_person | One row per dispensed prescription |
| `lpr_adm` | Landspatientregistret (LPR2) — admin/contact | event_from_person | Parent for `lpr_diag` / `lpr_sksopr` / `lpr_sksube` |
| `lpr_diag` | LPR2 — diagnoser | expand_from_parent | Child of `lpr_adm` (join on `recnum`) |
| `lpr_sksopr` | LPR2 — operationer | expand_from_parent | Child of `lpr_adm` (join on `recnum`) |
| `lpr_sksube` | LPR2 — undersøgelser og behandlinger | expand_from_parent | Child of `lpr_adm` (join on `recnum`) |
| `lpr_a_kontakt` | LPR3 — kontaktoplysninger | event_from_person | Parent for `lpr_a_diagnose` / `lpr_a_procregistrering` |
| `lpr_a_diagnose` | LPR3 — diagnoseoplysning | expand_from_parent | Child of `lpr_a_kontakt` (join on `dw_ek_kontakt`) |
| `lpr_a_procregistrering` | LPR3 — procedureregistreringer | expand_from_parent | Child of `lpr_a_kontakt` (join on `dw_ek_kontakt`) |
| `t_psyk_adm` | LPR psykiatri — administrative oplysninger | event_from_person | Parent for `t_psyk_diag`; separate from `lpr_adm` |
| `t_psyk_diag` | LPR psykiatri — diagnoser | expand_from_parent | Child of `t_psyk_adm` |
| `mfr` | MFR — levendefødte | event_from_person | One row per live birth (mother + child) |
| `sysi` | Sygesikring (6-cifret) | event_from_person | Primary-care fee settlements |
| `sssy` | Sygesikring (6-cifret) | event_from_person | Continuation of `sysi`; same shape |
| `udda` | Uddannelser (BUE, education) | person_reference_date | Completed-education code per person per year |
| `vnds` | Historiske vandringer (migrations) | event_from_person | One row per migration event (immigration or emigration) |
| `vnds_hist` | Historiske vandringer 1973–2004 | event_from_person | Frozen; closed, not updated |
| `vnds_ind` | Indvandringer (immigrations, 2005–) | event_from_person | One row per immigration |
| `vnds_ud` | Udvandringer (emigrations, 2005–) | event_from_person | One row per emigration |

`expand_from_parent` registers need their parent generated in the same
`registers=` call (or already generated) — see [Hospital data needs two
tables](#hospital-data-needs-two-tables) above.
