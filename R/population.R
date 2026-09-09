#' Generate a stable background population
#'
#' One row per person. The same `pnr` always has the same `foed_dag` and
#' `koen`. People persist across time; this is not a yearly random sample.
#' `pnr` is a joinable character code (zero-padded). It is not a CPR number
#' and carries no checksum or validity claim.
#'
#' @param n Number of people.
#' @param seed Optional RNG seed. Restored on exit.
#' @param schema Schema from [load_registers_schema()]. Required: `koen` is sampled from `code-systems/koen.yaml`. `NULL` is a SCHEMA GAP.
#' @param ... Unused; reserved.
#'
#' @return A tibble with `pnr`, `foed_dag`, and `koen`.
#' @export
generate_background_population <- function(n, seed = NULL, schema = NULL, ...) {
  n <- as.integer(n)
  if (length(n) != 1L || is.na(n) || n < 1L) {
    stop("`n` must be a positive integer.", call. = FALSE)
  }
  extra <- list(...)
  birth_from <- as_date1(extra$birth_from %||% as.Date("1940-01-01"))
  birth_to <- as_date1(extra$birth_to %||% as.Date("2007-12-31"))
  if (birth_to < birth_from) {
    stop("`birth_to` must be on or after `birth_from`.", call. = FALSE)
  }

  with_rng_seed(seed, {
    pnr <- sprintf("%08d", seq_len(n))
    span <- as.integer(birth_to - birth_from)
    foed_dag <- birth_from + sample.int(span + 1L, n, replace = TRUE) - 1L
    koen_keys <- koen_lookup_keys(schema)
    koen <- as.integer(sample_koen(koen_keys, n))
    tibble::tibble(
      pnr = pnr,
      foed_dag = as.Date(foed_dag),
      koen = koen
    )
  })
}

# koen.yaml's own reader_note: sex is derived deterministically from the CPR
# number (even digit = female, odd = male), so a real delivery essentially
# never contains DST's residual `9` ("Uoplyst") code even though the
# classification defines it as valid. Draw the schema's binary sex codes
# (1/2) evenly and keep any other lookup keys (9, or a future addition) as a
# rare residual rather than uniform across the whole lookup.
sample_koen <- function(keys, n) {
  binary <- keys[keys %in% c(1L, 2L)]
  residual <- keys[!keys %in% c(1L, 2L)]
  if (!length(binary)) {
    return(as.integer(sample(keys, n, replace = TRUE)))
  }
  if (!length(residual)) {
    return(as.integer(sample(binary, n, replace = TRUE)))
  }
  weights <- c(
    rep(0.999 / length(binary), length(binary)),
    rep(0.001 / length(residual), length(residual))
  )
  as.integer(sample(c(binary, residual), n, replace = TRUE, prob = weights))
}

koen_lookup_keys <- function(schema) {
  if (is.null(schema) || is.null(schema$code_systems)) {
    schema_gap(
      "schema for `koen`",
      "a schema from load_registers_schema() with code-systems/koen.yaml"
    )
  }
  cs <- schema$code_systems[["koen"]]
  if (is.null(cs)) {
    schema_gap(
      "code system `koen`",
      "code-systems/koen.yaml with a lookup of sex codes"
    )
  }
  keys <- lookup_keys(cs)
  if (is.null(keys) || !length(keys)) {
    schema_gap(
      "code system `koen` lookup",
      "lookup keys in code-systems/koen.yaml"
    )
  }
  as.integer(keys)
}
