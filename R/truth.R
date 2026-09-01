#' Truth slots for a generated run
#'
#' STEP 1 stub. Slots exist so later steps can fill estimands and estimators
#' without changing the API. No numbers are invented here.
#'
#' @param x Unused. Reserved for a generated object.
#' @param ... Unused.
#'
#' @return A list with empty `estimand`, `naive_estimator`,
#'   `adjusted_estimator`, `expected_naive`, and `expected_adjusted` slots.
#' @export
get_truth <- function(x = NULL, ...) {
  list(
    estimand = NULL,
    naive_estimator = NULL,
    adjusted_estimator = NULL,
    expected_naive = NULL,
    expected_adjusted = NULL
  )
}
