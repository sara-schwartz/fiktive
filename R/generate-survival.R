# time_to_event grain (STEP 9). Custom-register-only -- no schema register
# has this shape yet. Unlike every other grain, the scenario IS the
# generator here: structural generation and scenario application aren't
# separate steps, because the whole point is a correlation (exposure timing
# vs event timing for immortal time; age-at-event vs delayed entry for left
# truncation) that independent column draws + a later perturbation can't
# express. Column shape depends on which scenario -- immortal time produces
# entry_time/exit_time/event/exposure_start_time/ever_exposed, left
# truncation produces entry_age/exit_age/event/group. See notes/PLAN.md
# STEP 9 for the full design.

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

# Left truncation (STEP 9 phase 2): unlike immortal time, this needs an
# age-varying (Weibull) baseline hazard to have any bias to demonstrate at
# all -- a constant (exponential) hazard is memoryless, so ignoring delayed
# entry doesn't change anything under it. Also unlike immortal time, this
# scenario's own bias only appears when true_hazard_ratio != 1: with no
# true group effect, both the correct (age-scale, left-truncated) and naive
# (time-since-entry) analyses agree (confirmed during design, not assumed).
# The clock here is age, not calendar time, so from/to (unlike immortal
# time's horizon_years) genuinely don't affect this DGP.
generate_left_truncation_cohort <- function(population, bias, seed) {
  with_rng_seed(seed, {
    n <- nrow(population)
    shape <- as.numeric(bias$shape %||% 5)[[1]]
    scale <- as.numeric(bias$scale %||% 80)[[1]]
    hr <- as.numeric(bias$true_hazard_ratio %||% 1.5)[[1]]
    max_entry_age <- as.numeric(bias$max_entry_age %||% 70)[[1]]
    if (shape <= 0 || scale <= 0 || hr <= 0 || max_entry_age <= 0) {
      stop("`shape`, `scale`, `true_hazard_ratio`, and `max_entry_age` must be positive.", call. = FALSE)
    }
    draw_left_truncation(n, shape, scale, hr, max_entry_age, pnr = population$pnr)
  })
}

# Split out so the truth-side simulation
# (simulate_expected_naive_left_truncation() in R/truth.R) can call the
# exact same DGP without going through population plumbing.
draw_left_truncation <- function(n, shape, scale, hr, max_entry_age, pnr = NULL) {
  group <- sample(c(0L, 1L), n, replace = TRUE)
  # Weibull with a proportional-hazards group effect: inverse-CDF draw of
  # the true age at event, hazard multiplied by hr for group == 1.
  u <- stats::runif(n)
  age_at_event <- scale * (-log(u) / exp(log(hr) * group))^(1 / shape)
  entry_age <- stats::runif(n, 0, max_entry_age)
  # Left truncation is a survivorship condition, not just a later time
  # zero: anyone who wouldn't have survived to their own entry age is
  # never observed at all.
  included <- entry_age < age_at_event
  # Administrative censoring at a generous multiple of the Weibull scale
  # so the tail doesn't run forever.
  censor_age <- scale * 3
  event <- as.integer(age_at_event <= censor_age)
  exit_age <- pmin(age_at_event, censor_age)
  out <- tibble::tibble(
    entry_age = entry_age,
    exit_age = exit_age,
    event = event,
    group = group
  )[included, ]
  if (!is.null(pnr)) {
    out <- tibble::tibble(pnr = pnr[included], out)
  }
  out
}
