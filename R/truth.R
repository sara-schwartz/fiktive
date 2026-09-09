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
#' Fills `associations` with one exposure->outcome link. `confounders` and
#' `biases` stay empty. Coefficients live **only** here -- never in schema YAML
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
#' One confounder affecting exposure and outcome; known E->Y coefficient.
#' Truth stamps distinct naive vs adjusted expectations.
#'
#' @param exposure,outcome,confounder `register.column` refs (same register).
#' @param link Link for Y|E,U (default `"identity"`).
#' @param coefficient E->Y effect on the link scale.
#' @param affects_exposure Coefficient U->E.
#' @param affects_outcome Coefficient U->Y (additive on the linear predictor).
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
#' orthogonal -- use `fidelity = "clean"` (default) when evaluating truth.
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

#' Code misclassification bias scenario (STEP 8d)
#'
#' Generates an association, then **swaps** a coded column's true value for
#' a different value already occurring elsewhere in that same column (never
#' an invented code), with a probability that can depend on the outcome.
#' Models measurement error in a diagnosis/drug/other code column, e.g. a
#' mislabeled ICD or ATC code. `misclass_coefficient = 0` (the default) is
#' **non-differential** misclassification: a flat rate from
#' `misclass_intercept` alone, independent of outcome. A non-zero
#' `misclass_coefficient` makes it **differential**: the misclassification
#' rate itself depends on the outcome's value, which is a materially
#' different (and often worse) bias than the non-differential case.
#'
#' @inheritParams scenario_mnar
#' @param on Column whose values get swapped. Unlike [scenario_mnar()] /
#'   [scenario_complete_case()], this defaults to `exposure`, not `outcome`
#'   — code misclassification is usually about the exposure/diagnosis code,
#'   not the outcome.
#' @param misclass_intercept,misclass_coefficient Logit intercept / slope
#'   for P(misclassified). The slope multiplies the **outcome's** value
#'   (not `on`'s value) — that is what makes misclassification
#'   differential vs. non-differential.
#' @param id Scenario id (default `"misclassification"`).
#' @return A list of class `fiktive_scenario`.
#' @export
scenario_misclassification <- function(exposure, outcome,
                                       link = c("identity", "logit", "log"),
                                       coefficient,
                                       on = NULL,
                                       misclass_intercept = -2,
                                       misclass_coefficient = 0,
                                       intercept = 0,
                                       sigma = 1,
                                       id = "misclassification",
                                       version = 1L) {
  link <- match.arg(link)
  if (missing(coefficient) || length(coefficient) != 1L || is.na(coefficient) ||
      !is.numeric(coefficient)) {
    stop("`coefficient` must be a single non-NA number.", call. = FALSE)
  }
  parse_register_column(exposure, "exposure")
  parse_register_column(outcome, "outcome")
  on_ref <- if (is.null(on)) as.character(exposure)[[1]] else as.character(on)[[1]]
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
      type = "misclassification",
      on = on_ref,
      intercept = as.numeric(misclass_intercept)[[1]],
      coefficient = as.numeric(misclass_coefficient)[[1]]
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

# MNAR / complete-case selection bias (identity link) has no closed form for
# a logit-shaped P(missing | on) in general -- it depends on the exposure's
# actual distribution, which make_truth_from_scenario() cannot see (truth is
# a function of the scenario alone, not the generated data). This simulates
# the exact same DGP the real generator uses (draw_outcome_from_exposure(),
# invlogit() selection) against a standard-normal reference exposure, with a
# fixed internal seed so it is a deterministic calculation, not a fresh
# random draw. It is exact for a standard-normal exposure and an
# approximation otherwise -- accuracy degrades the further the real exposure
# is from that (e.g. a narrow uniform range, or a skewed/bounded column).
.MNAR_SIM_N <- 200000L
.MNAR_SIM_SEED <- 20260909L

simulate_expected_naive_selection <- function(beta, intercept, sigma,
                                              bias_intercept, bias_coefficient,
                                              on_is_exposure, drop_rows) {
  with_rng_seed(.MNAR_SIM_SEED, {
    n <- .MNAR_SIM_N
    x <- stats::rnorm(n)
    y <- intercept + beta * x + stats::rnorm(n, sd = sigma)
    z <- if (isTRUE(on_is_exposure)) x else y
    p <- stats::plogis(bias_intercept + bias_coefficient * z)
    if (isTRUE(drop_rows)) {
      keep <- stats::runif(n) < p
      x_obs <- x[keep]
      y_obs <- y[keep]
    } else {
      miss <- stats::runif(n) < p
      x_obs <- x[!miss]
      y_obs <- y[!miss]
    }
    if (length(x_obs) < 30L || stats::sd(x_obs) < 1e-8) {
      return(NA_real_)
    }
    unname(stats::coef(stats::lm(y_obs ~ x_obs))[[2]])
  })
}

# Same reference-exposure / fixed-seed approach as
# simulate_expected_naive_selection(), for misclassification instead of
# missingness/selection. P(misclassified) always depends on the outcome
# (differential when bias_coefficient != 0) regardless of which column
# (`on`) actually gets its value swapped -- mirrors the real generator
# (apply_biases()'s "misclassification" branch, R/scenario-apply.R), where
# the swap driver and the swapped column can differ. A "swap" is modelled
# as replacing the value with a fresh, independent draw from the same
# reference distribution -- what a large-sample cyclic shift among the
# flagged rows (the real generator's mechanism) converges to.
simulate_expected_naive_misclassification <- function(beta, intercept, sigma,
                                                       bias_intercept, bias_coefficient,
                                                       on_is_exposure) {
  with_rng_seed(.MNAR_SIM_SEED, {
    n <- .MNAR_SIM_N
    x <- stats::rnorm(n)
    y <- intercept + beta * x + stats::rnorm(n, sd = sigma)
    p <- stats::plogis(bias_intercept + bias_coefficient * y)
    swap <- stats::runif(n) < p
    idx <- which(swap)
    # Flagged rows are not a uniform random subset when bias_coefficient
    # != 0 (differential): P(flagged) depends on y, which correlates with
    # x. Resampling a swapped value from an unconditional fresh draw would
    # ignore that. The real generator (apply_biases()'s "misclassification"
    # branch) cyclic-shifts values *within* the flagged rows only -- match
    # that by resampling within the same flagged pool, not the unconditional
    # marginal.
    if (isTRUE(on_is_exposure)) {
      x_obs <- x
      if (length(idx) > 1L) {
        x_obs[idx] <- sample(x[idx])
      }
      if (stats::sd(x_obs) < 1e-8) {
        return(NA_real_)
      }
      return(unname(stats::coef(stats::lm(y ~ x_obs))[[2]]))
    }
    y_obs <- y
    if (length(idx) > 1L) {
      y_obs[idx] <- sample(y[idx])
    }
    if (stats::sd(x) < 1e-8) {
      return(NA_real_)
    }
    unname(stats::coef(stats::lm(y_obs ~ x))[[2]])
  })
}

#' @noRd
make_truth_from_scenario <- function(scenario) {
  sc <- as_fiktive_scenario(scenario)
  if (identical(sc$id, "independence") &&
      !length(sc$associations) && !length(sc$confounders) && !length(sc$biases)) {
    return(make_independence_truth())
  }

  assoc <- first_or_null(sc$associations)
  if (is.null(assoc)) {
    stop("Non-independence scenario needs at least one association.", call. = FALSE)
  }
  link <- as.character(assoc$link)[[1]]
  beta <- as.numeric(assoc$coefficient)[[1]]
  exposure <- as.character(assoc$exposure)[[1]]
  outcome <- as.character(assoc$outcome)[[1]]

  causal_effect <- list(
    estimand = sprintf("E[%s | %s] association on %s scale", outcome, exposure, link),
    parameter = sprintf("coefficient(%s \u2192 %s)", exposure, outcome),
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
      # Under MNAR-on-outcome, complete-case OLS is biased. For identity
      # link, simulate the actual naive expectation under this scenario's
      # own mnar_intercept/mnar_coefficient (see
      # simulate_expected_naive_selection()) instead of a fixed offset that
      # ignored how strong the missingness mechanism actually is.
      on_ref <- as.character(b$on %||% outcome)[[1]]
      if (identical(link, "identity") &&
          (identical(tolower(on_ref), tolower(outcome)) ||
           identical(tolower(on_ref), tolower(exposure)))) {
        exp_naive <- simulate_expected_naive_selection(
          beta = beta,
          intercept = as.numeric(assoc$intercept %||% 0)[[1]],
          sigma = as.numeric(assoc$sigma %||% 1)[[1]],
          bias_intercept = as.numeric(b$intercept %||% -1)[[1]],
          bias_coefficient = as.numeric(b$coefficient %||% 1)[[1]],
          on_is_exposure = identical(tolower(on_ref), tolower(exposure)),
          drop_rows = FALSE
        )
      } else {
        exp_naive <- NA_real_
      }
      if (is.na(exp_naive)) {
        # Non-identity link, or `on` references a third column this
        # simulation has no information about: fall back to a fixed
        # distinct value so expected_naive != expected_adjusted still holds.
        exp_naive <- beta * 0.5
        if (identical(exp_naive, beta)) {
          exp_naive <- beta - sign(beta + 1e-8) * 0.5
        }
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
      # Selection on outcome biases the slope. For identity link, simulate
      # the actual naive expectation under this scenario's own
      # selection_intercept/selection_coefficient (see
      # simulate_expected_naive_selection()) instead of a fixed offset that
      # ignored how strong the selection mechanism actually is.
      on_ref <- as.character(b$on %||% outcome)[[1]]
      if (identical(link, "identity") &&
          (identical(tolower(on_ref), tolower(outcome)) ||
           identical(tolower(on_ref), tolower(exposure)))) {
        exp_naive <- simulate_expected_naive_selection(
          beta = beta,
          intercept = as.numeric(assoc$intercept %||% 0)[[1]],
          sigma = as.numeric(assoc$sigma %||% 1)[[1]],
          bias_intercept = as.numeric(b$intercept %||% 0)[[1]],
          bias_coefficient = as.numeric(b$coefficient %||% 1)[[1]],
          on_is_exposure = identical(tolower(on_ref), tolower(exposure)),
          drop_rows = TRUE
        )
      } else {
        exp_naive <- NA_real_
      }
      if (is.na(exp_naive)) {
        # Non-identity link, or `on` references a third column this
        # simulation has no information about: fall back to a fixed
        # distinct value so expected_naive != expected_adjusted still holds.
        exp_naive <- beta * 0.5
        if (identical(exp_naive, beta)) {
          exp_naive <- beta - sign(beta + 1e-8) * 0.5
        }
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
    if (identical(typ, "misclassification")) {
      on_ref <- as.character(b$on %||% exposure)[[1]]
      est <- sprintf(
        "population %s-link coefficient of %s on %s (correctly classified)",
        link, exposure, outcome
      )
      naive <- sprintf(
        "unadjusted %s fit of %s ~ %s with misclassification on %s",
        link, outcome, exposure, on_ref
      )
      adj <- sprintf(
        "correctly classified (or bias-corrected) %s fit of %s ~ %s",
        link, outcome, exposure
      )
      # Differential-by-outcome measurement error on exposure or outcome.
      # For identity link, simulate the actual naive expectation under this
      # scenario's own misclass_intercept/misclass_coefficient (see
      # simulate_expected_naive_misclassification()) instead of a fixed
      # offset blind to how strong the misclassification actually is.
      if (identical(link, "identity") &&
          (identical(tolower(on_ref), tolower(outcome)) ||
           identical(tolower(on_ref), tolower(exposure)))) {
        exp_naive <- simulate_expected_naive_misclassification(
          beta = beta,
          intercept = as.numeric(assoc$intercept %||% 0)[[1]],
          sigma = as.numeric(assoc$sigma %||% 1)[[1]],
          bias_intercept = as.numeric(b$intercept %||% -2)[[1]],
          bias_coefficient = as.numeric(b$coefficient %||% 0)[[1]],
          on_is_exposure = identical(tolower(on_ref), tolower(exposure))
        )
      } else {
        exp_naive <- NA_real_
      }
      if (is.na(exp_naive)) {
        # Non-identity link, or `on` references a third column this
        # simulation has no information about: fall back to a fixed
        # distinct value so expected_naive != expected_adjusted still holds.
        exp_naive <- beta * 0.5
        if (identical(exp_naive, beta)) {
          exp_naive <- beta - sign(beta + 1e-8) * 0.5
        }
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
