# Generic runtime loader for schema code systems declared as
# values_from.kind = "csv" (e.g. disco08, DST's occupation classification;
# nace_db07, DST's industry classification) -- the schema records a real,
# publicly downloadable DST file (url/delimiter/encoding/column names) as
# the source of truth but ships no `lookup` baked in. fiktive will not
# invent an occupation/industry code list -- this only loads one that's
# actually published, same "opt-in runtime fetch, cached under
# tools::R_user_dir()" pattern as R/catalogue-labterm.R and
# R/catalogue-atc.R. Off by default so tests/offline runs stay
# deterministic.

.fiktive_csv_cs_cache <- new.env(parent = emptyenv())

#' Load a `values_from.kind = "csv"` code system's published codes
#'
#' Some schema code systems (e.g. `disco08`, DST's DISCO-08 occupation
#' classification, used by `akm`) declare a real, publicly downloadable CSV
#' as their source of truth (`values_from.url`) but the schema itself ships
#' no `lookup` -- fiktive will not invent a code list, so a column drawing
#' from one of these errors with a `SCHEMA GAP` until this is loaded.
#'
#' Unlike [load_labterm_catalogue()] or [load_whocc_atc_catalogue()], these
#' DST classification files need no registration or account -- they're
#' plain public downloads -- so the only opt-in step is telling fiktive to
#' actually fetch one, which it never does on its own by default.
#'
#' Point option `fiktive.<cs_id>` or env `FIKTIVE_<CS_ID>` at an
#' already-downloaded copy, or set option `fiktive.fetch_<cs_id> = TRUE`
#' (or env `FIKTIVE_FETCH_<CS_ID> = "true"`) to download the schema's own
#' `values_from.url` into the user cache. `fiktive.<cs_id>_url` /
#' `FIKTIVE_<CS_ID>_URL` override that URL if DST ever moves the file.
#'
#' @param cs_id Code system id, e.g. `"disco08"`.
#' @param vf The code system's `values_from` spec (`url`, `delimiter`,
#'   `encoding`, `code_column`, `label_column`, optional `level`/
#'   `level_column` to keep only one hierarchy level).
#' @param path Path to an already-downloaded copy of the file.
#' @param cache_dir Runtime cache under [tools::R_user_dir()]. Default:
#'   `file.path(tools::R_user_dir("fiktive", "cache"), "csv-catalogues", cs_id)`.
#' @param fetch If `TRUE`, download `values_from.url` when no local copy is
#'   configured. Default: option `fiktive.fetch_<cs_id>` (or env
#'   `FIKTIVE_FETCH_<CS_ID>`), else `FALSE`.
#'
#' @return A named list (`code = label`), or `NULL` if nothing resolved.
#' @export
load_csv_code_system <- function(cs_id, vf, path = NULL, cache_dir = NULL, fetch = NULL) {
  cs_id <- as.character(cs_id)[[1]]
  env_key <- toupper(cs_id)

  if (isTRUE(getOption(paste0("fiktive.", cs_id, "_disable")))) {
    return(NULL)
  }

  cache_dir <- cache_dir %||%
    file.path(tools::R_user_dir("fiktive", "cache"), "csv-catalogues", cs_id)

  mem <- .fiktive_csv_cs_cache[[cs_id]]
  if (!is.null(mem) && is.null(path)) {
    return(mem)
  }

  resolved <- resolve_csv_cs_source(
    cs_id, env_key, vf,
    path = path, cache_dir = cache_dir, fetch = fetch
  )
  if (is.null(resolved)) {
    return(NULL)
  }

  lookup <- parse_csv_cs_source(resolved, vf)
  if (is.null(lookup) || !length(lookup)) {
    return(NULL)
  }

  .fiktive_csv_cs_cache[[cs_id]] <- lookup
  lookup
}

resolve_csv_cs_source <- function(cs_id, env_key, vf, path = NULL, cache_dir = NULL, fetch = NULL) {
  if (!is.null(path)) {
    return(path)
  }

  opt <- getOption(paste0("fiktive.", cs_id))
  if (is.character(opt) && length(opt) && nzchar(opt[[1]]) && file.exists(opt[[1]])) {
    return(opt[[1]])
  }
  env <- Sys.getenv(paste0("FIKTIVE_", env_key), unset = "")
  if (nzchar(env) && file.exists(env)) {
    return(env)
  }

  url <- Sys.getenv(paste0("FIKTIVE_", env_key, "_URL"), unset = "")
  if (!nzchar(url)) {
    url_opt <- getOption(paste0("fiktive.", cs_id, "_url"))
    if (is.character(url_opt) && length(url_opt) && nzchar(url_opt[[1]])) {
      url <- url_opt[[1]]
    }
  }
  if (!nzchar(url)) {
    url <- as.character(vf$url %||% "")
  }

  do_fetch <- fetch
  if (is.null(do_fetch)) {
    do_fetch <- isTRUE(getOption(paste0("fiktive.fetch_", cs_id))) ||
      identical(tolower(Sys.getenv(paste0("FIKTIVE_FETCH_", env_key), unset = "")), "true")
  }
  if (nzchar(url) && isTRUE(do_fetch)) {
    fetched <- fetch_csv_cs_url(url, cache_dir = cache_dir)
    if (!is.null(fetched)) {
      return(fetched)
    }
  }

  # Cached download from a previous run.
  if (!is.null(cache_dir) && dir.exists(cache_dir)) {
    cands <- list.files(cache_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
    if (length(cands)) {
      return(cands[[1]])
    }
  }
  NULL
}

fetch_csv_cs_url <- function(url, cache_dir) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(cache_dir, "catalogue.csv")
  if (file.exists(dest) && file.info(dest)$size > 0) {
    return(dest)
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
  dest
}

# Handles the UTF-8-with-BOM encoding DST's classification CSVs ship as
# (base R's read.csv has no "UTF-8-BOM" fileEncoding) and an optional
# hierarchy-level filter (disco08/nace_db07 ship every level in one file;
# values_from.level says which one is the intended granularity).
parse_csv_cs_source <- function(path, vf) {
  raw <- readBin(path, "raw", file.info(path)$size)
  bom <- as.raw(c(0xEF, 0xBB, 0xBF))
  if (length(raw) >= 3L && identical(raw[1:3], bom)) {
    raw <- raw[-(1:3)]
  }
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  d <- tryCatch(
    utils::read.csv(
      text = txt,
      sep = as.character(vf$delimiter %||% ";"),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      encoding = "UTF-8"
    ),
    error = function(e) NULL
  )
  if (is.null(d) || !nrow(d)) {
    return(NULL)
  }
  code_col <- as.character(vf$code_column %||% "")
  label_col <- as.character(vf$label_column %||% "")
  if (!nzchar(code_col) || !code_col %in% names(d)) {
    return(NULL)
  }
  if (!is.null(vf$level) && !is.null(vf$level_column) && vf$level_column %in% names(d)) {
    d <- d[as.character(d[[vf$level_column]]) == as.character(vf$level), , drop = FALSE]
  }
  if (!nrow(d)) {
    return(NULL)
  }
  codes <- gsub('^"|"$', "", trimws(as.character(d[[code_col]])))
  labels <- if (nzchar(label_col) && label_col %in% names(d)) {
    as.character(d[[label_col]])
  } else {
    codes
  }
  keep <- nzchar(codes)
  codes <- codes[keep]
  labels <- labels[keep]
  if (!length(codes)) {
    return(NULL)
  }
  stats::setNames(as.list(labels), codes)
}
