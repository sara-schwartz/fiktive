# Write-out helpers (STEP 7). Primary generator return stays in-memory;
# these persist tables and stamps. Never call outputs "extracts."

fiktive_pkg_version <- function() {
  tryCatch(
    as.character(utils::packageVersion("fiktive")),
    error = function(e) "0.0.0.9000"
  )
}

#' Attach generation stamps to a register table
#'
#' Stamps schema commit, seed, and package version. Catalogue stamps already
#' set by emitters are preserved. Used by generators and available for tests.
#'
#' @param tbl A tibble.
#' @param schema Schema from [load_registers_schema()], or `NULL`.
#' @param seed Optional RNG seed used for the draw.
#' @return `tbl` with stamp attributes.
#' @keywords internal
stamp_generation <- function(tbl, schema = NULL, seed = NULL) {
  if (!is.null(schema) && !is.null(schema$schema_commit)) {
    attr(tbl, "schema_commit") <- as.character(schema$schema_commit)[[1]]
  }
  if (!is.null(seed)) {
    attr(tbl, "seed") <- seed
  }
  attr(tbl, "fiktive_version") <- fiktive_pkg_version()
  tbl
}

#' Read stamp attributes from a generated table
#'
#' @param tbl A tibble from a generator or after [write_register()] reload.
#' @return A named list of stamp fields (missing stamps are `NULL`).
#' @export
register_stamps <- function(tbl) {
  list(
    schema_commit = attr(tbl, "schema_commit", exact = TRUE),
    seed = attr(tbl, "seed", exact = TRUE),
    fiktive_version = attr(tbl, "fiktive_version", exact = TRUE),
    catalogue = attr(tbl, "catalogue", exact = TRUE),
    catalogue_version = attr(tbl, "catalogue_version", exact = TRUE),
    fidelity = attr(tbl, "fidelity", exact = TRUE),
    na_rate = attr(tbl, "na_rate", exact = TRUE),
    outlier_rate = attr(tbl, "outlier_rate", exact = TRUE)
  )
}

stamp_meta_list <- function(tbl) {
  meta <- list()
  st <- register_stamps(tbl)
  if (!is.null(st$schema_commit)) {
    meta$schema_commit <- st$schema_commit
  }
  if (!is.null(st$seed)) {
    meta$seed <- st$seed
  }
  if (!is.null(st$fiktive_version)) {
    meta$fiktive_version <- st$fiktive_version
  }
  if (!is.null(st$catalogue)) {
    meta$catalogue <- st$catalogue
  }
  if (!is.null(st$catalogue_version)) {
    meta$catalogue_version <- st$catalogue_version
  }
  if (!is.null(st$fidelity)) {
    meta$fidelity <- st$fidelity
  }
  if (!is.null(st$na_rate)) {
    meta$na_rate <- st$na_rate
  }
  if (!is.null(st$outlier_rate)) {
    meta$outlier_rate <- st$outlier_rate
  }
  meta
}

write_stamp_sidecar <- function(data_path, tbl) {
  meta <- stamp_meta_list(tbl)
  if (!length(meta)) {
    return(invisible(NULL))
  }
  meta_path <- paste0(data_path, ".meta.yaml")
  yaml::write_yaml(meta, meta_path)
  invisible(meta_path)
}

#' Write a generated register table to disk
#'
#' Default on-disk format is **CSV**. Parquet and optional hive `year=`
#' partitioning (via arrow) are **opt-in**. Stamps (schema SHA, seed, package
#' version, catalogue when present) are written as a `.meta.yaml` sidecar next
#' to the data file (or under the hive root as `_fiktive_meta.yaml`).
#' Generators still return in-memory tibbles; this only persists.
#'
#' @param data A tibble from [generate_register()], [generate_registers()],
#'   or [generate_custom_register()].
#' @param path Output file path (csv/parquet) or directory (when
#'   `hive_year = TRUE`).
#' @param format `"csv"` (default) or `"parquet"`.
#' @param hive_year If `TRUE`, write parquet hive partitions `year=YYYY/`
#'   under `path` (requires a `year` column and the arrow package).
#'
#' @return Invisibly, the path written (file or hive root).
#' @export
write_register <- function(data, path, format = c("csv", "parquet"),
                           hive_year = FALSE) {
  format <- match.arg(format)
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame / tibble.", call. = FALSE)
  }
  hive_year <- isTRUE(hive_year)
  if (hive_year && !identical(format, "parquet")) {
    stop("`hive_year = TRUE` requires format = \"parquet\".", call. = FALSE)
  }
  if (hive_year) {
    return(invisible(write_register_hive(data, path)))
  }
  if (identical(format, "csv")) {
    out <- ensure_ext(path, "csv")
    dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(data, out, row.names = FALSE, na = "")
    write_stamp_sidecar(out, data)
    return(invisible(out))
  }
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' is required for parquet write-out.", call. = FALSE)
  }
  out <- ensure_ext(path, "parquet")
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  arrow::write_parquet(data, out)
  write_stamp_sidecar(out, data)
  invisible(out)
}

write_register_hive <- function(data, path) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' is required for parquet hive write-out.", call. = FALSE)
  }
  if (!"year" %in% names(data)) {
    stop("`hive_year = TRUE` requires a `year` column on the table.", call. = FALSE)
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  arrow::write_dataset(
    data,
    path,
    format = "parquet",
    partitioning = "year",
    hive_style = TRUE
  )
  yaml::write_yaml(stamp_meta_list(data), file.path(path, "_fiktive_meta.yaml"))
  invisible(path)
}

ensure_ext <- function(path, ext) {
  path <- as.character(path)[[1]]
  re <- paste0("\\.", ext, "$")
  if (grepl(re, path, ignore.case = TRUE)) {
    return(path)
  }
  paste0(path, ".", ext)
}

#' Write several generated register tables
#'
#' @param tables Named list of tibbles.
#' @param dir Output directory.
#' @param format `"csv"` (default) or `"parquet"`.
#' @param hive_year Passed to [write_register()].
#' @return Invisibly, `dir`.
#' @export
write_registers <- function(tables, dir, format = c("csv", "parquet"),
                            hive_year = FALSE) {
  format <- match.arg(format)
  if (!is.list(tables) || is.null(names(tables)) || any(!nzchar(names(tables)))) {
    stop("`tables` must be a named list of tibbles.", call. = FALSE)
  }
  dir <- as.character(dir)[[1]]
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  for (nm in names(tables)) {
    if (isTRUE(hive_year)) {
      write_register(
        tables[[nm]],
        file.path(dir, nm),
        format = format,
        hive_year = TRUE
      )
    } else {
      write_register(
        tables[[nm]],
        file.path(dir, nm),
        format = format,
        hive_year = FALSE
      )
    }
  }
  invisible(dir)
}
