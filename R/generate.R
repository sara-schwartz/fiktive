#' Generate a fictitious register table
#'
#' `scenario = NULL` is independence: structurally valid noise that joins.
#' Snapshot grains implemented: `bef` (quarterly person x referencetid),
#' `udda` and `akm` (annual person x year). Other schema registers error as
#' not implemented; unknown ids are a SCHEMA GAP.
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
#'   for `register`.
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
      }
    }
    tibble::as_tibble(out)
  })
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

fill_schema_column <- function(col, rows, schema) {
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
  values <- derived_snapshot_column(id, rows)
  if (is.null(values)) {
    values <- draw_independent_column(col, n, schema)
  }
  values <- coerce_schema_type(values, type)
  if (!is.null(col$coverage) && n > 0L) {
    inside <- in_ym_coverage(rows$referencetid, col$coverage)
    values[!inside] <- na_of_type(type, 1L)[[1]]
  }
  values
}

derived_snapshot_column <- function(id, rows) {
  switch(
    id,
    pnr = rows$pnr,
    koen = rows$koen,
    foed_dag = rows$foed_dag,
    referencetid = rows$referencetid,
    year = as.integer(lubridate::year(rows$referencetid)),
    alder = age_years(rows$foed_dag, rows$referencetid),
    alder_ult_ink = age_years(rows$foed_dag, rows$referencetid),
    fdato = rows$foed_dag,
    NULL
  )
}

draw_independent_column <- function(col, n, schema) {
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
    # enumerated: false / lookup null: typed noise, no invented list
    return(typed_noise(type, n, role = role, name = name))
  }
  typed_noise(type, n, role = role, name = name)
}

typed_noise <- function(type, n, role = NULL, name = NULL) {
  if (identical(type, "integer")) {
    return(sample.int(11L, n, replace = TRUE) - 1L)
  }
  if (identical(type, "date")) {
    return(as.Date("1990-01-01") + sample.int(10000L, n, replace = TRUE) - 1L)
  }
  if (identical(role, "identifier") || (identical(role, "join_key") && !identical(name, "pnr"))) {
    prefix <- if (identical(role, "join_key")) "H" else "I"
    return(sprintf("%s%07d", prefix, sample.int(10000000L, n, replace = TRUE) - 1L))
  }
  sprintf("%03d", sample.int(1000L, n, replace = TRUE) - 1L)
}
