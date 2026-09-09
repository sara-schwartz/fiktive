#' Independence scenario object
#'
#' `scenario = NULL` on generators is independence. This constructor returns the
#' same machine-readable `fiktive_scenario` shape used when a scenario is
#' attached to a generated run. Associations / confounders / biases stay empty
#' until STEP 8b+.
#'
#' @param version Integer scenario version (default `1L`).
#' @return A list of class `fiktive_scenario`.
#' @export
scenario_independence <- function(version = 1L) {
  as_fiktive_scenario(list(
    id = "independence",
    version = as.integer(version)[[1]],
    associations = list(),
    confounders = list(),
    biases = list(),
    backend = "core"
  ))
}

as_fiktive_scenario <- function(x) {
  if (inherits(x, "fiktive_scenario")) {
    return(x)
  }
  structure(
    list(
      id = as.character(x$id %||% "independence")[[1]],
      version = as.integer(x$version %||% 1L)[[1]],
      associations = x$associations %||% list(),
      confounders = x$confounders %||% list(),
      biases = x$biases %||% list(),
      backend = as.character(x$backend %||% "core")[[1]]
    ),
    class = "fiktive_scenario"
  )
}

#' Build the always-on independence truth stub
#'
#' Under `scenario = NULL`, expected association is **0 within Monte Carlo
#' error**. Bias-claim slots exist so later steps can fill named estimands /
#' estimators without reshaping the API. Confounding / MAR / MNAR are not
#' claimed here.
#'
#' @return A list of class `fiktive_truth`.
#' @keywords internal
make_independence_truth <- function() {
  structure(
    list(
      scenario_id = "independence",
      causal_effect = 0,
      estimand = paste(
        "association among non-derived columns,",
        "conditional on the person (independence: expected 0)"
      ),
      naive_estimator = paste(
        "any unadjusted association test of two non-derived columns"
      ),
      adjusted_estimator = paste(
        "same as naive under independence (null remains null)"
      ),
      expected_naive = 0,
      expected_adjusted = 0,
      associations = list(),
      confounders = list(),
      biases = list()
    ),
    class = "fiktive_truth"
  )
}

attach_run_meta <- function(x, truth = NULL, scenario = NULL) {
  if (is.null(truth)) {
    truth <- make_independence_truth()
  }
  if (is.null(scenario)) {
    scenario <- scenario_independence()
  }
  attr(x, "fiktive_truth") <- truth
  attr(x, "fiktive_scenario") <- as_fiktive_scenario(scenario)
  x
}

#' Truth slots for a generated run
#'
#' Always available, including under independence (`scenario = NULL`). Prefer
#' passing the object returned by [generate_register()], [generate_registers()],
#' or [generate_custom_register()]. When `x` is missing or has no attached
#' truth, returns the independence stub (expected association 0).
#'
#' A bias claim is invalid unless it names `estimand`, `naive_estimator`,
#' `adjusted_estimator`, `expected_naive`, and `expected_adjusted`. Under
#' independence those fields describe a null association within MC error;
#' confounding / informative missingness are deferred to STEP 8b+.
#'
#' @param x A generated tibble or named list of tibbles, or `NULL`.
#' @param ... Unused.
#'
#' @return A list of class `fiktive_truth`.
#' @export
get_truth <- function(x = NULL, ...) {
  if (!is.null(x)) {
    tr <- attr(x, "fiktive_truth", exact = TRUE)
    if (!is.null(tr)) {
      return(tr)
    }
  }
  make_independence_truth()
}

#' Scenario attached to a generated run
#'
#' @param x A generated tibble or named list of tibbles, or `NULL`.
#' @param ... Unused.
#' @return A list of class `fiktive_scenario` (independence when absent).
#' @export
get_scenario <- function(x = NULL, ...) {
  if (!is.null(x)) {
    sc <- attr(x, "fiktive_scenario", exact = TRUE)
    if (!is.null(sc)) {
      return(as_fiktive_scenario(sc))
    }
  }
  scenario_independence()
}
