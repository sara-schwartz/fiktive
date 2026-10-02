# fiktive 0.0.0.9000

fiktive has not been released yet (no version bump past this placeholder,
no tag). This first entry describes what the package can do as of now,
rather than a commit-by-commit history.

## Core generation

* `generate_register()` / `generate_registers()` generate fictitious data
  for real Danish administrative registers (BEF, LPR, LMDB, MFR, cancer,
  deaths, migrations, labs, ...), driven entirely by the
  [registers-guide](https://github.com/steno-aarhus/registers-guide)
  schema -- no hardcoded column lists.
* `generate_background_population()` creates the shared population
  (`pnr`, `foed_dag`, `koen`, `familie_id`) that every register call joins
  on, so the same fake people appear consistently across tables.
* `generate_custom_register()` describes a register that isn't in the
  schema at all (a study cohort, a questionnaire, a set of scores) and
  generates structural noise for it the same way, joinable via `pnr` or a
  custom household key.
* LPR2's and LPR psykiatri's other real child tables -- operations
  (`lpr_sksopr`/`lpr_afl`/`lpr_opr` and their `t_psyk_*` psychiatric
  equivalents), outpatient visits (`lpr_bes`), waiting-period tracking
  (`lpr_pas`/`lpr_vente`), accident codes (`lpr_ulyk`), birth records
  (`lpr_foedsler`, with curated newborn length/weight/parity and visit
  counts), and discharge destination (`lpr_udtilsgh`/`t_psyk_udtilsgh`) --
  generate the same way as `lpr_diag`/`lpr_sksopr` already did, joined to
  their parent admission on `recnum`.
* Structural noise by default (every code valid, drawn uniformly, no
  attempt to look like real Denmark); opt into `constraints=` for
  real-world-shaped defaults (`weighted_municipality`,
  `valid_diagnosis_sex_age`, `weighted_lprindberetningssystem`).
* Curated, realistic value ranges (not generic noise) for columns where a
  generic uniform draw would be structurally wrong -- gestational age,
  Apgar scores, lab reference intervals, clinical vitals, and more -- with
  a documented, two-tier "cited vs. plausible-clinical" provenance split
  throughout.

## Bundled DCH / DCH-NG cohort data

* `dch` and `dchng` (Diet, Cancer and Health / ...and Next Generations)
  ship bundled inside the package and generate exactly like any DST
  register. Variable name, type, and label only, per the cohorts' own
  data-sharing approval -- no real data, no license to reuse the metadata
  outside fiktive.
* Each collapses ~8 (dch) or ~19 (dchng) real underlying SAS datasets into
  one register per cohort; a `dataset` field on every column (surfaced by
  `codebook()`) still records which real table a column came from.
* Numeric/categorical ranges are two-tier: a handful of anthropometric/
  biomarker anchors are cited directly from each cohort's own published
  profile paper (Lacoppidan et al. 2015 for dch; Zhang et al. 2025 for
  dchng); `dch_range_source()` (or `codebook()`'s `value_source` column)
  reports which tier a given column is in.
* `vaegt` (weight) is derived from `bmi` and `stahqjde` (height) so the
  three can never disagree on the same row -- the one cross-column
  reconciliation fiktive does for DCH/DCH-NG. `vaegtc`/`energitot`/
  nutrient `_tot`/`_ffq`/`_ktsk` trios are not reconciled against their
  own components -- documented, not silently wrong.
* Both cohorts' real 1993-12/1997-05 and 2015-03/2019-12 recruitment
  windows are respected: a requested `from`/`to` outside that window
  correctly returns zero rows instead of fabricating out-of-era
  participation dates.

## Code systems and external catalogues

* Real code systems for diagnosis codes (ICD-10, ICD-10-SKS via `sksr`),
  procedures (SKS), ATC drug codes, and DST classifications (`koen`,
  `kom`, ...) -- never invented lists.
* Lab analyte values (`lab_dm_forsker`, `labka`) use real NORIP reference
  intervals for 25 common analytes where the value is grounded in Rustad
  et al. 2004's own Table I, not guessed.
* External catalogues fiktive won't fabricate (LabTerm/NPU codes, WHOCC's
  ATC index, DST's DISCO-08/NACE classifications for `akm`) are opt-in
  runtime fetches (`load_labterm_catalogue()`, `load_whocc_atc_catalogue()`,
  `load_csv_code_system()`) -- off by default so tests and offline use
  stay deterministic; generating a column that needs one without it
  configured is a `schema_gap()` naming exactly what's missing and how to
  supply it, never silently-wrong noise.
* `schema_gap()` is the general "the schema doesn't provide this, don't
  invent it" signal used throughout the package.

## Scenarios: planting a known, testable answer

* `scenario_association()`, `scenario_confounding()`,
  `scenario_misclassification()`, `scenario_mnar()`,
  `scenario_complete_case()`, `scenario_immortal_time()`, and
  `scenario_left_truncation()` overlay a specific, documented relationship
  (or bias) on top of the structural draw -- for testing analysis code
  against a *known* answer, not just plausible-looking background noise.
* `get_truth()` returns the planted answer for anything generated with a
  scenario; `get_scenario()` returns the scenario object itself. Neither
  needs passing in by hand -- both come free with the generated table.
* `time_to_event` is a dedicated grain (via `generate_custom_register()`)
  for immortal time bias and left truncation testing, with a fixed
  column shape driven entirely by the scenario.

## Fidelity, documentation, and I/O

* `fidelity = "messy"` (plus `na_rate`/`outlier_rate` overrides) adds
  cosmetic missingness/outliers on top of a clean structural draw, for
  pipeline robustness testing -- independent of what any scenario plants.
* `codebook()` surfaces registers-guide's/fiktive's own human-readable
  column and value labels (Danish and English) for any register, whether
  or not you've generated anything yet; `label_columns()` attaches that
  same text as a `"label"` attribute directly on a generated table's
  columns, without renaming them.
* `register_stamps()` reports what a generated table's fidelity/seed/
  schema provenance actually was.
* `write_register()` / `write_all_registers()` write generated tables to
  CSV or Parquet, including hive-partitioned by year.
