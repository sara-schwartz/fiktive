# NPU / DNK sampling for lab_dm_forsker::analysiscode via LabTerm (SDS) or
# published IFCC C-NPU dump. Never invent NPU/DNK lists.

.fiktive_labterm_stamp <- new.env(parent = emptyenv())
.fiktive_labterm_cache <- new.env(parent = emptyenv())

.LABTERM_CODE_RE <- "^(NPU|DNK)[0-9]{5}$"

# Public IFCC C-NPU codes (international NPU). Full Danish LabTerm dumps
# (NPU + DNK) require SDS registration at labterm.dk.
.IFCC_NPU_CSV_URL <- "https://cms.ifcc.org/wp-content/uploads/npu-codes-latest.csv"

#' Load LabTerm / NPU analyte codes
#'
#' `lab_dm_forsker.analysiscode` is NPU or Danish DNK terminology. PLAN locks
#' LabTerm (SDS) as the external catalogue SoT — do not invent code lists.
#' Point `path`, option `fiktive.labterm`, or env `FIKTIVE_LABTERM` at a LabTerm
#' publication CSV/XML or the public IFCC C-NPU CSV. Optional
#' `FIKTIVE_LABTERM_URL` (or the IFCC default when `fetch_ifcc = TRUE`) downloads
#' a published dump into the user cache. There is no CRAN LabTerm package.
#'
#' @param path Path to a LabTerm / IFCC CSV (or character vector of codes).
#' @param cache_dir Runtime cache under [tools::R_user_dir()].
#' @param required If `TRUE` (default), missing catalogue is a SCHEMA GAP.
#' @param fetch_ifcc If `TRUE`, attempt the public IFCC NPU CSV when no local
#'   dump is configured. Default: option `fiktive.labterm_fetch_ifcc`, else
#'   `FALSE` (tests and offline use stay deterministic).
#'
#' @return A list with `codes`, `version`, `source`, `path`. `NULL` when
#'   `required = FALSE` and nothing is found.
#' @export
load_labterm_catalogue <- function(path = NULL,
                                   cache_dir = NULL,
                                   required = TRUE,
                                   fetch_ifcc = NULL) {
  if (isTRUE(getOption("fiktive.labterm_disable"))) {
    return(labterm_missing(required))
  }

  cache_dir <- cache_dir %||% getOption("fiktive.labterm_cache") %||%
    file.path(tools::R_user_dir("fiktive", "cache"), "labterm")

  mem <- .fiktive_labterm_cache$catalogue
  if (!is.null(mem) && is.null(path)) {
    return(mem)
  }

  resolved <- resolve_labterm_source(
    path = path,
    cache_dir = cache_dir,
    fetch_ifcc = fetch_ifcc
  )
  if (is.null(resolved)) {
    return(labterm_missing(required))
  }

  catalogue <- parse_labterm_source(resolved)
  if (is.null(catalogue) || !length(catalogue$codes)) {
    return(labterm_missing(required))
  }

  .fiktive_labterm_cache$catalogue <- catalogue
  catalogue
}

labterm_missing <- function(required) {
  .fiktive_labterm_cache$catalogue <- NULL
  if (!isTRUE(required)) {
    return(NULL)
  }
  schema_gap(
    paste(
      "LabTerm / NPU catalogue for lab_dm_forsker analysiscode.",
      "SDS LabTerm publication files require registration",
      "(https://www.labterm.dk/; labterm@sundhedsdata.dk).",
      "A public IFCC C-NPU CSV is also accepted",
      paste0("(", .IFCC_NPU_CSV_URL, ")."),
      "Do not invent NPU/DNK lists."
    ),
    paste(
      "FIKTIVE_LABTERM (or option fiktive.labterm) pointing at a LabTerm/IFCC",
      "CSV, FIKTIVE_LABTERM_URL, or option fiktive.labterm_fetch_ifcc = TRUE",
      "for the published IFCC dump. Never sprintf NPU noise."
    )
  )
}

resolve_labterm_source <- function(path = NULL, cache_dir = NULL, fetch_ifcc = NULL) {
  if (!is.null(path)) {
    return(as_labterm_source(path))
  }

  opt <- getOption("fiktive.labterm")
  src <- as_labterm_source(opt)
  if (!is.null(src)) {
    return(src)
  }

  env <- Sys.getenv("FIKTIVE_LABTERM", unset = "")
  src <- as_labterm_source(env)
  if (!is.null(src)) {
    return(src)
  }

  url <- Sys.getenv("FIKTIVE_LABTERM_URL", unset = "")
  if (!nzchar(url)) {
    url_opt <- getOption("fiktive.labterm_url")
    if (is.character(url_opt) && length(url_opt) && nzchar(url_opt[[1]])) {
      url <- as.character(url_opt[[1]])
    }
  }
  do_fetch <- fetch_ifcc
  if (is.null(do_fetch)) {
    do_fetch <- isTRUE(getOption("fiktive.labterm_fetch_ifcc"))
  }
  if (!nzchar(url) && isTRUE(do_fetch)) {
    url <- .IFCC_NPU_CSV_URL
  }
  if (nzchar(url)) {
    fetched <- fetch_labterm_url(url, cache_dir = cache_dir)
    if (!is.null(fetched)) {
      return(fetched)
    }
  }

  # Cached download from a previous run
  if (!is.null(cache_dir) && dir.exists(cache_dir)) {
    cands <- list.files(cache_dir, pattern = "\\.(csv|txt|xml)$", full.names = TRUE, ignore.case = TRUE)
    if (length(cands)) {
      return(as_labterm_source(cands[[1]]))
    }
  }
  NULL
}

as_labterm_source <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is.character(x) && length(x) > 1L) {
    codes <- labterm_form(x)
    if (!length(codes)) {
      return(NULL)
    }
    return(list(kind = "codes", codes = codes, path = NA_character_, version = "inline"))
  }
  if (is.character(x) && length(x) == 1L) {
    if (!nzchar(x) || !file.exists(x)) {
      # Single token that looks like a code?
      codes <- labterm_form(x)
      if (length(codes)) {
        return(list(kind = "codes", codes = codes, path = NA_character_, version = "inline"))
      }
      return(NULL)
    }
    return(list(kind = "file", path = normalizePath(x, winslash = "/", mustWork = TRUE)))
  }
  NULL
}

fetch_labterm_url <- function(url, cache_dir = NULL) {
  if (is.null(cache_dir)) {
    return(NULL)
  }
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(cache_dir, "npu-codes-latest.csv")
  if (file.exists(dest) && file.info(dest)$size > 0) {
    return(list(kind = "file", path = dest, version = "cached", source_url = url))
  }
  ok <- tryCatch(
    utils::download.file(
      url,
      destfile = dest,
      quiet = TRUE,
      mode = "wb",
      headers = c("User-Agent" = "fiktive (https://github.com/sara-schwartz/fiktive)")
    ),
    error = function(e) 1L
  )
  if (!identical(ok, 0L) || !file.exists(dest) || file.info(dest)$size < 1) {
    unlink(dest)
    return(NULL)
  }
  list(kind = "file", path = dest, version = "downloaded", source_url = url)
}

parse_labterm_source <- function(resolved) {
  if (identical(resolved$kind, "codes")) {
    return(list(
      codes = unique(resolved$codes),
      version = resolved$version %||% "inline",
      source = "inline",
      path = NA_character_
    ))
  }
  path <- resolved$path
  ext <- tolower(tools::file_ext(path))
  codes <- character()
  if (ext %in% c("csv", "txt", "tsv")) {
    codes <- parse_labterm_csv(path)
  } else if (ext %in% c("xml")) {
    # LabTerm publishes XML; extract NPU/DNK tokens without inventing a schema.
    raw <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    codes <- labterm_form(unique(unlist(regmatches(
      raw,
      gregexpr("(NPU|DNK)[0-9]{5}", raw, ignore.case = TRUE)
    ))))
  } else {
    # Fallback: scan text for NPU/DNK tokens
    raw <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    codes <- labterm_form(unique(unlist(regmatches(
      raw,
      gregexpr("(NPU|DNK)[0-9]{5}", raw, ignore.case = TRUE)
    ))))
  }
  if (!length(codes)) {
    return(NULL)
  }
  list(
    codes = unique(codes),
    version = resolved$version %||% basename(path),
    source = if (!is.null(resolved$source_url)) resolved$source_url else path,
    path = path
  )
}

parse_labterm_csv <- function(path) {
  d <- tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) NULL
  )
  if (is.null(d) || !nrow(d)) {
    return(character())
  }
  nms <- names(d)
  col <- NULL
  for (cand in c("npu_code", "NPU_code", "NPU", "npu", "code", "Code", "ANALYSISCODE")) {
    if (cand %in% nms) {
      col <- cand
      break
    }
  }
  if (is.null(col)) {
    # Scan all columns for NPU/DNK tokens
    pool <- unique(as.character(unlist(d, use.names = FALSE)))
    return(labterm_form(pool))
  }
  labterm_form(d[[col]])
}

labterm_form <- function(codes) {
  codes <- gsub("[[:space:]]+", "", as.character(codes))
  codes <- toupper(codes)
  codes <- codes[grepl(.LABTERM_CODE_RE, codes)]
  unique(codes)
}

load_labterm_codes <- function() {
  cat_tbl <- tryCatch(
    load_labterm_catalogue(required = FALSE),
    error = function(e) NULL
  )
  if (is.null(cat_tbl) || !length(cat_tbl$codes)) {
    return(character())
  }
  .fiktive_labterm_stamp$catalogue <- cat_tbl$source %||% "LabTerm/NPU"
  .fiktive_labterm_stamp$version <- as.character(cat_tbl$version %||% NA_character_)
  cat_tbl$codes
}

sample_labterm_codes <- function(n) {
  n <- as.integer(n)[[1]]
  if (n == 0L) {
    return(character())
  }
  cat_tbl <- load_labterm_catalogue(required = TRUE)
  codes <- cat_tbl$codes
  .fiktive_labterm_stamp$catalogue <- cat_tbl$source %||% "LabTerm/NPU"
  .fiktive_labterm_stamp$version <- as.character(cat_tbl$version %||% NA_character_)
  sample(codes, n, replace = TRUE)
}

stamp_labterm_catalogue <- function(tbl) {
  if (is.null(tbl) || !nrow(tbl)) {
    return(tbl)
  }
  attr(tbl, "catalogue") <- .fiktive_labterm_stamp$catalogue %||% NA_character_
  attr(tbl, "catalogue_version") <- .fiktive_labterm_stamp$version %||% NA_character_
  tbl
}
