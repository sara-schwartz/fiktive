# Column emit / code-system draw (loaded with generate.R).

emit_schema_table <- function(spec, rows, schema) {
  cols <- spec$columns %||% list()
  if (!length(cols)) {
    schema_gap(
      paste(spec$id %||% "register", "columns"),
      "a `columns` list on the register"
    )
  }
  register_id <- as.character(spec$id %||% spec$name %||% "")
  # kont_type's format (SKS admin code vs legacy pattype digit) depends on
  # lprindberetningssystem, which comes later in column order on
  # lpr_a_kontakt -- draw it first if the register has it, so kont_type and
  # the stored lprindberetningssystem column agree on the same row's value
  # instead of two independent, possibly-inconsistent draws.
  if (!("lprindberetningssystem" %in% names(rows)) && nrow(rows) > 0L) {
    lprib_col <- Find(
      function(c) identical(as.character(c$code_system %||% ""), "lprindberetningssystem"),
      cols
    )
    if (!is.null(lprib_col)) {
      rows$lprindberetningssystem <- fill_schema_column(
        lprib_col, rows, schema,
        register_id = register_id, spec = spec
      )
    }
  }
  used_sks <- FALSE
  used_atc <- FALSE
  used_icd_who <- FALSE
  used_labterm <- FALSE
  out <- list()
  for (col in cols) {
    name <- as.character(col$name %||% col$id)
    if (!nzchar(name)) {
      next
    }
    values <- fill_schema_column(col, rows, schema, register_id = register_id, spec = spec)
    if (!is.null(values)) {
      out[[name]] <- values
      rows[[name]] <- values
    }
    # A column can carry a clinical code_system id yet still be left NA for
    # this register (e.g. lpr_adm's icd10_sks field: only the diagnosis
    # child tables actually sample it, see draw_sks_dia_codes()). Stamping
    # catalogue/catalogue_version from the code_system id alone, regardless
    # of whether real values were drawn, produced a stamp that was both
    # wrong (claims a catalogue this register never touched) and
    # order-dependent (NA vs a real version depending on whether some other
    # register already lazy-loaded it earlier in the session).
    has_values <- !is.null(values) && nrow(rows) > 0L && any(!is.na(values))
    cs_id <- as.character(col$code_system %||% "")
    if (cs_id %in% c("sks", "kont_type", "icd10_sks") && has_values) {
      used_sks <- TRUE
    }
    if (identical(cs_id, "icd10") && has_values) {
      used_icd_who <- TRUE
    }
    if ((identical(cs_id, "atc") || identical(name, "atc")) && has_values) {
      used_atc <- TRUE
    }
    if ((identical(name, "analysiscode") ||
         identical(as.character(col$id %||% ""), "analysiscode")) && has_values) {
      used_labterm <- TRUE
    }
  }
  tbl <- tibble::as_tibble(out)
  if (used_sks) {
    meta <- sks_catalogue_stamp()
    attr(tbl, "catalogue") <- meta$catalogue
    attr(tbl, "catalogue_version") <- meta$version
  }
  if (used_icd_who && !used_sks) {
    tbl <- stamp_icd10_who_catalogue(tbl)
  }
  if (used_atc) {
    tbl <- stamp_atc_catalogue(tbl)
  }
  if (used_labterm && !used_sks && !used_atc && !used_icd_who) {
    tbl <- stamp_labterm_catalogue(tbl)
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

fill_schema_column <- function(col, rows, schema, register_id = NULL, spec = NULL) {
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
  when <- if ("event_date" %in% names(rows)) rows$event_date else rows$referencetid
  values <- derived_column(id, rows, schema = schema)
  if (is.null(values)) {
    # Sex/age diagnosis-chapter coherence is the "valid_diagnosis_sex_age"
    # constraint, not the uniform-noise default -- see with_constraints().
    # Skip the lookup/join work entirely when it's not requested.
    valid_sex_age <- has_constraint("valid_diagnosis_sex_age")
    koen <- if (valid_sex_age && "koen" %in% names(rows)) rows$koen else NULL
    age_years <- if (valid_sex_age && "foed_dag" %in% names(rows) && n > 0L) {
      as.numeric(difftime(when, rows$foed_dag, units = "days")) / 365.25
    } else {
      NULL
    }
    # kont_type's format must match its own row's lprindberetningssystem
    # regardless of which constraints are set -- a structural-consistency
    # fix (two columns on the same row agreeing), not something to opt into
    # separately, so always available
    # when the register has the column (see emit_schema_table's pre-pass).
    lprindberetningssystem <- if ("lprindberetningssystem" %in% names(rows)) {
      rows$lprindberetningssystem
    } else {
      NULL
    }
    values <- draw_independent_column(
      col, n, schema,
      register_id = register_id,
      when = when,
      koen = koen,
      age_years = age_years,
      lprindberetningssystem = lprindberetningssystem
    )
  }
  values <- coerce_schema_type(values, type)
  cov <- column_coverage_or_inherit(col, spec, schema)
  if (!is.null(cov) && n > 0L) {
    inside <- in_ym_coverage(when, cov)
    values[!inside] <- na_of_type(type, 1L)[[1]]
  }
  values
}

column_coverage_or_inherit <- function(col, spec, schema) {
  # Absent column coverage inherits register/family (tip deleted bad stamps).
  # Soften remaining single-year stamps that are narrower than register coverage.
  reg_cov <- if (!is.null(spec)) effective_coverage(spec, schema) else NULL
  if (is.null(col$coverage)) {
    return(NULL) # no per-column mask; register window already clipped upstream
  }
  if (is_suspicious_single_year_coverage(col$coverage, reg_cov)) {
    return(NULL)
  }
  col$coverage
}

is_suspicious_single_year_coverage <- function(col_cov, reg_cov) {
  if (is.null(col_cov) || is.null(col_cov$from) || is.null(col_cov$to)) {
    return(FALSE)
  }
  from_y <- lubridate::year(ym_start(col_cov$from))
  to_y <- lubridate::year(ym_end(col_cov$to))
  if (!identical(from_y, to_y)) {
    return(FALSE)
  }
  if (is.null(reg_cov) || is.null(reg_cov$from) || is.null(reg_cov$to)) {
    return(FALSE)
  }
  reg_from_y <- lubridate::year(ym_start(reg_cov$from))
  reg_to_y <- lubridate::year(ym_end(reg_cov$to))
  # Single calendar year while register spans multiple years → ignore stamp.
  (reg_to_y - reg_from_y) >= 2L
}

derived_column <- function(id, rows, schema = NULL) {
  when <- if ("event_date" %in% names(rows)) rows$event_date else rows$referencetid
  atc <- if ("atc" %in% names(rows)) as.character(rows$atc) else NULL
  event_dt <- if ("event_datetime" %in% names(rows)) rows$event_datetime else NULL
  discharge <- if ("discharge_date" %in% names(rows)) rows$discharge_date else NULL
  discharge_dt <- if ("discharge_datetime" %in% names(rows)) rows$discharge_datetime else NULL
  # borger_koen: tip is character with no code_system — do NOT map from pop koen.
  switch(
    id,
    pnr = rows$pnr,
    # Cancerregisteret person key (rename before joining DST pnr).
    k_cprnr = rows$pnr,
    # MFR Levendefoedte: join_keys is cpr_barn; schema relationship names BEF
    # column `pnr` — map carefully, do not invent an mfr `pnr` column.
    cpr_barn = rows$pnr,
    # Lab_dm_forsker: join_keys patient_cpr ← pop pnr (map carefully).
    patient_cpr = rows$pnr,
    samplingdate = when,
    foedselsdato = when,
    foedselsaar = as.character(lubridate::year(when)),
    familie_id = if ("familie_id" %in% names(rows)) rows$familie_id else NULL,
    # Pre-drawn in emit_schema_table()'s pre-pass (see there) so kont_type,
    # which sits earlier in column order on lpr_a_kontakt, can read the same
    # row's value instead of triggering a second, inconsistent draw.
    lprindberetningssystem = if ("lprindberetningssystem" %in% names(rows)) rows$lprindberetningssystem else NULL,
    koen = rows$koen,
    foed_dag = rows$foed_dag,
    referencetid = rows$referencetid,
    year = as.integer(lubridate::year(when)),
    alder = age_years(rows$foed_dag, rows$referencetid),
    alder_ult_ink = age_years(rows$foed_dag, rows$referencetid),
    alder_haend = age_years(rows$foed_dag, when),
    aldr = age_years(rows$foed_dag, when),
    v_alder = age_years(rows$foed_dag, when),
    v_diagnosealder = age_years(rows$foed_dag, when),
    v_diagaar = as.numeric(lubridate::year(when)),
    v_diagmd = as.numeric(lubridate::month(when)),
    fdato = rows$foed_dag,
    d_fdsdato = rows$foed_dag,
    d_diagnosedato = when,
    d_statdato = when,
    doddato = when,
    eksd = when,
    haend_dato = when,
    d_inddto = when,
    d_uddto = if (is.null(discharge)) NULL else pmax(as.Date(discharge), as.Date(when)),
    recnum = if ("recnum" %in% names(rows)) rows$recnum else rows$contact_id,
    dw_ek_kontakt = if ("dw_ek_kontakt" %in% names(rows)) rows$dw_ek_kontakt else rows$contact_id,
    kont_starttidspunkt = event_dt,
    kont_sluttidspunkt = if (is.null(discharge_dt)) event_dt else pmax(discharge_dt, event_dt),
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
