# The three public generate_*() entry points: generate_register(),
# generate_registers(), generate_custom_register(). Each wires independence /
# association / confounding / named biases + opt-in fidelity around the grain
# dispatch in generate.R / generate-pipeline.R, without reshaping it.
#
# Order: structural draw → scenario DGP → fidelity (default clean) → stamps →
# truth/scenario attrs. Messy fidelity after scenarios is for pipeline stress
# only; stamped truth expects clean (cosmetic MCAR must not silently move
# estimands).

#' Generate a fictitious register table
#'
#' `scenario = NULL` is independence: structurally valid noise that joins.
#' Pass a [scenario_association()], [scenario_confounding()],
#' [scenario_mnar()], or [scenario_complete_case()] object to overlay a
#' known DGP after structural generation. Coefficients live only on the
#' scenario — never in schema YAML.
#'
#' Snapshot grains: `bef` (quarterly), `udda` and `akm` (annual).
#' Event-from-person: `dod`, `lmdb`, `vnds`, `cancer`, `mfr` / Levendefoedte
#' (empty tables are valid; coverage ends 2018), `lab_dm_forsker`
#' (`analysiscode` from LabTerm / published NPU; coverage 2008-2025).
#' Expand-from-parent: LPR2 (`lpr_adm` then `lpr_diag` / `lpr_sksopr` /
#' `lpr_sksube`) and LPR3 (`lpr_a_kontakt` then `lpr_a_diagnose` /
#' `lpr_a_procregistrering`). Diagnoses/procedures are generated off the
#' **same** contact table that was written. Household-year: `faik` (one row
#' per `familie_id` × year; `pnr` blank when present). Branch on `code_system`
#' id: `icd10_sks` → `sksr::SKS_labels` Prefix `dia` (D-prefixed, e.g. DE119);
#' plain `icd10` → WHO via `codeCollection::ICD10Koodit` (E119, never sksr);
#' `icd8` / `previous_code_system` until 1993 → honour or SCHEMA GAP.
#' Procedures sample `sksr` Prefix `opr` / related. LMDB `atc` samples WHO-form
#' codes from `codeCollection::ATCKoodit` (or WHOCC dump). Dispatch prefers
#' schema `one_row_per` when present. Psych LPR (`t_psyk_*`) is not this step.
#' Never mix `vnds` with `vnds_hist` / `vnds_ind` / `vnds_ud`. Other schema
#' registers error as not implemented; unknown ids / novel grains are a
#' SCHEMA GAP.
#'
#' @param register Lowercase register id (fastreg name), e.g. `"bef"`.
#' @param population Persons table from [generate_background_population()].
#' @param schema Schema from [load_registers_schema()].
#' @param from Start of the requested window (Date or coercible).
#' @param to End of the requested window (Date or coercible).
#' @param seed Optional RNG seed. Restored on exit.
#' @param scenario `NULL` (independence) or a `fiktive_scenario` from the
#'   scenario_* constructors.
#' @param fidelity `"clean"` (default) or `"messy"`. Under scenarios, prefer
#'   clean; messy is for pipeline stress and must not be read as moving
#'   estimands.
#' @param na_rate,outlier_rate Optional fidelity rate overrides in `[0, 1]`.
#' @param realistic Default `FALSE`: structural noise only, uniform across
#'   valid codes (e.g. `kom` drawn evenly across municipalities). `TRUE`
#'   opts into a small set of real-world-shaped defaults: `kom` weighted by
#'   real municipality population, and diagnosis codes (`icd10`/`icd10_sks`)
#'   never assigned a chapter that's impossible for the patient's sex or age
#'   (e.g. a pregnancy code to a man). Does not change what any scenario/
#'   truth claims — see `?scenario_association` if you want a planted,
#'   documented relationship instead of realistic-looking background shape.
#'
#' @return A tibble whose columns are a subset of the schema column names
#'   for `register`. Zero rows is a valid event or child table.
#' @export
generate_register <- function(register, population, schema, from, to,
                              seed = NULL, scenario = NULL,
                              fidelity = c("clean", "messy"),
                              na_rate = NULL, outlier_rate = NULL,
                              realistic = FALSE) {
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  sc <- if (is.null(scenario)) {
    scenario_independence()
  } else {
    validate_fiktive_scenario(scenario)
  }
  fidelity_info <- resolve_fidelity(fidelity, na_rate = na_rate, outlier_rate = outlier_rate)
  register <- tolower(as.character(register)[[1]])
  spec <- schema$registers[[register]]
  if (is.null(spec)) {
    schema_gap(
      sprintf("register id '%s' is not in the schema.", register),
      "a register id that exists in registers/*.yaml"
    )
  }
  tbl <- with_realistic(realistic, {
    dispatch_generate_register(register, spec, population, schema, from, to, seed)
  })
  tbl <- with_rng_seed(seed, {
    # Scenario DGP first (associations / confounding / biases), then fidelity.
    tbl <- apply_scenario(tbl, sc, register_hint = register)
    apply_fidelity(tbl, spec, fidelity_info)
  })
  tbl <- stamp_generation(tbl, schema = schema, seed = seed)
  attach_run_meta(tbl, scenario = sc)
}

#' Generate several schema registers (opt-in batch)
#'
#' Builds **only** the named schema registers. `registers` is **required** —
#' there is no silent default of every implemented id. Customs are not accepted
#' here; use [generate_custom_register()] one-at-a-time.
#'
#' When `scenario` associations span registers, tables are drawn structurally
#' first, then the scenario is applied across the list (joining on `pnr` when
#' needed), then fidelity is applied per table.
#'
#' @param registers Character vector of schema register ids (required).
#' @param population Persons table from [generate_background_population()].
#' @param schema Schema from [load_registers_schema()].
#' @param from Start of the requested window (Date or coercible).
#' @param to End of the requested window (Date or coercible).
#' @param seed Optional RNG seed. Restored on exit (per register call).
#' @param scenario `NULL` (independence) or a `fiktive_scenario`.
#' @param fidelity `"clean"` (default) or `"messy"`.
#' @param na_rate,outlier_rate Optional fidelity rate overrides in `[0, 1]`.
#' @param realistic Default `FALSE`. See [generate_register()] for what
#'   `TRUE` opts into (real municipality weighting, sex/age-coherent
#'   diagnosis codes).
#'
#' @return A named list of tibbles, one per requested id (lowercase names).
#' @export
generate_registers <- function(registers, population, schema, from, to,
                               seed = NULL, scenario = NULL,
                               fidelity = c("clean", "messy"),
                               na_rate = NULL, outlier_rate = NULL,
                               realistic = FALSE) {
  if (missing(registers)) {
    stop(
      "`registers` is required. Pass an explicit character vector of schema ids; ",
      "refusing a silent dump of all registers.",
      call. = FALSE
    )
  }
  if (is.null(registers) || !length(registers)) {
    stop("`registers` must be a non-empty character vector of schema ids.", call. = FALSE)
  }
  registers <- as.character(registers)
  if (anyNA(registers) || any(!nzchar(registers))) {
    stop("`registers` must be a non-empty character vector of schema ids.", call. = FALSE)
  }
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  sc <- if (is.null(scenario)) {
    scenario_independence()
  } else {
    validate_fiktive_scenario(scenario)
  }
  fidelity <- match.arg(fidelity)
  fidelity_info <- resolve_fidelity(fidelity, na_rate = na_rate, outlier_rate = outlier_rate)
  ids <- tolower(registers)
  out <- vector("list", length(ids))
  names(out) <- ids
  # Structural draw only (no scenario / fidelity yet) so cross-register
  # associations can join before cosmetic missingness.
  with_realistic(realistic, {
    for (i in seq_along(ids)) {
      rid <- ids[[i]]
      spec <- schema$registers[[rid]]
      if (is.null(spec)) {
        schema_gap(
          sprintf("register id '%s' is not in the schema.", rid),
          "a register id that exists in registers/*.yaml"
        )
      }
      tbl <- dispatch_generate_register(rid, spec, population, schema, from, to, seed)
      tbl <- stamp_generation(tbl, schema = schema, seed = seed)
      out[[i]] <- tbl
    }
  })
  out <- with_rng_seed(seed, {
    out <- apply_scenario(out, sc, register_hint = NULL)
    for (i in seq_along(ids)) {
      rid <- ids[[i]]
      spec <- schema$registers[[rid]]
      out[[i]] <- apply_fidelity(out[[i]], spec, fidelity_info)
      out[[i]] <- stamp_generation(out[[i]], schema = schema, seed = seed)
      out[[i]] <- attach_run_meta(out[[i]], scenario = sc)
    }
    out
  })
  attach_run_meta(out, scenario = sc)
}

#' Generate a custom / external register (structure only + optional scenario)
#'
#' Front door for researcher-described tables that are **not** in the guide
#' YAML. Register metadata is passed as R arguments; columns come from a CSV
#' path or tibble with `name`, `type`, and optional `min` / `max` / `values`
#' (structural noise only — **no coefficients**). Pass `scenario` to overlay
#' association / confounding / MNAR / complete-case after the structural draw.
#'
#' Grains: any existing schema grain (`person`, `person_reference_date`,
#' `event_from_person`, `expand_from_parent`, `household_year`), plus
#' `time_to_event` (STEP 9: [scenario_immortal_time()] /
#' [scenario_left_truncation()]). A novel grain is a SCHEMA GAP. For
#' `household_year`, `join_keys` must be household-side (e.g. `familie_id`)
#' — never a silent `pnr` default. `expand_from_parent` requires an
#' already-generated `parent` table. `time_to_event` ignores `columns`
#' entirely — its column shape is fixed (`entry_time`/`exit_time`/`event`/
#' `exposure_start_time`/`ever_exposed` for immortal time,
#' `entry_age`/`exit_age`/`event`/`group` for left truncation), because the
#' correlation between them, driven by `scenario`, is the whole point — and
#' requires a `scenario` built with [scenario_immortal_time()] or
#' [scenario_left_truncation()]; there is no independence version of this
#' grain.
#'
#' @param id Custom register id (not looked up in schema YAML).
#' @param one_row_per Grain (see details).
#' @param join_keys Character vector of join keys. Defaults to `pnr` for
#'   person-side grains; required and household-side for `household_year`.
#' @param columns CSV path or tibble/data.frame with columns `name`, `type`,
#'   and optional `min`, `max`, `values`. Extra columns (e.g. coefficients)
#'   are ignored — do not put DGP coeffs here. Not used for
#'   `one_row_per = "time_to_event"` (see Details).
#' @param population Persons table from [generate_background_population()].
#' @param schema Schema from [load_registers_schema()] (stamps / population).
#' @param from,to Window (Date or coercible).
#' @param seed Optional RNG seed.
#' @param scenario `NULL` (independence) or a `fiktive_scenario`. Required
#'   (a [scenario_immortal_time()] or [scenario_left_truncation()]) for
#'   `one_row_per = "time_to_event"`.
#' @param parent Already-generated parent table when
#'   `one_row_per = "expand_from_parent"`.
#' @param cadence Snapshot cadence: `"annual"` (default) or `"quarterly"`.
#' @param fidelity `"clean"` (default) or `"messy"`. Not applied for
#'   `one_row_per = "time_to_event"` (no safe subset of its fixed columns
#'   for cosmetic noise without corrupting the survival times).
#' @param na_rate,outlier_rate Optional fidelity rate overrides in `[0, 1]`.
#'   Same `time_to_event` exception as `fidelity`.
#'
#' @return A tibble of structural noise that joins on `join_keys`.
#' @export
generate_custom_register <- function(id, one_row_per, join_keys = NULL, columns = NULL,
                                     population, schema, from, to,
                                     seed = NULL, scenario = NULL,
                                     parent = NULL, cadence = NULL,
                                     fidelity = c("clean", "messy"),
                                     na_rate = NULL, outlier_rate = NULL) {
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  sc <- if (is.null(scenario)) {
    scenario_independence()
  } else {
    validate_fiktive_scenario(scenario)
  }
  fidelity_info <- resolve_fidelity(fidelity, na_rate = na_rate, outlier_rate = outlier_rate)
  id <- as.character(id)[[1]]
  if (!nzchar(id)) {
    stop("`id` must be a non-empty string.", call. = FALSE)
  }
  grain <- as.character(one_row_per)[[1]]
  if (!grain %in% .KNOWN_GRAINS || identical(grain, "unknown")) {
    schema_gap(
      sprintf("one_row_per '%s' for custom register '%s'", grain, id),
      "an existing schema grain (person / person_reference_date / event_from_person / expand_from_parent / household_year / time_to_event); do not invent a new grain"
    )
  }
  if (identical(grain, "time_to_event")) {
    first_bias <- first_or_null(sc$biases)
    bias_type <- if (!is.null(first_bias)) as.character(first_bias$type)[[1]] else ""
    if (!bias_type %in% c("immortal_time", "left_truncation")) {
      stop(
        "`one_row_per = \"time_to_event\"` needs `scenario = scenario_immortal_time(...)` ",
        "or `scenario_left_truncation(...)`; there is no independence version of this grain.",
        call. = FALSE
      )
    }
    # Fixed shape, always keyed on pnr -- no reason to support an
    # alternate join key for a grain whose columns are not user-described.
    # fidelity does not apply here: apply_fidelity()'s eligibility isn't
    # scoped to spec$columns, so with no columns declared it would treat
    # exit_time/exit_age/event/... as fair game for NA/outlier injection --
    # which would corrupt Surv() rather than rehearse anything meaningful.
    # There is no safe subset of these columns for cosmetic noise, so
    # fidelity is skipped entirely for this grain.
    spec <- list(id = id, one_row_per = grain, join_keys = "pnr", columns = list())
    tbl <- if (identical(bias_type, "immortal_time")) {
      generate_immortal_time_cohort(population, first_bias, from, to, seed)
    } else {
      generate_left_truncation_cohort(population, first_bias, seed)
    }
    tbl <- stamp_generation(tbl, schema = schema, seed = seed)
    return(attach_run_meta(tbl, scenario = sc))
  }
  join_keys <- resolve_custom_join_keys(grain, join_keys)
  col_df <- parse_custom_columns(columns)
  spec <- build_custom_spec(id, grain, join_keys, col_df)
  if (identical(grain, "expand_from_parent")) {
    if (is.null(parent)) {
      stop(
        "`parent` table is required for expand_from_parent customs; do not invent parents.",
        call. = FALSE
      )
    }
    if (!is.data.frame(parent)) {
      stop("`parent` must be a data frame / tibble.", call. = FALSE)
    }
  }
  cad <- cadence %||% "annual"
  if (!cad %in% c("annual", "quarterly")) {
    stop("`cadence` must be \"annual\" or \"quarterly\".", call. = FALSE)
  }
  tbl <- dispatch_custom_register(
    spec, population, schema, from, to, seed,
    parent = parent, cadence = cad
  )
  tbl <- with_rng_seed(seed, {
    tbl <- apply_scenario(tbl, sc, register_hint = id)
    apply_fidelity(tbl, spec, fidelity_info)
  })
  tbl <- stamp_generation(tbl, schema = schema, seed = seed)
  attach_run_meta(tbl, scenario = sc)
}
