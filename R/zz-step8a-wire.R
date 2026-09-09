# STEP 8a — wire independence truth + opt-in fidelity through the public
# generators without reshaping grain dispatch (STEP 1–7).

#' @rdname generate_register
#' @export
generate_register <- function(register, population, schema, from, to,
                              seed = NULL, scenario = NULL,
                              fidelity = c("clean", "messy"),
                              na_rate = NULL, outlier_rate = NULL) {
  if (!is.null(scenario)) {
    stop("Only scenario = NULL (independence) is supported.", call. = FALSE)
  }
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  fidelity_info <- resolve_fidelity(fidelity, na_rate = na_rate, outlier_rate = outlier_rate)
  register <- tolower(as.character(register)[[1]])
  spec <- schema$registers[[register]]
  if (is.null(spec)) {
    schema_gap(
      sprintf("register id '%s' is not in the schema.", register),
      "a register id that exists in registers/*.yaml"
    )
  }
  tbl <- dispatch_generate_register(register, spec, population, schema, from, to, seed)
  tbl <- with_rng_seed(seed, apply_fidelity(tbl, spec, fidelity_info))
  tbl <- stamp_generation(tbl, schema = schema, seed = seed)
  attach_run_meta(tbl)
}

#' @rdname generate_registers
#' @export
generate_registers <- function(registers, population, schema, from, to,
                               seed = NULL, scenario = NULL,
                               fidelity = c("clean", "messy"),
                               na_rate = NULL, outlier_rate = NULL) {
  if (missing(registers)) {
    stop(
      "`registers` is required. Pass an explicit character vector of schema ids; ",
      "refusing a silent dump of all registers.",
      call. = FALSE
    )
  }
  if (is.null(registers) || !length(registers)) {
    stop("`registers` must be a non-empty character vector of schema ids.", call. = FALSE)
  }
  registers <- as.character(registers)
  if (anyNA(registers) || any(!nzchar(registers))) {
    stop("`registers` must be a non-empty character vector of schema ids.", call. = FALSE)
  }
  if (!is.null(scenario)) {
    stop("Only scenario = NULL (independence) is supported.", call. = FALSE)
  }
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  fidelity <- match.arg(fidelity)
  ids <- tolower(registers)
  out <- vector("list", length(ids))
  names(out) <- ids
  for (i in seq_along(ids)) {
    out[[i]] <- generate_register(
      ids[[i]],
      population = population,
      schema = schema,
      from = from,
      to = to,
      seed = seed,
      scenario = scenario,
      fidelity = fidelity,
      na_rate = na_rate,
      outlier_rate = outlier_rate
    )
  }
  attach_run_meta(out)
}

#' @rdname generate_custom_register
#' @export
generate_custom_register <- function(id, one_row_per, join_keys = NULL, columns,
                                     population, schema, from, to,
                                     seed = NULL, scenario = NULL,
                                     parent = NULL, cadence = NULL,
                                     fidelity = c("clean", "messy"),
                                     na_rate = NULL, outlier_rate = NULL) {
  if (!is.null(scenario)) {
    stop("Only scenario = NULL (independence) is supported.", call. = FALSE)
  }
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  fidelity_info <- resolve_fidelity(fidelity, na_rate = na_rate, outlier_rate = outlier_rate)
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
  tbl <- with_rng_seed(seed, apply_fidelity(tbl, spec, fidelity_info))
  tbl <- stamp_generation(tbl, schema = schema, seed = seed)
  attach_run_meta(tbl)
}
