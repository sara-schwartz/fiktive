#' Load WHO ICD-10 Version:2019 codes and map to Danish D-prefix form
#'
#' LPR diagnosis codes use the Danish edition: WHO `E11` appears as `DE11`.
#' The source list is WHO ICD-10 2019 category/leaf codes (icdcdn / browse10
#' 2019 tabular), shipped under `inst/extdata/who_icd10_2019_codes.txt`.
#' Dots are stripped and a leading `D` is prepended. This is not `decoder`,
#' not SKS, and not schema `sample_values`.
#'
#' @param refresh If `TRUE`, ignore the in-memory catalogue and reload.
#' @return A list with `who_codes`, `danish_codes`, `version`, and `source`.
#' @export
load_who_icd10_catalogue <- function(refresh = FALSE) {
  if (!isTRUE(refresh) && !is.null(.fiktive_icd$catalogue)) {
    return(.fiktive_icd$catalogue)
  }
  path <- who_icd10_extdata_path()
  if (is.null(path) || !file.exists(path)) {
    schema_gap(
      "WHO ICD-10 Version:2019 catalogue is missing from package extdata",
      "inst/extdata/who_icd10_2019_codes.txt from icdcdn / WHO browse10 2019"
    )
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- trimws(lines)
  lines <- lines[nzchar(lines) & !startsWith(lines, "#")]
  who_codes <- unique(lines)
  who_codes <- who_codes[grepl("^[A-Z][0-9]{2}", who_codes)]
  if (!length(who_codes)) {
    schema_gap(
      "WHO ICD-10 Version:2019 catalogue file has no codes",
      "a non-empty who_icd10_2019_codes.txt from the WHO 2019 release"
    )
  }
  danish_codes <- who_to_danish_icd10(who_codes)
  cat <- list(
    who_codes = who_codes,
    danish_codes = danish_codes,
    version = "WHO ICD-10 Version:2019",
    source = "WHO ICD-10 2019 (icdcdn / browse10) + Danish D-prefix"
  )
  .fiktive_icd$catalogue <- cat
  cat
}

.fiktive_icd <- new.env(parent = emptyenv())

who_icd10_extdata_path <- function() {
  opt <- getOption("fiktive.who_icd10_path")
  if (is.character(opt) && length(opt) == 1L && nzchar(opt) && file.exists(opt)) {
    return(normalizePath(opt, winslash = "/", mustWork = TRUE))
  }
  pkg <- tryCatch(
    system.file("extdata", "who_icd10_2019_codes.txt", package = "fiktive"),
    error = function(e) ""
  )
  if (nzchar(pkg) && file.exists(pkg)) {
    return(pkg)
  }
  candidates <- c(
    file.path(getwd(), "inst", "extdata", "who_icd10_2019_codes.txt"),
    file.path(getwd(), "..", "inst", "extdata", "who_icd10_2019_codes.txt"),
    file.path(getwd(), "..", "..", "inst", "extdata", "who_icd10_2019_codes.txt")
  )
  if (requireNamespace("testthat", quietly = TRUE)) {
    tp <- tryCatch(
      testthat::test_path("..", "..", "inst", "extdata", "who_icd10_2019_codes.txt"),
      error = function(e) ""
    )
    candidates <- c(tp, candidates)
  }
  for (p in candidates) {
    if (nzchar(p) && file.exists(p)) {
      return(normalizePath(p, winslash = "/", mustWork = TRUE))
    }
  }
  NULL
}

#' Map WHO ICD-10 codes to Danish LPR D-prefix form (E11 -> DE11).
#' @param who Character WHO codes (optional dots).
#' @return Character Danish codes.
#' @export
who_to_danish_icd10 <- function(who) {
  who <- as.character(who)
  who <- gsub("\\.", "", who, fixed = FALSE)
  who <- toupper(who)
  paste0("D", who)
}

sample_danish_icd10 <- function(n) {
  n <- as.integer(n)
  if (length(n) != 1L || is.na(n) || n < 0L) {
    stop("`n` must be a non-negative integer.", call. = FALSE)
  }
  if (n == 0L) {
    return(character())
  }
  cat <- load_who_icd10_catalogue()
  sample(cat$danish_codes, n, replace = TRUE)
}

icd10_catalogue_stamp <- function() {
  cat <- .fiktive_icd$catalogue
  list(
    catalogue = cat$source %||% "WHO ICD-10 2019 + Danish D-prefix",
    version = cat$version %||% "WHO ICD-10 Version:2019"
  )
}

reset_who_icd10_catalogue <- function() {
  .fiktive_icd$catalogue <- NULL
  invisible(NULL)
}

draw_icd10_codes <- function(name, n, type, register_id) {
  register_id <- as.character(register_id %||% "")
  if (!register_id %in% c("lpr_diag", "lpr_a_diagnose")) {
    return(na_of_type(type %||% "character", n))
  }
  coerce_schema_type(sample_danish_icd10(n), type %||% "character")
}
