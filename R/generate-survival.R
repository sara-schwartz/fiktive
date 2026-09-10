# time_to_event grain (STEP 9): entry_time / exit_time / event, plus
# exposure_start_time / ever_exposed for immortal-time scenarios. Custom-
# register-only -- no schema register has this shape yet. Unlike every other
# grain, the scenario IS the generator here: structural generation and
# scenario application aren't separate steps, because the whole point is the
# correlation between exposure timing and event timing, which independent
# column draws + a later perturbation can't express. See notes/PLAN.md
# STEP 9 for the full design and the piecewise-exponential derivation.

generate_immortal_time_cohort <- function(population, bias, from, to, seed) {
  from <- as_date1(from)
  to <- as_date1(to)
  if (is.na(from) || is.na(to) || to < from) {
    stop("`from` must be a Date on or before `to`.", call. = FALSE)
  }
  with_rng_seed(seed, {
    n <- nrow(population)
    baseline_hazard <- as.numeric(bias$baseline_hazard %||% 0.1)[[1]]
    hr <- as.numeric(bias$true_hazard_ratio %||% 1)[[1]]
    exposure_rate <- as.numeric(bias$exposure_rate %||% 0.2)[[1]]
    if (baseline_hazard <= 0 || exposure_rate <= 0 || hr <= 0) {
      stop("`baseline_hazard`, `exposure_rate`, and `true_hazard_ratio` must be positive.", call. = FALSE)
    }
    horizon <- as.numeric(to - from, units = "days") / 365.25
    draw_immortal_time(n, baseline_hazard, hr, exposure_rate, horizon, pnr = population$pnr)
  })
}

# Split out from generate_immortal_time_cohort() so the truth-side
# simulation (simulate_expected_naive_immortal_time() in R/truth.R) can
# call the exact same DGP without going through population/date plumbing.
draw_immortal_time <- function(n, baseline_hazard, hr, exposure_rate, horizon, pnr = NULL) {
  # Piecewise-exponential time-varying-exposure survival draw: an unexposed
  # clock at baseline_hazard, an independent exposure-start clock at
  # exposure_rate. If exposure would start before the unexposed clock
  # fires, the *remaining* time from exposure start is redrawn under the
  # exposed hazard (baseline_hazard * hr) -- exact under the memoryless
  # property of the exponential distribution, not an approximation.
  t_unexposed <- stats::rexp(n, rate = baseline_hazard)
  t_exposure_start <- stats::rexp(n, rate = exposure_rate)
  exposed_before_event <- t_exposure_start < t_unexposed
  t_remaining_exposed <- stats::rexp(n, rate = baseline_hazard * hr)
  event_time <- ifelse(exposed_before_event, t_exposure_start + t_remaining_exposed, t_unexposed)
  exposure_start_time <- ifelse(exposed_before_event, t_exposure_start, NA_real_)
  # Administrative censoring at the end of the requested follow-up window.
  event <- as.integer(event_time <= horizon)
  exit_time <- pmin(event_time, horizon)
  # Exposure that would only have started after censoring never happened
  # within the observed window.
  after_censoring <- !is.na(exposure_start_time) & exposure_start_time > exit_time
  exposure_start_time[after_censoring] <- NA_real_
  ever_exposed <- as.integer(!is.na(exposure_start_time))
  out <- tibble::tibble(
    entry_time = rep(0, n),
    exit_time = exit_time,
    event = event,
    exposure_start_time = exposure_start_time,
    ever_exposed = ever_exposed
  )
  if (!is.null(pnr)) {
    out <- tibble::tibble(pnr = pnr, out)
  }
  out
}
