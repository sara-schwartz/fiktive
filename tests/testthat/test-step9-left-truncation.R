test_that("scenario_left_truncation validates its parameters", {
  expect_error(scenario_left_truncation(shape = 0), "positive")
  expect_error(scenario_left_truncation(scale = -1), "positive")
  expect_error(scenario_left_truncation(true_hazard_ratio = 0), "positive")
  expect_error(scenario_left_truncation(max_entry_age = 0), "positive")
  sc <- scenario_left_truncation(true_hazard_ratio = 1.5)
  expect_s3_class(sc, "fiktive_scenario")
  expect_equal(sc$biases[[1]]$type, "left_truncation")
  expect_equal(sc$biases[[1]]$true_hazard_ratio, 1.5)
})

test_that("time_to_event grain accepts scenario_left_truncation too, not just immortal_time", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 500L, seed = 1)
  sc <- scenario_left_truncation(true_hazard_ratio = 1.5)
  cohort <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 1, scenario = sc
  )
  expect_true(is.data.frame(cohort))
  expect_true(nrow(cohort) > 0L)
})

test_that("left truncation generates the fixed shape, with left-truncation exclusion and sane values", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 2000L, seed = 2)
  sc <- scenario_left_truncation(
    shape = 5, scale = 80, true_hazard_ratio = 1.5, max_entry_age = 70
  )
  cohort <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 2, scenario = sc
  )
  expect_named(cohort, c("pnr", "entry_age", "exit_age", "event", "group"), ignore.order = TRUE)
  # Left truncation is a survivorship condition: some people who wouldn't
  # have survived to their own entry age are excluded entirely, unlike
  # immortal time (which keeps everyone).
  expect_true(nrow(cohort) < nrow(pop))
  expect_true(all(cohort$entry_age < cohort$exit_age))
  expect_true(all(cohort$event %in% c(0L, 1L)))
  expect_true(all(cohort$group %in% c(0L, 1L)))
  expect_false(anyNA(cohort$entry_age))
  expect_false(anyNA(cohort$exit_age))
  expect_false(anyNA(cohort$event))
  expect_false(anyNA(cohort$group))
})

test_that("fidelity is not applied to time_to_event left_truncation cohorts either", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 300L, seed = 3)
  sc <- scenario_left_truncation(true_hazard_ratio = 1.5)
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
  expect_identical(clean, messy)
})

test_that("no true group effect -> naive and correct analyses agree (no bias to demonstrate)", {
  skip_if_not_installed("survival")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 15000L, seed = 4)
  sc <- scenario_left_truncation(shape = 5, scale = 80, true_hazard_ratio = 1, max_entry_age = 70)
  cohort <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 4, scenario = sc
  )
  tr <- get_truth(cohort)
  expect_equal(tr$expected_adjusted, 1)
  # Confirmed during design: with no true group effect, the naive
  # (time-since-entry) and correct (left-truncated) analyses give the same
  # answer -- there's nothing for the left-truncation mistake to bias.
  expect_equal(tr$expected_naive, 1, tolerance = 0.1)
})

test_that("left truncation bias: naive Cox model is biased toward the null; expected_naive tracks it", {
  skip_if_not_installed("survival")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20000L, seed = 5)
  true_hr <- 1.5
  sc <- scenario_left_truncation(
    shape = 5, scale = 80, true_hazard_ratio = true_hr, max_entry_age = 70
  )
  cohort <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 5, scenario = sc
  )
  fit_naive <- survival::coxph(
    survival::Surv(exit_age - entry_age, event) ~ group,
    data = cohort
  )
  naive_hr <- unname(exp(stats::coef(fit_naive)[["group"]]))
  expect_true(naive_hr < true_hr - 0.05) # biased toward the null

  tr <- get_truth(cohort)
  expect_equal(tr$scenario_id, "left_truncation")
  expect_equal(tr$expected_adjusted, true_hr)
  expect_equal(tr$expected_naive, naive_hr, tolerance = 0.1)
})

test_that("correctly left-truncated analysis (age as time scale) recovers the true hazard ratio", {
  skip_if_not_installed("survival")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20000L, seed = 6)
  true_hr <- 1.5
  sc <- scenario_left_truncation(
    shape = 5, scale = 80, true_hazard_ratio = true_hr, max_entry_age = 70
  )
  cohort <- generate_custom_register(
    id = "cohort", one_row_per = "time_to_event",
    population = pop, schema = schema,
    from = as.Date("2010-01-01"), to = as.Date("2015-01-01"),
    seed = 6, scenario = sc
  )
  fit_correct <- survival::coxph(
    survival::Surv(entry_age, exit_age, event) ~ group,
    data = cohort
  )
  correct_hr <- unname(exp(stats::coef(fit_correct)[["group"]]))
  expect_equal(correct_hr, true_hr, tolerance = 0.1)
})
