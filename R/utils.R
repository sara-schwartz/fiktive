`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}

with_rng_seed <- function(seed, expr) {
  if (is.null(seed)) {
    return(force(expr))
  }
  if (!exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    set.seed(NULL)
  }
  old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit(
    assign(".Random.seed", old_seed, envir = .GlobalEnv),
    add = TRUE
  )
  set.seed(seed)
  force(expr)
}

as_date1 <- function(x) {
  if (inherits(x, "Date") && !inherits(x, "POSIXt")) {
    return(x)
  }
  if (inherits(x, "POSIXt")) {
    return(as.Date(x, tz = "UTC"))
  }
  as.Date(x)
}

as_datetime1 <- function(x) {
  if (inherits(x, "POSIXt")) {
    return(as.POSIXct(x, tz = "UTC"))
  }
  if (inherits(x, "Date")) {
    return(as.POSIXct(paste(format(x, "%Y-%m-%d"), "00:00:00"), tz = "UTC"))
  }
  as.POSIXct(x, tz = "UTC")
}

normalize_ym <- function(ym) {
  if (is.null(ym)) {
    return(NULL)
  }
  if (inherits(ym, "Date")) {
    return(format(ym, "%Y-%m-%d"))
  }
  if (is.numeric(ym) && !inherits(ym, "Date")) {
    return(sprintf("%04d", as.integer(ym)))
  }
  as.character(ym)
}

ym_start <- function(ym) {
  ym <- normalize_ym(ym)
  if (grepl("^[0-9]{4}$", ym)) {
    return(as.Date(paste0(ym, "-01-01")))
  }
  if (grepl("^[0-9]{4}-Q[1-4]$", ym)) {
    y <- substr(ym, 1L, 4L)
    q <- as.integer(substr(ym, 6L, 6L))
    month <- (q - 1L) * 3L + 1L
    return(as.Date(sprintf("%s-%02d-01", y, month)))
  }
  if (grepl("^[0-9]{4}-[0-9]{2}$", ym)) {
    return(as.Date(paste0(ym, "-01")))
  }
  as.Date(ym)
}

ym_end <- function(ym) {
  ym <- normalize_ym(ym)
  if (grepl("^[0-9]{4}$", ym)) {
    return(as.Date(paste0(ym, "-12-31")))
  }
  if (grepl("^[0-9]{4}-Q[1-4]$", ym)) {
    y <- substr(ym, 1L, 4L)
    q <- as.integer(substr(ym, 6L, 6L))
    month <- q * 3L
    start <- as.Date(sprintf("%s-%02d-01", y, month))
    return(lubridate::ceiling_date(start, unit = "month") - lubridate::days(1))
  }
  start <- ym_start(ym)
  lubridate::ceiling_date(start, unit = "month") - lubridate::days(1)
}

in_ym_coverage <- function(dates, coverage) {
  if (is.null(coverage)) {
    return(rep(TRUE, length(dates)))
  }
  dates <- as.Date(dates)
  from <- if (!is.null(coverage$from)) ym_start(coverage$from) else as.Date("0001-01-01")
  to <- if (!is.null(coverage$to)) ym_end(coverage$to) else as.Date("9999-12-31")
  dates >= from & dates <= to
}

age_years <- function(birth, when) {
  birth <- as_date1(birth)
  when <- as_date1(when)
  year_diff <- lubridate::year(when) - lubridate::year(birth)
  before_anniversary <- (
    lubridate::month(when) < lubridate::month(birth)
  ) | (
    lubridate::month(when) == lubridate::month(birth) &
      lubridate::day(when) < lubridate::day(birth)
  )
  as.integer(year_diff - as.integer(before_anniversary))
}

na_of_type <- function(type, n) {
  switch(
    type %||% "character",
    integer = rep(NA_integer_, n),
    numeric = rep(NA_real_, n),
    date = as.Date(rep(NA_real_, n), origin = "1970-01-01"),
    datetime = as.POSIXct(rep(NA_real_, n), origin = "1970-01-01", tz = "UTC"),
    character = rep(NA_character_, n),
    rep(NA, n)
  )
}

coerce_schema_type <- function(x, type) {
  switch(
    type %||% "character",
    integer = as.integer(x),
    numeric = as.numeric(x),
    date = as_date1(x),
    datetime = as_datetime1(x),
    character = as.character(x),
    as.character(x)
  )
}

lookup_keys <- function(cs) {
  if (is.null(cs) || isTRUE(identical(cs$enumerated, FALSE))) {
    return(NULL)
  }
  lu <- cs$lookup
  if (is.null(lu)) {
    return(NULL)
  }
  nms <- names(lu)
  if (is.null(nms) || !length(nms)) {
    return(NULL)
  }
  keep <- nzchar(nms) & !vapply(lu, is.null, logical(1))
  nms[keep]
}

schema_column_ids <- function(register_obj) {
  cols <- register_obj$columns %||% list()
  vapply(cols, function(col) {
    as.character(col$name %||% col$id)
  }, character(1))
}
