#' Generate several schema registers (opt-in batch)
#'
#' Builds **only** the named schema registers. `registers` is **required** —
#' there is no silent default of every implemented id. Customs are not accepted
#' here; use [generate_custom_register()] one-at-a-time.
#'
#' @param registers Character vector of schema register ids (required).
#' @param population Persons table from [generate_background_population()].
#' @param schema Schema from [load_registers_schema()].
#' @param from Start of the requested window (Date or coercible).
#' @param to End of the requested window (Date or coercible).
#' @param seed Optional RNG seed. Restored on exit (per register call).
#' @param scenario Must be `NULL` (independence).
#'
#' @return A named list of tibbles, one per requested id (lowercase names).
#' @export
generate_registers <- function(registers, population, schema, from, to,
                               seed = NULL, scenario = NULL) {
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
      scenario = scenario
    )
  }
  out
}
