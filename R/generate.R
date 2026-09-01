#' Generate a fictitious register table
#'
#' `scenario = NULL` is independence: structurally valid noise that joins.
#' Snapshot grains: `bef` (quarterly), `udda` and `akm` (annual).
#' Event-from-person: `dod`, `lmdb`, `vnds` (empty tables are valid).
#' Never mix `vnds` with `vnds_hist` / `vnds_ind` / `vnds_ud`.
#' Other schema registers error as not implemented; unknown ids are a SCHEMA GAP.
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
#'   for `register`. Zero rows is a valid event table.
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

emit_schema_table <- function(spec, rows, schema) {
  cols <- spec$columns %||% list()
  if (!length(cols)) {
    schema_gap(
      paste(spec$id %||% "register", "columns"),
      "a `columns` list on the register"
    )
  }
  out <- list()
  for (col in cols) {
    name <- as.character(col$name %||% col$id)
    if (!nzchar(name)) {
      next
    }
    values <- fill_schema_column(col, rows, schema)
    if (!is.null(values)) {
      out[[name]] <- values
      rows[[name]] <- values
    }
  }
  tibble::as_tibble(out)
}
