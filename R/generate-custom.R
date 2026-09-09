# Custom / external registers (STEP 7) — structure only; never raw extracts;
# never coefficients in the column CSV.
# Public generate_custom_register() lives in zz-step8a-wire.R (scenario + fidelity).

.CUSTOM_ALLOWED_TYPES <- c("character", "integer", "numeric", "date", "logical", "datetime")

resolve_custom_join_keys <- function(grain, join_keys) {
  if (identical(grain, "household_year")) {
    if (is.null(join_keys) || !length(join_keys)) {
      stop(
        "`join_keys` is required for household_year customs ",
        "(e.g. familie_id); refusing a silent pnr default.",
        call. = FALSE
      )
    }
    jk <- as.character(join_keys)
    if (anyNA(jk) || any(!nzchar(jk))) {
      stop("`join_keys` must be non-empty character names.", call. = FALSE)
    }
    non_pnr <- setdiff(jk, "pnr")
    if (!length(non_pnr)) {
      stop(
        "`join_keys` for household_year must be household-side ",
        "(e.g. familie_id), not pnr.",
        call. = FALSE
      )
    }
    return(jk)
  }
  if (is.null(join_keys) || !length(join_keys)) {
    return("pnr")
  }
  jk <- as.character(join_keys)
  if (anyNA(jk) || any(!nzchar(jk))) {
    stop("`join_keys` must be non-empty character names.", call. = FALSE)
  }
  jk
}

parse_custom_columns <- function(columns) {
  if (is.character(columns) && length(columns) == 1L) {
    path <- columns[[1]]
    if (!file.exists(path)) {
      stop("columns CSV not found: ", path, call. = FALSE)
    }
    columns <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (!is.data.frame(columns)) {
    stop("`columns` must be a tibble/data.frame or a CSV path.", call. = FALSE)
  }
  nms <- names(columns)
  if (!all(c("name", "type") %in% nms)) {
    stop("`columns` must have at least `name` and `type` columns.", call. = FALSE)
  }
  # Structural columns only — ignore coeff / prevalence / etc. extras.
  keep <- intersect(c("name", "type", "min", "max", "values"), nms)
  columns <- columns[, keep, drop = FALSE]
  columns$name <- as.character(columns$name)
  columns$type <- as.character(columns$type)
  if (!nrow(columns) || any(!nzchar(columns$name))) {
    stop("`columns` must have at least one named column.", call. = FALSE)
  }
  bad_type <- setdiff(unique(columns$type), .CUSTOM_ALLOWED_TYPES)
  if (length(bad_type)) {
    schema_gap(
      sprintf("custom column type(s) %s", paste(bad_type, collapse = ", ")),
      "character / integer / numeric / date / logical (or datetime)"
    )
  }
  columns
}

build_custom_spec <- function(id, grain, join_keys, col_df) {
  cols <- lapply(seq_len(nrow(col_df)), function(i) {
    col <- list(
      id = col_df$name[[i]],
      name = col_df$name[[i]],
      type = col_df$type[[i]]
    )
    if ("min" %in% names(col_df) && !is.na(col_df$min[[i]])) {
      col$min <- col_df$min[[i]]
    }
    if ("max" %in% names(col_df) && !is.na(col_df$max[[i]])) {
      col$max <- col_df$max[[i]]
    }
    if ("values" %in% names(col_df) && !is.na(col_df$values[[i]]) &&
        nzchar(as.character(col_df$values[[i]]))) {
      col$values <- parse_custom_values(col_df$values[[i]])
    }
    if (col$name %in% join_keys) {
      col$role <- "join_key"
    }
    col
  })
  # Ensure join keys appear as columns even if omitted from the CSV.
  have <- vapply(cols, function(c) c$name, character(1))
  for (jk in join_keys) {
    if (!jk %in% have) {
      cols <- c(
        list(list(id = jk, name = jk, type = "character", role = "join_key")),
        cols
      )
    }
  }
  # household_year grain is household x year — include year when omitted.
  have <- vapply(cols, function(c) c$name, character(1))
  if (identical(grain, "household_year") && !"year" %in% have) {
    cols <- c(cols, list(list(id = "year", name = "year", type = "integer")))
  }
  list(
    id = id,
    name = id,
    one_row_per = grain,
    join_keys = as.list(join_keys),
    columns = cols
  )
}

parse_custom_values <- function(x) {
  if (is.null(x) || (length(x) == 1L && is.na(x))) {
    return(NULL)
  }
  if (is.list(x)) {
    return(unlist(x, use.names = FALSE))
  }
  if (is.numeric(x) || is.logical(x)) {
    return(x)
  }
  s <- as.character(x)[[1]]
  # Pipe or semicolon separated small allowed set.
  parts <- strsplit(s, "\\s*[|;]\\s*")[[1]]
  parts <- parts[nzchar(parts)]
  if (!length(parts)) {
    return(NULL)
  }
  parts
}

dispatch_custom_register <- function(spec, population, schema, from, to, seed,
                                     parent, cadence) {
  grain <- spec$one_row_per
  if (grain %in% c("person_reference_date", "person")) {
    return(generate_custom_snapshot(population, schema, spec, from, to, seed, cadence))
  }
  if (identical(grain, "event_from_person")) {
    return(generate_custom_events(population, schema, spec, from, to, seed))
  }
  if (identical(grain, "household_year")) {
    return(generate_custom_household_year(population, schema, spec, from, to, seed))
  }
  if (identical(grain, "expand_from_parent")) {
    return(generate_custom_expand(parent, schema, spec, seed))
  }
  schema_gap(
    sprintf("grain '%s' for custom register '%s'", grain, spec$id),
    "an existing schema grain"
  )
}

generate_custom_snapshot <- function(population, schema, spec, from, to, seed, cadence) {
  pop <- validate_population(population)
  from <- as_date1(from)
  to <- as_date1(to)
  if (is.na(from) || is.na(to) || to < from) {
    stop("`from` must be a Date on or before `to`.", call. = FALSE)
  }
  dates <- snapshot_dates(from, to, coverage = NULL, cadence = cadence)
  with_rng_seed(seed, {
    if (!length(dates) || !nrow(pop)) {
      return(emit_custom_table(spec, empty_scaffold(spec), schema))
    }
    grid <- tibble::tibble(
      pnr = rep(pop$pnr, each = length(dates)),
      referencetid = rep(dates, times = nrow(pop))
    )
    rows <- dplyr::left_join(grid, pop, by = "pnr")
    rows <- rows[rows$referencetid >= rows$foed_dag, , drop = FALSE]
    rows$year <- as.integer(lubridate::year(rows$referencetid))
    emit_custom_table(spec, rows, schema)
  })
}

generate_custom_events <- function(population, schema, spec, from, to, seed) {
  pop <- validate_population(population)
  from <- as_date1(from)
  to <- as_date1(to)
  if (is.na(from) || is.na(to) || to < from) {
    stop("`from` must be a Date on or before `to`.", call. = FALSE)
  }
  with_rng_seed(seed, {
    if (!nrow(pop) || to < from) {
      return(emit_custom_table(spec, empty_scaffold(spec), schema))
    }
    n_people <- nrow(pop)
    n_ev <- stats::rpois(n_people, 0.4)
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
        event_date = as.Date(event_date),
        referencetid = as.Date(event_date)
      )
    }
    rows <- dplyr::bind_rows(pieces)
    if (!nrow(rows)) {
      return(emit_custom_table(spec, empty_scaffold(spec), schema)}
    }
    rows$year <- as.integer(lubridate::year(rows$referencetid))
    emit_custom_table(spec, rows, schema)
  })
}

