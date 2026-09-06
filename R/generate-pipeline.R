# Parent contact + expand-from-parent pipelines (loaded with generate.R).

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
