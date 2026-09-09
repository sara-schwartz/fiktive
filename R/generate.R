#' Generate a fictitious register table
#'
#' `scenario = NULL` is independence: structurally valid noise that joins.
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
#' @param scenario Must be `NULL` (independence).
#'
#' @return A tibble whose columns are a subset of the schema column names
#'   for `register`. Zero rows is a valid event or child table.
#' @export
generate_register <- function(register, population, schema, from, to,
                              seed = NULL, scenario = NULL) {
  if (!is.null(scenario)) {
    stop("Only scenario = NULL (independence) is supported.", call. = FALSE)
  }
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  register <- tolower(as.character(register)[[1]])
  spec <- schema$registers[[register]]
  if (is.null(spec)) {
    schema_gap(
      sprintf("register id '%s' is not in the schema.", register),
      "a register id that exists in registers/*.yaml"
    )
  }
  dispatch_generate_register(register, spec, population, schema, from, to, seed)
}

.KNOWN_GRAINS <- c(
  "person",
  "person_reference_date",
  "event_from_person",
  "expand_from_parent",
  "household_year"
)

.IMPLEMENTED_SNAPSHOT <- c("bef", "udda", "akm")
.IMPLEMENTED_EVENTS <- c("dod", "lmdb", "vnds", "cancer", "mfr", "lab_dm_forsker")
.IMPLEMENTED_PARENTS <- c("lpr_adm", "lpr_a_kontakt")
.IMPLEMENTED_EXPAND <- c(
  "lpr_diag", "lpr_sksopr", "lpr_sksube",
  "lpr_a_diagnose", "lpr_a_procregistrering"
)

dispatch_generate_register <- function(register, spec, population, schema, from, to, seed) {
  grain <- as.character(spec$one_row_per %||% "")
  if (nzchar(grain) && !grain %in% .KNOWN_GRAINS) {
    schema_gap(
      sprintf("one_row_per '%s' for register '%s'", grain, register),
      "a documented ALLOWED_GRAIN (person / person_reference_date / event_from_person / expand_from_parent / household_year / unknown)"
    )
  }
  if (identical(grain, "unknown")) {
    schema_gap(
      sprintf("one_row_per 'unknown' for register '%s'", register),
      "a concrete grain in the schema before generation"
    )
  }
  if (identical(grain, "household_year")) {
    return(generate_household_year(population, schema, spec, from, to, seed))
  }

  # Prefer one_row_per when present; else fall back to register-id lists (thin fixtures).
  if (identical(grain, "person_reference_date") || identical(grain, "person") ||
      (!nzchar(grain) && register %in% .IMPLEMENTED_SNAPSHOT)) {
    if (!register %in% .IMPLEMENTED_SNAPSHOT) {
      stop(
        sprintf("Register '%s' is in the schema but is not implemented yet.", register),
        call. = FALSE
      )
    }
    cadence <- snapshot_cadence_for(register, spec)
    return(generate_snapshot(population, schema, spec, from, to, seed, cadence = cadence))
  }

  if (identical(grain, "expand_from_parent") ||
      (!nzchar(grain) && register %in% .IMPLEMENTED_EXPAND)) {
    if (!register %in% .IMPLEMENTED_EXPAND) {
      stop(
        sprintf("Register '%s' is in the schema but is not implemented yet.", register),
        call. = FALSE
      )
    }
    return(generate_expand_from_parent(population, schema, spec, from, to, seed))
  }

  if (identical(grain, "event_from_person") ||
      (!nzchar(grain) && register %in% c(.IMPLEMENTED_EVENTS, .IMPLEMENTED_PARENTS))) {
    if (register %in% .IMPLEMENTED_PARENTS) {
      return(generate_parent_contacts(population, schema, spec, from, to, seed))
    }
    if (register %in% .IMPLEMENTED_EVENTS) {
      return(generate_events(population, schema, spec, from, to, seed))
    }
    stop(
      sprintf("Register '%s' is in the schema but is not implemented yet.", register),
      call. = FALSE
    )
  }

  stop(
    sprintf("Register '%s' is in the schema but is not implemented yet.", register),
    call. = FALSE
  )
}

snapshot_cadence_for <- function(register, spec) {
  if (identical(register, "bef")) {
    return("quarterly")
  }
  cad <- as.character(spec$update_cadence %||% "")
  if (identical(cad, "quarterly")) {
    return("quarterly")
  }
  "annual"
}

generate_snapshot <- function(population, schema, spec, from, to, seed, cadence) {
  pop <- validate_population(population)
  from <- as_date1(from)
  to <- as_date1(to)
  if (is.na(from) || is.na(to) || to < from) {
    stop("`from` must be a Date on or before `to`.", call. = FALSE)
  }
  dates <- snapshot_dates(from, to, spec$coverage, cadence)
  with_rng_seed(seed, {
    if (!length(dates) || !nrow(pop)) {
      return(empty_from_spec(spec))
    }
    grid <- tibble::tibble(
      pnr = rep(pop$pnr, each = length(dates)),
      referencetid = rep(dates, times = nrow(pop))
    )
    rows <- dplyr::left_join(grid, pop, by = "pnr")
    rows <- rows[rows$referencetid >= rows$foed_dag, , drop = FALSE]
    emit_schema_table(spec, rows, schema)
  })
}

generate_events <- function(population, schema, spec, from, to, seed) {
  pop <- validate_population(population)
  from <- as_date1(from)
  to <- as_date1(to)
  if (is.na(from) || is.na(to) || to < from) {
    stop("`from` must be a Date on or before `to`.", call. = FALSE)
  }
  if (!is.null(spec$coverage)) {
    if (!is.null(spec$coverage$from)) {
      from <- max(from, ym_start(spec$coverage$from))
    }
    if (!is.null(spec$coverage$to)) {
      to <- min(to, ym_end(spec$coverage$to))
    }
  }
  with_rng_seed(seed, {
    if (!nrow(pop) || to < from) {
      return(empty_from_spec(spec))
    }
    n_people <- nrow(pop)
    n_ev <- event_counts(spec$id, n_people)
    lo <- pmax(pop$foed_dag, from)
    hi <- rep(to, n_people)
    pieces <- vector("list", n_people)
    for (i in seq_len(n_people)) {
      k <- n_ev[[i]]
      if (k < 1L || lo[[i]] > hi[[i]]) {
        next
      }
      span <- as.integer(hi[[i]] - lo[[i]])
      event_date <- lo[[i]] + sample.int(span + 1L, k, replace = TRUE) - 1L
      pieces[[i]] <- tibble::tibble(
        pnr = pop$pnr[[i]],
        foed_dag = pop$foed_dag[[i]],
        koen = pop$koen[[i]],
        event_date = as.Date(event_date)
      )
    }
    rows <- dplyr::bind_rows(pieces)
    if (!nrow(rows)) {
      return(empty_from_spec(spec))
    }
    rows$referencetid <- rows$event_date
    emit_schema_table(spec, rows, schema)
  })
}

generate_household_year <- function(population, schema, spec, from, to, seed) {
  # Household × year on familie_id (not person-level). Structural noise only;
  # no family-graph truth. pnr is not a FAIK key — blank/NA when present.
  pop <- validate_population(population)
  from <- as_date1(from)
  to <- as_date1(to)
  if (is.na(from) || is.na(to) || to < from) {
    stop("`from` must be a Date on or before `to`.", call. = FALSE)
  }
  win <- clip_requested_window(from, to, effective_coverage(spec, schema))
  from <- win$from
  to <- win$to
  with_rng_seed(seed, {
    if (!nrow(pop) || to < from) {
      return(empty_from_spec(spec))
    }
    y0 <- lubridate::year(from)
    y1 <- lubridate::year(to)
    years <- seq.int(y0, y1)
    dates <- as.Date(sprintf("%d-12-31", years))
    dates <- dates[dates >= from & dates <= to]
    if (!length(dates)) {
      return(empty_from_spec(spec))
    }
    n_hh <- nrow(pop)
    # Undocumented familie_id format — structural join_key noise (H#######).
    familie_ids <- sprintf("H%07d", sample.int(10000000L, n_hh, replace = FALSE) - 1L)
    n_y <- length(dates)
    rows <- tibble::tibble(
      familie_id = rep(familie_ids, each = n_y),
      referencetid = rep(dates, times = n_hh),
      # Not a real FAIK key (often empty in deliveries); do not invent person grain.
      pnr = rep(NA_character_, n_hh * n_y)
    )
    emit_schema_table(spec, rows, schema)
  })
}

event_counts <- function(register_id, n) {
  if (identical(register_id, "dod")) {
    return(stats::rbinom(n, 1L, 0.3))
  }
  if (identical(register_id, "lmdb")) {
    return(stats::rpois(n, 1.5))
  }
  if (identical(register_id, "cancer")) {
    # Tumours per person (incident cancers); empty tables remain valid.
    return(stats::rpois(n, 0.5))
  }
  if (identical(register_id, "mfr")) {
    # Live births (Levendefoedte) per person; empty tables remain valid.
    return(stats::rpois(n, 0.4))
  }
  if (identical(register_id, "lab_dm_forsker")) {
    # Lab results per person; empty tables remain valid.
    return(stats::rpois(n, 2.0))
  }
  stats::rpois(n, 0.4)
}

effective_coverage <- function(spec, schema) {
  if (!is.null(spec$coverage)) {
    return(spec$coverage)
  }
  fam_id <- spec$family
  if (!is.null(fam_id) && !is.null(schema$families)) {
    fam <- schema$families[[as.character(fam_id)]]
    if (!is.null(fam) && !is.null(fam$coverage)) {
      return(fam$coverage)
    }
  }
  NULL
}

spec_has_col <- function(spec, id) {
  cols <- spec$columns %||% list()
  any(vapply(cols, function(col) {
    identical(as.character(col$id %||% col$name), id)
  }, logical(1)))
}

clip_requested_window <- function(from, to, coverage) {
  if (!is.null(coverage)) {
    if (!is.null(coverage$from)) {
      from <- max(from, ym_start(coverage$from))
    }
    if (!is.null(coverage$to)) {
      to <- min(to, ym_end(coverage$to))
    }
  }
  list(from = from, to = to)
}

lpr_parent_id <- function(register_id) {
  switch(
    register_id,
    lpr_diag = "lpr_adm",
    lpr_sksopr = "lpr_adm",
    lpr_sksube = "lpr_adm",
    lpr_a_diagnose = "lpr_a_kontakt",
    lpr_a_procregistrering = "lpr_a_kontakt",
    NULL
  )
}
