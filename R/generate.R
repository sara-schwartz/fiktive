# Public generate_register() lives in generate-api.R (scenario + fidelity).

.KNOWN_GRAINS <- c(
  "person",
  "person_reference_date",
  "event_from_person",
  "expand_from_parent",
  "household_year",
  "time_to_event"
)

.IMPLEMENTED_SNAPSHOT <- c("bef", "udda", "akm")
.IMPLEMENTED_EVENTS <- c(
  "dod", "lmdb", "vnds", "cancer", "mfr", "lab_dm_forsker", "labka",
  "dodsaars", "dodsaasg", "dodsaarsager",
  "sysi", "sssy",
  "vnds_hist", "vnds_ind", "vnds_ud"
)
.IMPLEMENTED_PARENTS <- c("lpr_adm", "lpr_a_kontakt", "t_psyk_adm")
.IMPLEMENTED_EXPAND <- c(
  "lpr_diag", "lpr_sksopr", "lpr_sksube",
  "lpr_a_diagnose", "lpr_a_procregistrering",
  "t_psyk_diag"
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
  # Bundled KKH/KKHNG registers (all one_row_per: person) extend this
  # whitelist dynamically, read from the installed package -- see
  # kkh_register_ids() in R/schema.R. A DST register in the schema but not
  # in either list still correctly errors below, unchanged.
  implemented_snapshot <- c(.IMPLEMENTED_SNAPSHOT, kkh_register_ids())
  if (identical(grain, "person_reference_date") || identical(grain, "person") ||
      (!nzchar(grain) && register %in% implemented_snapshot)) {
    if (!register %in% implemented_snapshot) {
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
  if (identical(spec$one_row_per, "person")) {
    return(generate_person_snapshot(population, schema, spec, from, to, seed))
  }
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

# Schema-driven counterpart to generate_custom_person() (R/generate-custom.R)
# -- same fix, same reason: one_row_per = "person" is a baseline cohort
# table (one row per participant), not a repeated snapshot, so it must not
# go through the person x snapshot-date grid above. cadence is silently
# irrelevant here (unlike the custom-register path, generate_register()'s
# public API has no cadence= argument to conflict with in the first place --
# it's purely schema-derived via snapshot_cadence_for(), which the caller in
# dispatch_generate_register() still computes but this branch never uses).
generate_person_snapshot <- function(population, schema, spec, from, to, seed) {
  pop <- validate_population(population)
  from <- as_date1(from)
  to <- as_date1(to)
  if (is.na(from) || is.na(to) || to < from) {
    stop("`from` must be a Date on or before `to`.", call. = FALSE)
  }
  with_rng_seed(seed, {
    rows <- pop[pop$foed_dag <= to, , drop = FALSE]
    if (!nrow(rows)) {
      return(empty_from_spec(spec))
    }
    lo <- pmax(rows$foed_dag, from)
    span <- as.integer(to - lo)
    # One independent date per person within their own eligible window --
    # not a shared as-of date like person_reference_date's snapshot dates.
    # Faithful to staggered recruitment (e.g. KKH/KKHNG's baseline cohort
    # enrolled over several years): referencetid means "this person's own
    # date", a different meaning from the snapshot grain's.
    rows$referencetid <- lo + floor(stats::runif(nrow(rows)) * (span + 1L))
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
  # familie_id must come from the population -- generate_background_population()
  # provides it -- not be minted fresh here. Bef's snapshot generator picks
  # up the same population-level familie_id via derived_column() (map
  # carefully, exactly like pnr/koen/foed_dag); minting a second,
  # independent set of ids here would make bef and faik's familie_id
  # values disconnected, the actual reported bug.
  if (!"familie_id" %in% names(pop)) {
    stop(
      "`population` must have a `familie_id` column for a household-grain ",
      "register like '", spec$id %||% "this register", "' -- ",
      "generate_background_population() provides one; a hand-built ",
      "population needs to add one so it matches bef's.",
      call. = FALSE
    )
  }
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
    familie_ids <- unique(pop$familie_id)
    n_hh <- length(familie_ids)
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
  if (identical(register_id, "labka")) {
    # Regional lab register, same shape as lab_dm_forsker; empty tables remain valid.
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
    t_psyk_diag = "t_psyk_adm",
    NULL
  )
}
