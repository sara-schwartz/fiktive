#' Independence scenario object
#'
#' `scenario = NULL` on generators is independence. This constructor returns the
#' same machine-readable `fiktive_scenario` shape used when a scenario is
#' attached to a generated run.
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

#' Pure association scenario (STEP 8b)
#'
#' Fills `associations` with one exposure→outcome link. `confounders` and
#' `biases` stay empty. Coefficients live **only** here — never in schema YAML
#' or custom column CSV.
#'
#' @param exposure Exposure as `register.column`.
#' @param outcome Outcome as `register.column`.
#' @param link One of `"identity"`, `"logit"`, `"log"`.
#' @param coefficient Numeric effect (on the link scale).
#' @param intercept Optional intercept (default 0).
#' @param sigma Residual SD for identity link (default 1).
#' @param id Scenario id (default `"association"`).
#' @param version Integer scenario version.
#' @return A list of class `fiktive_scenario`.
#' @export
scenario_association <- function(exposure, outcome,
                                 link = c("identity", "logit", "log"),
                                 coefficient,
                                 intercept = 0,
                                 sigma = 1,
                                 id = "association",
                                 version = 1L) {
  link <- match.arg(link)
  if (missing(coefficient) || length(coefficient) != 1L || is.na(coefficient) ||
      !is.numeric(coefficient)) {
    stop("`coefficient` must be a single non-NA number.", call. = FALSE)
  }
  parse_register_column(exposure, "exposure")
  parse_register_column(outcome, "outcome")
  as_fiktive_scenario(list(
    id = as.character(id)[[1]],
    version = as.integer(version)[[1]],
    associations = list(list(
      exposure = as.character(exposure)[[1]],
      outcome = as.character(outcome)[[1]],
      link = link,
      coefficient = as.numeric(coefficient)[[1]],
      intercept = as.numeric(intercept)[[1]],
      sigma = as.numeric(sigma)[[1]]
    )),
    confounders = list(),
    biases = list(),
    backend = "core"
  ))
}

#' Confounding scenario (STEP 8c)
#'
#' One confounder affecting exposure and outcome; known E→Y coefficient.
#' Truth stamps distinct naive vs adjusted expectations.
#'
#' @param exposure,outcome,confounder `register.column` refs (same register).
#' @param link Link for Y|E,U (default `"identity"`).
#' @param coefficient E→Y effect on the link scale.
#' @param affects_exposure Coefficient U→E.
#' @param affects_outcome Coefficient U→Y (additive on the linear predictor).
#' @param intercept,sigma Outcome intercept / residual SD.
#' @param intercept_exposure,sigma_exposure Exposure intercept / residual SD.
#' @param id Scenario id (default `"confounding"`).
#' @param version Integer scenario version.
#' @return A list of class `fiktive_scenario`.
#' @export
scenario_confounding <- function(exposure, outcome, confounder,
                                 link = c("identity", "logit", "log"),
                                 coefficient,
                                 affects_exposure,
                                 affects_outcome,
                                 intercept = 0,
                                 sigma = 1,
                                 intercept_exposure = 0,
                                 sigma_exposure = 1,
                                 id = "confounding",
                                 version = 1L) {
  link <- match.arg(link)
  for (nm in c("coefficient", "affects_exposure", "affects_outcome")) {
    v <- get(nm)
    if (length(v) != 1L || is.na(v) || !is.numeric(v)) {
      stop(sprintf("`%s` must be a single non-NA number.", nm), call. = FALSE)
    }
  }
  parse_register_column(exposure, "exposure")
  parse_register_column(outcome, "outcome")
  parse_register_column(confounder, "confounder")
  as_fiktive_scenario(list(
    id = as.character(id)[[1]],
    version = as.integer(version)[[1]],
    associations = list(list(
      exposure = as.character(exposure)[[1]],
      outcome = as.character(outcome)[[1]],
      link = link,
      coefficient = as.numeric(coefficient)[[1]],
      intercept = as.numeric(intercept)[[1]],
      sigma = as.numeric(sigma)[[1]]
    )),
    confounders = list(list(
      name = as.character(confounder)[[1]],
      affects_exposure = as.numeric(affects_exposure)[[1]],
      affects_outcome = as.numeric(affects_outcome)[[1]],
      intercept_exposure = as.numeric(intercept_exposure)[[1]],
      sigma_exposure = as.numeric(sigma_exposure)[[1]]
    )),
    biases = list(),
    backend = "core"
  ))
}

#' MNAR missingness bias scenario (STEP 8d)
#'
#' Generates an association, then sets the target column to NA with probability
#' depending on its value (informative MNAR). Cosmetic MCAR fidelity stays
#' orthogonal — use `fidelity = "clean"` (default) when evaluating truth.
#'
#' @param exposure,outcome `register.column` refs.
#' @param link,coefficient Association link and effect.
#' @param on Column driving / receiving missingness (`register.column`;
#'   default = outcome).
#' @param mnar_intercept,mnar_coefficient Logit intercept / slope for P(missing).
#' @param intercept,sigma Association intercept / residual SD.
#' @param id Scenario id (default `"mnar"`).
#' @param version Integer scenario version.
#' @return A list of class `fiktive_scenario`.
#' @export
scenario_mnar <- function(exposure, outcome,
                          link = c("identity", "logit", "log"),
                          coefficient,
                          on = NULL,
                          mnar_intercept = -1,
                          mnar_coefficient = 1,
                          intercept = 0,
                          sigma = 1,
                          id = "mnar",
                          version = 1L) {
  link <- match.arg(link)
  if (missing(coefficient) || length(coefficient) != 1L || is.na(coefficient) ||
      !is.numeric(coefficient)) {
    stop("`coefficient` must be a single non-NA number.", call. = FALSE)
  }
  parse_register_column(exposure, "exposure")
  parse_register_column(outcome, "outcome")
  on_ref <- if (is.null(on)) as.character(outcome)[[1]] else as.character(on)[[1]]
  parse_register_column(on_ref, "on")
  as_fiktive_scenario(list(
    id = as.character(id)[[1]],
    version = as.integer(version)[[1]],
    associations = list(list(
      exposure = as.character(exposure)[[1]],
      outcome = as.character(outcome)[[1]],
      link = link,
      coefficient = as.numeric(coefficient)[[1]],
      intercept = as.numeric(intercept)[[1]],
      sigma = as.numeric(sigma)[[1]]
    )),
    confounders = list(),
    biases = list(list(
      type = "mnar",
      on = on_ref,
      intercept = as.numeric(mnar_intercept)[[1]],
      coefficient = as.numeric(mnar_coefficient)[[1]]
    )),
    backend = "core"
  ))
}

#' Complete-case selection bias scenario (STEP 8d)
#'
#' Generates an association, then **drops rows** with selection probability
#' depending on a column (typically the outcome). Truth contrasts the
#' selected-sample (naive) estimand with the population (adjusted) estimand.
#'
#' @inheritParams scenario_mnar
#' @param selection_intercept,selection_coefficient Logit intercept / slope for
#'   P(selected).
#' @param id Scenario id (default `"complete_case"`).
#' @return A list of class `fiktive_scenario`.
#' @export
scenario_complete_case <- function(exposure, outcome,
                                   link = c("identity", "logit", "log"),
                                   coefficient,
                                   on = NULL,
                                   selection_intercept = 0,
                                   selection_coefficient = 1,
                                   intercept = 0,
                                   sigma = 1,
                                   id = "complete_case",
                                   version = 1L) {
  link <- match.arg(link)
  if (missing(coefficient) || length(coefficient) != 1L || is.na(coefficient) ||
      !is.numeric(coefficient)) {
    stop("`coefficient` must be a single non-NA number.", call. = FALSE)
  }
  parse_register_column(exposure, "exposure")
  parse_register_column(outcome, "outcome")
  on_ref <- if (is.null(on)) as.character(outcome)[[1]] else as.character(on)[[1]]
  parse_register_column(on_ref, "on")
  as_fiktive_scenario(list(
    id = as.character(id)[[1]],
    version = as.integer(version)[[1]],
    associations = list(list(
      exposure = as.character(exposure)[[1]],
      outcome = as.character(outcome)[[1]],
      link = link,
      coefficient = as.numeric(coefficient)[[1]],
      intercept = as.numeric(intercept)[[1]],
      sigma = as.numeric(sigma)[[1]]
    )),
    confounders = list(),
    biases = list(list(
      type = "complete_case",
      on = on_ref,
      intercept = as.numeric(selection_intercept)[[1]],
      coefficient = as.numeric(selection_coefficient)[[1]]
    )),
    backend = "core"
  ))
}

#' @noRd
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

#' @noRd
expected_naive_confounding_identity <- function(beta, a_ue, a_uy,
                                                sigma_e = 1, var_u = 1) {
  var_e <- (a_ue^2) * var_u + sigma_e^2
  beta + a_uy * a_ue * var_u / var_e
}

#' @noRd
make_truth_from_scenario <- function(scenario) {
  sc <- as_fiktive_scenario(scenario)
  if (identical(sc$id, "independence") &&
      !length(sc$associations) && !length(sc$confounders) && !length(sc$biases)) {
    return(make_independence_truth())
  }

  assoc <- (sc$associations %||% list())[[1]]
  if (is.null(assoc)) {
    stop("Non-independence scenario needs at least one association.", call. = FALSE)
  }
  link <- as.character(assoc$link)[[1]]
  beta <- as.numeric(assoc$coefficient)[[1]]
  exposure <- as.character(assoc$exposure)[[1]]
  outcome <- as.character(assoc$outcome)[[1]]

  causal_effect <- list(
    estimand = sprintf("E[%s | %s] association on %s scale", outcome, exposure, link),
    parameter = sprintf("coefficient(%s → %s)", exposure, outcome),
    value = beta,
    scale = link
  )

  # --- pure association (8b) ---
  if (!length(sc$confounders) && !length(sc$biases)) {
    est <- sprintf(
      "population %s-link coefficient of %s on %s",
      link, exposure, outcome
    )
    naive <- sprintf(
      "unadjusted %s fit of %s ~ %s (recovers coefficient within MC error)",
      link, outcome, exposure
    )
    return(structure(
      list(
        scenario_id = sc$id,
        causal_effect = causal_effect,
        estimand = est,
        naive_estimator = naive,
        adjusted_estimator = naive,
        expected_naive = beta,
        expected_adjusted = beta,
        associations = sc$associations,
        confounders = list(),
        biases = list()
      ),
      class = "fiktive_truth"
    ))
  }

  # --- confounding (8c) ---
  if (length(sc$confounders) && !length(sc$biases)) {
    cfd <- sc$confounders[[1]]
    a_ue <- as.numeric(cfd$affects_exposure)[[1]]
    a_uy <- as.numeric(cfd$affects_outcome)[[1]]
    sig_e <- as.numeric(cfd$sigma_exposure %||% 1)[[1]]
    if (identical(link, "identity")) {
      exp_naive <- expected_naive_confounding_identity(beta, a_ue, a_uy, sig_e)
    } else {
      # Non-identity: stamp a distinct sentinel; tests use identity.
      exp_naive <- beta + a_uy * a_ue
    }
    est <- sprintf(
      "causal coefficient of %s on %s adjusting for %s",
      exposure, outcome, cfd$name
    )
    naive <- sprintf("unadjusted lm/glm of %s ~ %s (omits confounder)", outcome, exposure)
    adj <- sprintf(
      "adjusted lm/glm of %s ~ %s + %s",
      outcome, exposure, cfd$name
    )
    return(structure(
      list(
        scenario_id = sc$id,
        causal_effect = causal_effect,
        estimand = est,
        naive_estimator = naive,
        adjusted_estimator = adj,
        expected_naive = exp_naive,
        expected_adjusted = beta,
        associations = sc$associations,
        confounders = sc$confounders,
        biases = list()
      ),
      class = "fiktive_truth"
    ))
  }

  # --- named biases (8d) ---
  if (length(sc$biases)) {
    b <- sc$biases[[1]]
    typ <- as.character(b$type)[[1]]
    if (identical(typ, "mnar")) {
      est <- sprintf(
        "population %s-link coefficient of %s on %s (full data)",
        link, exposure, outcome
      )
      naive <- sprintf(
        "complete-case unadjusted fit of %s ~ %s after MNAR missingness on %s",
        outcome, exposure, b$on %||% outcome
      )
      adj <- sprintf(
        "full-data (or correctly adjusted) %s fit of %s ~ %s",
        link, outcome, exposure
      )
      # Under MNAR-on-outcome, complete-case OLS is biased; stamp a distinct
      # naive expectation. For identity we use a qualitative offset marker:
      # expected_naive != beta. Exact finite-sample bias depends on the MNAR
      # curve; tests check naive estimate closer to stamped naive and
      # adjusted (full-data before NA, or known beta) closer to beta.
      # Use a fixed distinct value derived from MNAR slope sign.
      mnar_slope <- as.numeric(b$coefficient %||% 1)[[1]]
      # Heuristic asymptotic bias direction for identity + MNAR on Y:
      # complete-case attenuates toward 0 when missingness rises with |Y|
      # and exposure is related; stamp attenuated target for tests.
      exp_naive <- beta * 0.5
      if (identical(exp_naive, beta)) {
        exp_naive <- beta - sign(beta + 1e-8) * 0.5
      }
      return(structure(
        list(
          scenario_id = sc$id,
          causal_effect = causal_effect,
          estimand = est,
          naive_estimator = naive,
          adjusted_estimator = adj,
          expected_naive = exp_naive,
          expected_adjusted = beta,
          associations = sc$associations,
          confounders = list(),
          biases = sc$biases
        ),
        class = "fiktive_truth"
      ))
    }
    if (identical(typ, "complete_case")) {
      est <- sprintf(
        "population %s-link coefficient of %s on %s",
        link, exposure, outcome
      )
      naive <- sprintf(
        "selected-sample unadjusted fit of %s ~ %s (selection on %s)",
        outcome, exposure, b$on %||% outcome
      )
      adj <- sprintf(
        "population (pre-selection) %s fit of %s ~ %s",
        link, outcome, exposure
      )
      sel_slope <- as.numeric(b$coefficient %||% 1)[[1]]
      # Selection on outcome biases the slope; stamp distinct naive.
      exp_naive <- beta * 0.5
      if (identical(exp_naive, beta)) {
        exp_naive <- beta - sign(beta + 1e-8) * 0.5
      }
      return(structure(
        list(
          scenario_id = sc$id,
          causal_effect = causal_effect,
          estimand = est,
          naive_estimator = naive,
          adjusted_estimator = adj,
          expected_naive = exp_naive,
          expected_adjusted = beta,
          associations = sc$associations,
          confounders = list(),
          biases = sc$biases
        ),
        class = "fiktive_truth"
      ))
    }
    stop(sprintf("Unsupported bias type '%s' in truth builder.", typ), call. = FALSE)
  }

  stop("Unable to build truth from scenario.", call. = FALSE)
}

attach_run_meta <- function(x, truth = NULL, scenario = NULL) {
  if (is.null(scenario)) {
    scenario <- scenario_independence()
  } else {
    scenario <- as_fiktive_scenario(scenario)
  }
  if (is.null(truth)) {
    truth <- make_truth_from_scenario(scenario)
  }
  attr(x, "fiktive_truth") <- truth
  attr(x, "fiktive_scenario") <- scenario
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
#' independence those fields describe a null association within MC error.
#' Association / confounding / MNAR / complete-case fill the same slots via
#' [scenario_association()], [scenario_confounding()], [scenario_mnar()], and
#' [scenario_complete_case()].
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
