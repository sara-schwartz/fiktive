test_that("scenario_immortal_time validates its parameters", {
  expect_error(scenario_immortal_time(baseline_hazard = 0), "positive")
  expect_error(scenario_immortal_time(true_hazard_ratio = -1), "positive")
  expect_error(scenario_immortal_time(exposure_rate = 0), "positive")
  expect_error(scenario_immortal_time(horizon_years = 0), "positive")
  sc <- scenario_immortal_time(true_hazard_ratio = 1.2)
  expect_s3_class(sc, "fiktive_scenario")
  expect_equal(sc$biases[[1]]$type, "immortal_time")
  expect_equal(sc$biases[[1]]$true_hazard_ratio, 1.2)
})

test_that("time_to_event grain requires scenario_immortal_time -- no independence version", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 1)
  err <- tryCatch(
    generate_custom_register(
      id = "cohort", one_row_per = "time_to_event",
      population = pop, schema = schema,
      from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
      seed = 1
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "scenario_immortal_time")

  err2 <- tryCatch(
    generate_custom_register(
      id = "cohort", one_row_per = "time_to_event",
      population = pop, schema = schema,
      from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
      seed = 1, scenario = scenario_independence()
    ),
    error = function(e) e
  )
  expect_s3_class(err2, "error")
  expect_match(err2$message, "scenario_immortal_time")
})

test_that("time_to_event generates the fixed survival shape with sane values", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 500L, seed = 2)
  sc <- scenario_immortal_time(
    baseline_hazard = 0.1, true_hazard_ratio = 1.5,
    exposure_rate = 0.2, horizon_years = 5
  )
  cohort <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 2, scenario = sc
  )
  expect_equal(nrow(cohort), nrow(pop))
  expect_named(
    cohort,
    c("pnr", "entry_time", "exit_time", "event", "exposure_start_time", "ever_exposed"),
    ignore.order = TRUE
  )
  expect_true(all(cohort$entry_time == 0))
  expect_true(all(cohort$exit_time > 0 & cohort$exit_time <= 5 + 1e-8))
  expect_true(all(cohort$event %in% c(0L, 1L)))
  expect_true(all(cohort$ever_exposed %in% c(0L, 1L)))
  expect_equal(cohort$ever_exposed, as.integer(!is.na(cohort$exposure_start_time)))
  # Anyone with a recorded exposure start must have started before they exited.
  exposed <- cohort[cohort$ever_exposed == 1L, ]
  expect_true(all(exposed$exposure_start_time <= exposed$exit_time))
  expect_false(anyNA(cohort$entry_time))
  expect_false(anyNA(cohort$exit_time))
  expect_false(anyNA(cohort$event))
})

test_that("fidelity is not applied to time_to_event (would corrupt survival columns)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 300L, seed = 3)
  sc <- scenario_immortal_time(true_hazard_ratio = 1.2, horizon_years = 5)
  clean <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 3, scenario = sc, fidelity = "clean"
  )
  messy <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 3, scenario = sc, fidelity = "messy"
  )
  expect_identical(clean$entry_time, messy$entry_time)
  expect_identical(clean$exit_time, messy$exit_time)
  expect_identical(clean$event, messy$event)
  expect_false(anyNA(messy$exit_time))
  expect_false(anyNA(messy$event))
})

test_that("immortal time bias: naive Cox model shows spurious protection; expected_naive tracks it", {
  skip_if_not_installed("survival")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 6000L, seed = 4)
  # true_hazard_ratio = 1: no real effect at all, so any naive HR below 1
  # is entirely immortal time bias, nothing else.
  sc <- scenario_immortal_time(
    baseline_hazard = 0.1, true_hazard_ratio = 1,
    exposure_rate = 0.2, horizon_years = 5
  )
  cohort <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 4, scenario = sc
  )
  fit <- survival::coxph(
    survival::Surv(entry_time, exit_time, event) ~ ever_exposed,
    data = cohort
  )
  naive_hr <- unname(exp(stats::coef(fit)[["ever_exposed"]]))
  expect_true(naive_hr < 0.8) # spurious protection despite true_hazard_ratio = 1

  tr <- get_truth(cohort)
  expect_equal(tr$scenario_id, "immortal_time")
  expect_equal(tr$expected_adjusted, 1)
  expect_equal(tr$expected_naive, naive_hr, tolerance = 0.1)
  expect_true(tr$expected_naive < tr$expected_adjusted)
})

test_that("correctly time-varying analysis recovers the true hazard ratio", {
  skip_if_not_installed("survival")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 8000L, seed = 5)
  true_hr <- 1.5
  sc <- scenario_immortal_time(
    baseline_hazard = 0.1, true_hazard_ratio = true_hr,
    exposure_rate = 0.2, horizon_years = 5
  )
  cohort <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 5, scenario = sc
  )
  # Split each exposed row into an unexposed interval [0, exposure_start)
  # and an exposed interval [exposure_start, exit_time) -- the correct,
  # time-varying analysis this scenario exists to contrast against the
  # naive fixed-baseline-covariate mistake. Vectorized (not a per-row
  # rbind loop, which is O(n^2) in base R and far too slow at n in the
  # thousands).
  never_exposed <- is.na(cohort$exposure_start_time)
  unexposed_part <- data.frame(
    tstart = 0,
    tstop = ifelse(never_exposed, cohort$exit_time, cohort$exposure_start_time),
    event = ifelse(never_exposed, cohort$event, 0L),
    exposed = 0
  )
  exposed_part <- data.frame(
    tstart = cohort$exposure_start_time[!never_exposed],
    tstop = cohort$exit_time[!never_exposed],
    event = cohort$event[!never_exposed],
    exposed = 1
  )
  cp <- rbind(unexposed_part, exposed_part)
  cp <- cp[cp$tstop > cp$tstart, ]
  fit_tv <- survival::coxph(survival::Surv(tstart, tstop, event) ~ exposed, data = cp)
  tv_hr <- unname(exp(stats::coef(fit_tv)[["exposed"]]))
  expect_equal(tv_hr, true_hr, tolerance = 0.15)
})
