#' Load official WHO ATC codes from WHOCC Oslo
#'
#' Denmark's LMDB uses the WHO Anatomical Therapeutic Chemical classification
#' published by the WHO Collaborating Centre for Drug Statistics Methodology
#' (WHOCC) in Oslo: \\url{https://atcddd.fhi.no/atc_ddd_index/}.
#'
#' The complete structured index (Excel or XML) is **not** an unauthenticated
#' public dump. WHOCC documents that it is downloaded from a **registered user
#' account** at \\url{https://orders.atcddd.fhi.no/}. This function does not scrape
#' the searchable website into the package, does not vendor the index in git,
#' and does not use `decoder::atc` (Swedish MPA).
#'
#' Point `path`, option `fiktive.whocc_atc`, or env var `FIKTIVE_WHOCC_ATC` at
#' a downloaded Excel, XML, or text dump. Parsed 7-character codes are cached
#' under [tools::R_user_dir()] (`"fiktive"`, `"cache"`), not `inst/extdata`.
#' Generated LMDB tables stamp `atc_catalogue` and `atc_catalogue_version`.
#'
#' @param path Path to a WHOCC Excel (`.xlsx`), XML, CSV, TSV, or text dump.
#'   Default: `fiktive.whocc_atc` option, then `FIKTIVE_WHOCC_ATC`, then the
#'   user cache. A character vector of 7-character codes is accepted in tests.
#' @param cache_dir Runtime cache directory. Default:
#'   `file.path(tools::R_user_dir("fiktive", "cache"), "whocc-atc")`.
#' @param required If `TRUE` (default), missing catalogue is a SCHEMA GAP with
#'   an install/account message. If `FALSE`, return `NULL`.
#'
#' @return A list with `codes` (unique 7-character WHO ATC codes), `version`,
#'   `source`, and `path`. `NULL` when `required = FALSE` and nothing is found.
#' @export
load_whocc_atc_catalogue <- function(path = NULL, cache_dir = NULL, required = TRUE) {
  if (isTRUE(getOption("fiktive.whocc_atc_disable"))) {
    return(whocc_atc_missing(required))
  }

  cache_dir <- cache_dir %||% getOption("fiktive.whocc_atc_cache") %||%
    file.path(tools::R_user_dir("fiktive", "cache"), "whocc-atc")

  mem <- .fiktive_whocc_atc$catalogue
  if (!is.null(mem) && is.null(path)) {
    return(mem)
  }

  resolved <- resolve_whocc_atc_source(path = path, cache_dir = cache_dir)
  if (is.null(resolved)) {
    return(whocc_atc_missing(required))
  }

  catalogue <- parse_whocc_atc_source(resolved, cache_dir = cache_dir)
  if (is.null(catalogue) || !length(catalogue$codes)) {
    return(whocc_atc_missing(required))
  }

  .fiktive_whocc_atc$catalogue <- catalogue
  catalogue
}

.fiktive_whocc_atc <- new.env(parent = emptyenv())

.ATC_LEVEL5 <- "^[A-Z][0-9]{2}[A-Z]{2}[0-9]{2}$"

whocc_atc_missing <- function(required) {
  .fiktive_whocc_atc$catalogue <- NULL
  if (!isTRUE(required)) {
    return(NULL)
  }
  schema_gap(
    paste(
      "WHOCC Oslo ATC catalogue (official WHO ATC/DDD Index).",
      "A registered WHOCC account is required to download the complete",
      "Excel/XML index from https://orders.atcddd.fhi.no/.",
      "See https://atcddd.fhi.no/atc_ddd_index/.",
      "There is no unauthenticated public dump of the complete index."
    ),
    paste(
      "FIKTIVE_WHOCC_ATC (or option fiktive.whocc_atc) pointing at that dump,",
      "or the same file in tools::R_user_dir(\"fiktive\", \"cache\")/whocc-atc.",
      "Do not use decoder::atc (Swedish MPA). Never sprintf ATC fallback."
    )
  )
}

resolve_whocc_atc_source <- function(path = NULL, cache_dir = NULL) {
  if (!is.null(path)) {
    return(as_whocc_source(path))
  }

  opt <- getOption("fiktive.whocc_atc")
  src <- as_whocc_source(opt)
  if (!is.null(src)) {
    return(src)
  }

  env <- Sys.getenv("FIKTIVE_WHOCC_ATC", unset = "")
  src <- as_whocc_source(env)
  if (!is.null(src)) {
    return(src)
  }

  url <- Sys.getenv("FIKTIVE_WHOCC_ATC_URL", unset = "")
  if (nzchar(url)) {
    fetched <- fetch_whocc_atc_url(url, cache_dir = cache_dir)
    if (!is.null(fetched)) {
      return(fetched)
    }
  }

  find_whocc_atc_cache(cache_dir)
}

as_whocc_source <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is.list(x) && !is.null(x$codes)) {
    codes <- extract_atc_level5(x$codes)
    if (!length(codes)) {
      return(NULL)
    }
    return(list(
      type = "memory",
      codes = codes,
      version = as.character(x$version %||% "in-memory"),
      path = NA_character_
    ))
  }
  if (is.character(x) && length(x) > 1L) {
    codes <- extract_atc_level5(x)
    if (!length(codes)) {
      return(NULL)
    }
    return(list(
      type = "memory",
      codes = codes,
      version = as.character(getOption("fiktive.whocc_atc_version") %||% "in-memory"),
      path = NA_character_
    ))
  }
  if (is.character(x) && length(x) == 1L && nzchar(x)) {
    if (file.exists(x)) {
      return(list(type = "file", path = normalizePath(x, winslash = "/", mustWork = TRUE)))
    }
    codes <- extract_atc_level5(x)
    if (length(codes) == 1L) {
      return(list(
        type = "memory",
        codes = codes,
        version = as.character(getOption("fiktive.whocc_atc_version") %||% "in-memory"),
        path = NA_character_
      ))
    }
  }
  NULL
}
