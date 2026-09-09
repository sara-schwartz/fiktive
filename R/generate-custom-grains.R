generate_custom_household_year <- function(population, schema, spec, from, to, seed) {
  pop <- validate_population(population)
  from <- as_date1(from)
  to <- as_date1(to)
  if (is.na(from) || is.na(to) || to < from) {
    stop("`from` must be a Date on or before `to`.", call. = FALSE)
  }
  hh_key <- setdiff(as.character(unlist(spec$join_keys)), "pnr")[[1]]
  with_rng_seed(seed, {
    if (!nrow(pop) || to < from) {
      return(emit_custom_table(spec, empty_scaffold(spec), schema))
    }
    y0 <- lubridate::year(from)
    y1 <- lubridate::year(to)
    years <- seq.int(y0, y1)
    dates <- as.Date(sprintf("%d-12-31", years))
    dates <- dates[dates >= from & dates <= to]
    if (!length(dates)) {
      return(emit_custom_table(spec, empty_scaffold(spec), schema))
    }
    n_hh <- nrow(pop)
    hh_ids <- sprintf("H%07d", sample.int(10000000L, n_hh, replace = FALSE) - 1L)
    n_y <- length(dates)
    rows <- tibble::tibble(
      referencetid = rep(dates, times = n_hh),
      year = as.integer(lubridate::year(rep(dates, times = n_hh))),
      pnr = rep(NA_character_, n_hh * n_y)
    )
    rows[[hh_key]] <- rep(hh_ids, each = n_y)
    emit_custom_table(spec, rows, schema)
  })
}

generate_custom_expand <- function(parent, schema, spec, seed) {
  key <- as.character(unlist(spec$join_keys))[[1]]
  with_rng_seed(seed, {
    if (!nrow(parent)) {
      return(emit_custom_table(spec, empty_scaffold(spec), schema))
    }
    if (!key %in% names(parent)) {
      stop(
        sprintf("parent table lacks join key '%s' required by the custom register.", key),
        call. = FALSE
      )
    }
    n_parent <- nrow(parent)
    n_ch <- stats::rpois(n_parent, 1.0)
    idx <- rep(seq_len(n_parent), times = n_ch)
    if (!length(idx)) {
      return(emit_custom_table(spec, empty_scaffold(spec), schema))
    }
    rows <- tibble::tibble(placeholder = seq_along(idx))
    rows[[key]] <- as.character(parent[[key]][idx])
    rows$placeholder <- NULL
    if ("referencetid" %in% names(parent)) {
      rows$referencetid <- parent$referencetid[idx]
    } else if ("event_date" %in% names(parent)) {
      rows$referencetid <- as.Date(parent$event_date[idx])
    }
    if ("year" %in% names(parent)) {
      rows$year <- parent$year[idx]
    } else if ("referencetid" %in% names(rows)) {
      rows$year <- as.integer(lubridate::year(rows$referencetid))
    }
    emit_custom_table(spec, rows, schema)
  })
}

empty_scaffold <- function(spec) {
  tibble::tibble(.rows = 0L)
}

emit_custom_table <- function(spec, rows, schema) {
  cols <- spec$columns %||% list()
  if (!length(cols)) {
    schema_gap(
      paste(spec$id %||% "custom", "columns"),
      "a columns CSV/tibble with name and type"
    )
  }
  n <- nrow(rows)
  join_keys <- as.character(unlist(spec$join_keys %||% list()))
  out <- list()
  for (col in cols) {
    name <- as.character(col$name %||% col$id)
    type <- col$type %||% "character"
    if (n == 0L) {
      out[[name]] <- na_of_type(type, 0L)
      next
    }
    if (name %in% names(rows)) {
      values <- coerce_schema_type(rows[[name]], type)
    } else if (name %in% c("year") && "referencetid" %in% names(rows)) {
      values <- as.integer(lubridate::year(rows$referencetid))
    } else if (name %in% c("referencetid") && "event_date" %in% names(rows)) {
      values <- coerce_schema_type(rows$event_date, type)
    } else {
      values <- draw_custom_column(col, n)
    }
    out[[name]] <- values
  }
  tibble::as_tibble(out)
}

draw_custom_column <- function(col, n) {
  type <- col$type %||% "character"
  if (!is.null(col$values) && length(col$values)) {
    vals <- col$values
    drawn <- sample(vals, n, replace = TRUE)
    return(coerce_schema_type(drawn, type))
  }
  if (!is.null(col$min) || !is.null(col$max)) {
    return(draw_range_noise(type, n, col$min, col$max))
  }
  typed_noise(type, n, role = col$role, name = col$name)
}

draw_range_noise <- function(type, n, min_v, max_v) {
  if (identical(type, "integer")) {
    lo <- if (is.null(min_v) || is.na(min_v)) 0L else as.integer(min_v)
    hi <- if (is.null(max_v) || is.na(max_v)) lo + 10L else as.integer(max_v)
    if (hi < lo) {
      stop("custom column min must be <= max.", call. = FALSE)
    }
    return(as.integer(lo + sample.int(as.integer(hi - lo + 1L), n, replace = TRUE) - 1L))
  }
  if (identical(type, "numeric")) {
    lo <- if (is.null(min_v) || is.na(min_v)) 0 else as.numeric(min_v)
    hi <- if (is.null(max_v) || is.na(max_v)) lo + 1 else as.numeric(max_v)
    if (hi < lo) {
      stop("custom column min must be <= max.", call. = FALSE)
    }
    return(stats::runif(n, lo, hi))
  }
  if (identical(type, "date")) {
    lo <- if (is.null(min_v) || is.na(min_v)) as.Date("1990-01-01") else as_date1(min_v)
    hi <- if (is.null(max_v) || is.na(max_v)) lo + 3650 else as_date1(max_v)
    span <- as.integer(hi - lo)
    if (span < 0L) {
      stop("custom column min must be <= max.", call. = FALSE)
    }
    return(lo + sample.int(span + 1L, n, replace = TRUE) - 1L)
  }
  typed_noise(type, n)
}
