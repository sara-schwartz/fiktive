# Custom / external registers (STEP 7) — structure only; never raw extracts;
# never coefficients in the column CSV.

.CUSTOM_ALLOWED_TYPES <- c("character", "integer", "numeric", "date", "logical", "datetime")

#' Generate a custom / external register (structure only)
#'
#' Front door for researcher-described tables that are **not** in the guide
#' YAML. Register metadata is passed as R arguments; columns come from a CSV
#' path or tibble with `name`, `type`, and optional `min` / `max` / `values`
#' (structural noise only). Wraps the same grain engine as schema generation.
#' [generate_register()] stays schema-ids only.
#'
#' Grains: any existing schema grain (`person`, `person_reference_date`,
#' `event_from_person`, `expand_from_parent`, `household_year`). A novel grain
#' is a SCHEMA GAP. For `household_year`, `join_keys` must be household-side
#' (e.g. `familie_id`) — never a silent `pnr` default. `expand_from_parent`
#' requires an already-generated `parent` table.
#'
#' @param id Custom register id (not looked up in schema YAML).
#' @param one_row_per Grain (see details).
#' @param join_keys Character vector of join keys. Defaults to `pnr` for
#'   person-side grains; required and household-side for `household_year`.
#' @param columns CSV path or tibble/data.frame with columns `name`, `type`,
#'   and optional `min`, `max`, `values`. Extra columns (e.g. coefficients)
#'   are ignored — do not put DGP coeffs here.
#' @param population Persons table from [generate_background_population()].
#' @param schema Schema from [load_registers_schema()] (stamps / population).
#' @param from,to Window (Date or coercible).
#' @param seed Optional RNG seed.
#' @param scenario Must be `NULL` (independence).
#' @param parent Already-generated parent table when
#'   `one_row_per = "expand_from_parent"`.
#' @param cadence Snapshot cadence: `"annual"` (default) or `"quarterly"`.
#'
#' @return A tibble of structural noise that joins on `join_keys`.
#' @export
generate_custom_register <- function(id, one_row_per, join_keys = NULL, columns,
                                     population, schema, from, to,
                                     seed = NULL, scenario = NULL,
                                     parent = NULL, cadence = NULL) {
  if (!is.null(scenario)) {
    stop("Only scenario = NULL (independence) is supported.", call. = FALSE)
  }
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  id <- as.character(id)[[1]]
  if (!nzchar(id)) {
    stop("`id` must be a non-empty string.", call. = FALSE)
  }
  grain <- as.character(one_row_per)[[1]]
  if (!grain %in% .KNOWN_GRAINS || identical(grain, "unknown")) {
    schema_gap(
      sprintf("one_row_per '%s' for custom register '%s'", grain, id),
      "an existing schema grain (person / person_reference_date / event_from_person / expand_from_parent / household_year); do not invent a new grain"
    )
  }
  join_keys <- resolve_custom_join_keys(grain, join_keys)
  col_df <- parse_custom_columns(columns)
  spec <- build_custom_spec(id, grain, join_keys, col_df)
  if (identical(grain, "expand_from_parent")) {
    if (is.null(parent)) {
      stop(
        "`parent` table is required for expand_from_parent customs; do not invent parents.",
        call. = FALSE
      )
    }
    if (!is.data.frame(parent)) {
      stop("`parent` must be a data frame / tibble.", call. = FALSE)
    }
  }
  cad <- cadence %||% "annual"
  if (!cad %in% c("annual", "quarterly")) {
    stop("`cadence` must be \"annual\" or \"quarterly\".", call. = FALSE)
  }
  tbl <- dispatch_custom_register(
    spec, population, schema, from, to, seed,
    parent = parent, cadence = cad
  )
  stamp_generation(tbl, schema = schema, seed = seed)
}

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
