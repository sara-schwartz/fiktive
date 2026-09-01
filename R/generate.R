#' Generate a fictitious register table
#'
#' `scenario = NULL` is independence: structurally valid noise that joins.
#' Snapshot grains: `bef` (quarterly), `udda` and `akm` (annual).
#' Event-from-person: `dod`, `lmdb`, `vnds` (empty tables are valid).
#' Expand-from-parent: LPR2 (`lpr_adm` then `lpr_diag` / `lpr_sksopr` /
#' `lpr_sksube`) and LPR3 (`lpr_a_kontakt` then `lpr_a_diagnose` /
#' `lpr_a_procregistrering`). Diagnoses/procedures are generated off the
#' **same** contact table that was written. LPR procedure codes sample
#' `sksr::SKS_labels` at runtime (surgical `lpr_sksopr` uses Prefix `opr` /
#' K-codes). ICD-10 diagnosis columns SCHEMA GAP until a published ICD-10
#' catalogue is chosen (not SKS, not ATC, not decoder). Psych LPR
#' (`t_psyk_*`) is not this step. Never mix `vnds` with `vnds_hist` /
#' `vnds_ind` / `vnds_ud`. Other schema registers error as not implemented;
#' unknown ids are a SCHEMA GAP.
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
  if (identical(register, "bef")) {
    return(generate_snapshot(population, schema, spec, from, to, seed, cadence = "quarterly"))
  }
  if (register %in% c("udda", "akm")) {
    return(generate_snapshot(population, schema, spec, from, to, seed, cadence = "annual"))
  }
  if (register %in% c("dod", "lmdb", "vnds")) {
    return(generate_events(population, schema, spec, from, to, seed))
  }
  if (register %in% c("lpr_adm", "lpr_a_kontakt")) {
    return(generate_parent_contacts(population, schema, spec, from, to, seed))
  }
  if (register %in% c("lpr_diag", "lpr_sksopr", "lpr_sksube",
                      "lpr_a_diagnose", "lpr_a_procregistrering")) {
    return(generate_expand_from_parent(population, schema, spec, from, to, seed))
  }
  stop(
    sprintf(
      "Register '%s' is in the schema but is not implemented yet.",
      register
    ),
    call. = FALSE
  )
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

event_counts <- function(register_id, n) {
  if (identical(register_id, "dod")) {
    return(stats::rbinom(n, 1L, 0.3))
  }
  if (identical(register_id, "lmdb")) {
    return(stats::rpois(n, 1.5))
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

generate_parent_contacts <- function(population, schema, spec, from, to, seed) {
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
    n_people <- nrow(pop)
    n_ev <- stats::rpois(n_people, 1.2)
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
    n <- nrow(rows)
    rows$contact_id <- sprintf("C%010d", seq_len(n))
    rows$recnum <- rows$contact_id
    rows$dw_ek_kontakt <- rows$contact_id
    stay <- sample.int(15L, n, replace = TRUE) - 1L
    rows$discharge_date <- rows$event_date + stay
    rows$referencetid <- rows$event_date
    if (spec_has_col(spec, "kont_starttidspunkt")) {
      tod <- sample.int(24L * 3600L, n, replace = TRUE) - 1L
      start0 <- as.POSIXct(
        paste(format(rows$event_date, "%Y-%m-%d"), "00:00:00"),
        tz = "UTC"
      )
      rows$event_datetime <- start0 + tod
      rows$discharge_datetime <- rows$event_datetime + stay * 86400
    }
    emit_schema_table(spec, rows, schema)
  })
}

generate_expand_from_parent <- function(population, schema, spec, from, to, seed) {
  parent_id <- lpr_parent_id(spec$id %||% spec$name)
  if (is.null(parent_id)) {
    schema_gap(
      sprintf("expand-from-parent mapping for '%s'", spec$id %||% "register"),
      "a documented parent contact register"
    )
  }
  parent_spec <- schema$registers[[parent_id]]
  if (is.null(parent_spec)) {
    schema_gap(
      sprintf("parent register '%s' for '%s'", parent_id, spec$id %||% "child"),
      "the parent register YAML in registers/"
    )
  }
  with_rng_seed(seed, {
    parent_tbl <- generate_parent_contacts(
      population, schema, parent_spec, from, to, seed = NULL
    )
    expand_child_rows(parent_tbl, spec, schema)
  })
}

parent_event_when <- function(parent_tbl) {
  if ("d_inddto" %in% names(parent_tbl)) {
    return(parent_tbl$d_inddto)
  }
  if ("kont_starttidspunkt" %in% names(parent_tbl)) {
    return(parent_tbl$kont_starttidspunkt)
  }
  schema_gap(
    "parent event/contact date",
    "d_inddto or kont_starttidspunkt on the parent table"
  )
}

child_join_key <- function(parent_tbl, spec) {
  keys <- spec$join_keys
  if (!is.null(keys) && length(keys)) {
    k <- as.character(keys[[1]])
    if (k %in% names(parent_tbl)) {
      return(k)
    }
  }
  if ("dw_ek_kontakt" %in% names(parent_tbl)) {
    return("dw_ek_kontakt")
  }
  if ("recnum" %in% names(parent_tbl)) {
    return("recnum")
  }
  schema_gap(
    sprintf("join key for '%s'", spec$id %||% "child"),
    "join_keys pointing at a parent contact id"
  )
}

child_event_counts <- function(register_id, n) {
  if (register_id %in% c("lpr_diag", "lpr_a_diagnose")) {
    return(stats::rpois(n, 1.5))
  }
  stats::rpois(n, 0.6)
}

expand_child_rows <- function(parent_tbl, spec, schema) {
  if (!nrow(parent_tbl)) {
    return(empty_from_spec(spec))
  }
  key <- child_join_key(parent_tbl, spec)
  when <- parent_event_when(parent_tbl)
  keep <- in_ym_coverage(when, effective_coverage(spec, schema))
  parent_tbl <- parent_tbl[keep, , drop = FALSE]
  when <- when[keep]
  if (!nrow(parent_tbl)) {
    return(empty_from_spec(spec))
  }
  n_parent <- nrow(parent_tbl)
  n_ch <- child_event_counts(spec$id, n_parent)
  idx <- rep(seq_len(n_parent), times = n_ch)
  if (!length(idx)) {
    return(empty_from_spec(spec))
  }
  event_date <- as.Date(when[idx])
  key_vals <- as.character(parent_tbl[[key]][idx])
  rows <- tibble::tibble(
    contact_id = key_vals,
    recnum = key_vals,
    dw_ek_kontakt = key_vals,
    event_date = event_date,
    referencetid = event_date
  )
  if ("kont_starttidspunkt" %in% names(parent_tbl)) {
    rows$event_datetime <- as.POSIXct(parent_tbl$kont_starttidspunkt[idx], tz = "UTC")
  }
  if ("kont_sluttidspunkt" %in% names(parent_tbl)) {
    rows$discharge_datetime <- as.POSIXct(parent_tbl$kont_sluttidspunkt[idx], tz = "UTC")
  }
  if ("d_uddto" %in% names(parent_tbl)) {
    rows$discharge_date <- as.Date(parent_tbl$d_uddto[idx])
  }
  emit_schema_table(spec, rows, schema)
}

emit_schema_table <- function(spec, rows, schema) {
  cols <- spec$columns %||% list()
  if (!length(cols)) {
    schema_gap(
      paste(spec$id %||% "register", "columns"),
      "a `columns` list on the register"
    )
  }
  register_id <- as.character(spec$id %||% spec$name %||% "")
  used_sks <- FALSE
  out <- list()
  for (col in cols) {
    name <- as.character(col$name %||% col$id)
    if (!nzchar(name)) {
      next
    }
    values <- fill_schema_column(col, rows, schema, register_id = register_id)
    if (!is.null(values)) {
      out[[name]] <- values
      rows[[name]] <- values
    }
    cs_id <- as.character(col$code_system %||% "")
    if (cs_id %in% c("sks", "kont_type") && nrow(rows) > 0L) {
      used_sks <- TRUE
    }
  }
  tbl <- tibble::as_tibble(out)
  if (used_sks) {
    meta <- sks_catalogue_stamp()
    attr(tbl, "catalogue") <- meta$catalogue
    attr(tbl, "catalogue_version") <- meta$version
  }
  tbl
}

validate_population <- function(population) {
  pop <- tibble::as_tibble(population)
  needed <- c("pnr", "foed_dag", "koen")
  missing <- setdiff(needed, names(pop))
  if (length(missing)) {
    stop(
      "population must have columns: ",
      paste(needed, collapse = ", "),
      call. = FALSE
    )
  }
  pop$pnr <- as.character(pop$pnr)
  pop$foed_dag <- as_date1(pop$foed_dag)
  pop$koen <- as.integer(pop$koen)
  pop
}

empty_from_spec <- function(spec) {
  cols <- spec$columns %||% list()
  out <- list()
  for (col in cols) {
    name <- as.character(col$name %||% col$id)
    type <- col$type
    if (is.null(type) && is.null(col$code_system)) {
      schema_gap(
        sprintf("column '%s' has neither type nor code_system", name),
        "a `type` and/or `code_system` on the column"
      )
    }
    type <- type %||% "character"
    out[[name]] <- na_of_type(type, 0L)
  }
  tibble::as_tibble(out)
}

snapshot_dates <- function(from, to, coverage = NULL, cadence = "quarterly") {
  if (!is.null(coverage)) {
    if (!is.null(coverage$from)) {
      from <- max(from, ym_start(coverage$from))
    }
    if (!is.null(coverage$to)) {
      to <- min(to, ym_end(coverage$to))
    }
  }
  if (to < from) {
    return(as.Date(character()))
  }
  years <- seq.int(lubridate::year(from), lubridate::year(to))
  dates <- do.call(c, lapply(years, function(y) {
    if (identical(cadence, "annual")) {
      as.Date(sprintf("%d-12-31", y))
    } else if (y < 2008L) {
      as.Date(sprintf("%d-12-31", y))
    } else {
      as.Date(c(
        sprintf("%d-03-31", y),
        sprintf("%d-06-30", y),
        sprintf("%d-09-30", y),
        sprintf("%d-12-31", y)
      ))
    }
  }))
  sort(unique(dates[dates >= from & dates <= to]))
}

fill_schema_column <- function(col, rows, schema, register_id = NULL) {
  n <- nrow(rows)
  id <- as.character(col$id %||% col$name)
  type <- col$type
  cs <- col$code_system
  if (is.null(type) && is.null(cs)) {
    schema_gap(
      sprintf("column '%s' has neither type nor code_system", id),
      "a `type` and/or `code_system` on the column"
    )
  }
  type <- type %||% "character"
  values <- derived_column(id, rows)
  if (is.null(values)) {
    values <- draw_independent_column(col, n, schema, register_id = register_id)
  }
  values <- coerce_schema_type(values, type)
  if (!is.null(col$coverage) && n > 0L) {
    when <- if ("event_date" %in% names(rows)) rows$event_date else rows$referencetid
    inside <- in_ym_coverage(when, col$coverage)
    values[!inside] <- na_of_type(type, 1L)[[1]]
  }
  values
}

derived_column <- function(id, rows) {
  when <- if ("event_date" %in% names(rows)) rows$event_date else rows$referencetid
  atc <- if ("atc" %in% names(rows)) as.character(rows$atc) else NULL
  event_dt <- if ("event_datetime" %in% names(rows)) rows$event_datetime else NULL
  discharge <- if ("discharge_date" %in% names(rows)) rows$discharge_date else NULL
  discharge_dt <- if ("discharge_datetime" %in% names(rows)) rows$discharge_datetime else NULL
  switch(
    id,
    pnr = rows$pnr,
    koen = rows$koen,
    foed_dag = rows$foed_dag,
    referencetid = rows$referencetid,
    year = as.integer(lubridate::year(when)),
    alder = age_years(rows$foed_dag, rows$referencetid),
    alder_ult_ink = age_years(rows$foed_dag, rows$referencetid),
    alder_haend = age_years(rows$foed_dag, when),
    aldr = age_years(rows$foed_dag, when),
    v_alder = age_years(rows$foed_dag, when),
    fdato = rows$foed_dag,
    doddato = when,
    eksd = when,
    haend_dato = when,
    d_inddto = when,
    d_uddto = if (is.null(discharge)) NULL else pmax(as.Date(discharge), as.Date(when)),
    recnum = if ("recnum" %in% names(rows)) rows$recnum else rows$contact_id,
    dw_ek_kontakt = if ("dw_ek_kontakt" %in% names(rows)) rows$dw_ek_kontakt else rows$contact_id,
    kont_starttidspunkt = event_dt,
    kont_sluttidspunkt = if (is.null(discharge_dt)) event_dt else pmax(discharge_dt, event_dt),
    borger_koen = rows$koen,
    borger_foedselsdato = rows$foed_dag,
    borger_alder_aar_ind = age_years(rows$foed_dag, when),
    borger_alder_aar_ud = age_years(rows$foed_dag, if (is.null(discharge)) when else discharge),
    d_odto = when,
    proc_starttidspunkt = event_dt,
    proc_sluttidspunkt = if (is.null(discharge_dt)) event_dt else pmax(discharge_dt, event_dt),
    proc_indb_tidspunkt = event_dt,
    atc1 = if (is.null(atc)) NULL else substr(atc, 1L, 1L),
    atc2 = if (is.null(atc)) NULL else substr(atc, 1L, 3L),
    atc3 = if (is.null(atc)) NULL else substr(atc, 1L, 4L),
    atc4 = if (is.null(atc)) NULL else substr(atc, 1L, 5L),
    NULL
  )
}

draw_independent_column <- function(col, n, schema, register_id = NULL) {
  type <- col$type %||% "character"
  role <- col$role
  cs_id <- col$code_system
  name <- as.character(col$name %||% col$id)
  if (n == 0L) {
    return(na_of_type(type, 0L))
  }
  if (!is.null(cs_id)) {
    cs <- schema$code_systems[[as.character(cs_id)]]
    if (is.null(cs)) {
      schema_gap(
        sprintf("code system '%s' for column '%s'", cs_id, name),
        "a matching file in code-systems/"
      )
    }
    keys <- lookup_keys(cs)
    if (!is.null(keys) && length(keys)) {
      if (identical(as.character(cs_id), "civst")) {
        keys <- setdiff(keys, "D")
      }
      drawn <- sample(keys, n, replace = TRUE)
      return(coerce_schema_type(drawn, type))
    }
    cs_id_chr <- as.character(cs_id)
    if (identical(cs_id_chr, "icd10")) {
      return(draw_icd10_pending(name, n, type, register_id))
    }
    if (cs_id_chr %in% c("sks", "kont_type")) {
      kind <- sks_kind_for(cs_id_chr, register_id, name)
      drawn <- sample_sks_codes(n, kind, cs)
      return(coerce_schema_type(drawn, type))
    }
    return(typed_noise(type, n, role = role, name = name, code_system = cs_id, cs = cs))
  }
  typed_noise(type, n, role = role, name = name)
}


.sks_state <- new.env(parent = emptyenv())

sksr_is_installed <- function() {
  requireNamespace("sksr", quietly = TRUE)
}

sks_catalogue_stamp <- function() {
  list(
    catalogue = .sks_state$catalogue %||% "sksr::SKS_labels",
    version = .sks_state$version %||% NA_character_
  )
}

load_sks_labels <- function() {
  if (!sksr_is_installed()) {
    stop(
      "Package 'sksr' is required to sample published SKS codes. ",
      "Install it with install.packages(\"sksr\").",
      call. = FALSE
    )
  }
  if (!is.null(.sks_state$labels)) {
    return(.sks_state$labels)
  }
  labels <- sksr::SKS_labels
  if (is.null(labels) || !nrow(labels) || !("Kode" %in% names(labels))) {
    schema_gap(
      "sksr::SKS_labels",
      "a SKS_labels table with a Kode column"
    )
  }
  labels$Kode <- as.character(labels$Kode)
  if ("Prefix" %in% names(labels)) {
    labels$Prefix <- as.character(labels$Prefix)
  }
  keep <- !is.na(labels$Kode) & nzchar(labels$Kode)
  .sks_state$labels <- labels[keep, , drop = FALSE]
  .sks_state$catalogue <- "sksr::SKS_labels"
  .sks_state$version <- as.character(utils::packageVersion("sksr"))
  .sks_state$labels
}

draw_icd10_pending <- function(name, n, type, register_id) {
  if (as.character(register_id %||% "") %in% c("lpr_diag", "lpr_a_diagnose")) {
    schema_gap(
      sprintf(
        "ICD-10 catalogue for column '%s' (published source not selected)",
        name
      ),
      "a published ICD-10 source once the catalogue is chosen"
    )
  }
  na_of_type(type %||% "character", n)
}

sks_kind_for <- function(cs_id, register_id, name) {
  if (identical(as.character(cs_id), "kont_type")) {
    return("adm")
  }
  register_id <- as.character(register_id %||% "")
  if (identical(register_id, "lpr_sksopr")) {
    return("opr")
  }
  if (identical(register_id, "lpr_sksube")) {
    return("pro_und")
  }
  if (identical(register_id, "lpr_a_procregistrering")) {
    return("proc")
  }
  schema_gap(
    sprintf("SKS kind for column '%s' on '%s'", name, register_id %||% "register"),
    "a documented procedure grain (lpr_sksopr / lpr_sksube / lpr_a_procregistrering)"
  )
}

filter_published_sks <- function(labels, kind, cs) {
  kode <- as.character(labels$Kode)
  if ("Prefix" %in% names(labels)) {
    pref <- as.character(labels$Prefix)
    pick <- switch(
      kind,
      opr = pref == "opr",
      pro_und = pref %in% c("pro", "und"),
      proc = pref %in% c("opr", "pro", "und"),
      adm = pref == "adm",
      rep(TRUE, length(kode))
    )
    kode <- kode[pick]
  } else {
    if (identical(kind, "opr")) {
      kode <- kode[startsWith(kode, "K")]
    } else if (identical(kind, "adm")) {
      kode <- kode[nchar(kode) == 6L]
    }
  }
  kode <- kode[grepl("^[A-Za-z][A-Za-z0-9]{3,}$", kode)]
  if (identical(kind, "adm")) {
    kode <- kode[nchar(kode) == 6L]
  }
  if (identical(kind, "opr")) {
    kode <- kode[startsWith(kode, "K") | startsWith(kode, "k")]
  }
  unique(kode)
}

sample_sks_codes <- function(n, kind, cs) {
  labels <- load_sks_labels()
  codes <- filter_published_sks(labels, kind, cs)
  if (!length(codes)) {
    schema_gap(
      sprintf("published SKS codes in sksr::SKS_labels for kind '%s'", kind),
      "SKS_labels rows already classified for this grain"
    )
  }
  sample(codes, n, replace = TRUE)
}

typed_noise <- function(type, n, role = NULL, name = NULL, code_system = NULL, cs = NULL) {
  if (identical(type, "integer")) {
    return(sample.int(11L, n, replace = TRUE) - 1L)
  }
  if (identical(type, "numeric")) {
    return(stats::runif(n, 0.5, 20))
  }
  if (identical(type, "date")) {
    return(as.Date("1990-01-01") + sample.int(10000L, n, replace = TRUE) - 1L)
  }
  if (identical(type, "datetime")) {
    return(
      as.POSIXct("1990-01-01", tz = "UTC") +
        (sample.int(10000L, n, replace = TRUE) - 1L) * 86400
    )
  }
  if (identical(as.character(code_system), "atc") || identical(name, "atc")) {
    # Pattern from code-systems/atc.yaml structure, not a WHO/DST list.
    # ATC catalogues belong in the LMDB step, not LPR.
    return(sprintf(
      "%s%02d%s%s%02d",
      sample(LETTERS, n, replace = TRUE),
      sample.int(100L, n, replace = TRUE) - 1L,
      sample(LETTERS, n, replace = TRUE),
      sample(LETTERS, n, replace = TRUE),
      sample.int(100L, n, replace = TRUE) - 1L
    ))
  }
  if (as.character(code_system %||% "") %in% c("icd10", "sks", "kont_type")) {
    stop(
      "Internal error: clinical nomenclature must not fall through to typed noise.",
      call. = FALSE
    )
  }
  if (identical(role, "identifier") || (identical(role, "join_key") && !identical(name, "pnr"))) {
    prefix <- if (identical(role, "join_key")) "H" else "I"
    return(sprintf("%s%07d", prefix, sample.int(10000000L, n, replace = TRUE) - 1L))
  }
  sprintf("%03d", sample.int(1000L, n, replace = TRUE) - 1L)
}
