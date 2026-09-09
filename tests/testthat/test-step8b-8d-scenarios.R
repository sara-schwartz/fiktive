win_from <- as.Date("2008-01-01")
win_to <- as.Date("2008-12-31")

assoc_cols <- function() {
  tibble::tibble(
    name = c("x", "y", "u"),
    type = c("numeric", "numeric", "numeric"),
    min = c(-2, -2, -2),
    max = c(2, 2, 2)
  )
}

gen_person_custom <- function(pop, schema, scenario, seed, n_hint = NULL) {
  generate_custom_register(
    id = "study",
    one_row_per = "person_reference_date",
    join_keys = "pnr",
    columns = assoc_cols(),
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = seed,
    scenario = scenario,
    cadence = "annual"
  )
}

test_that("scenario=NULL still independence", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 8)
  bef <- generate_register("bef", pop, schema, win_from, win_to, seed = 8)
  expect_equal(get_truth(bef)$scenario_id, "independence")
  expect_equal(get_truth(bef)$expected_naive, 0)
  expect_equal(get_scenario(bef)$id, "independence")
  expect_equal(get_scenario(bef)$associations, list())
})

test_that("association identity recovers beta within tolerance at large n", {
  schema <- fixture_schema()
  beta <- 1.5
  sc <- scenario_association(
    exposure = "study.x",
    outcome = "study.y",
    link = "identity",
    coefficient = beta,
    sigma = 1
  )
  pop <- tiny_pop(schema, n = 5000L, seed = 101)
  tab <- gen_person_custom(pop, schema, sc, seed = 101)
  tr <- get_truth(tab)
  expect_equal(tr$scenario_id, "association")
  expect_equal(tr$expected_naive, beta)
  expect_equal(tr$expected_adjusted, beta)
  expect_identical(tr$naive_estimator, tr$adjusted_estimator)
  expect_equal(tr$causal_effect$value, beta)
  expect_equal(tr$causal_effect$scale, "identity")
  expect_equal(tr$confounders, list())
  expect_equal(tr$biases, list())
  expect_false(anyNA(tab$x))
  expect_false(anyNA(tab$y))
  fit <- stats::lm(y ~ x, data = tab)
  est <- unname(stats::coef(fit)[["x"]])
  expect_equal(est, beta, tolerance = 0.08)
  st <- register_stamps(tab)
  expect_equal(st$fidelity, "clean")
  expect_equal(st$na_rate, 0)
})

test_that("confounding: naive != adjusted; estimates track stamped targets", {
  schema <- fixture_schema()
  beta <- 1.0
  a_ue <- 1.5
  a_uy <- 1.5
  sc <- scenario_confounding(
    exposure = "study.x",
    outcome = "study.y",
    confounder = "study.u",
    link = "identity",
    coefficient = beta,
    affects_exposure = a_ue,
    affects_outcome = a_uy,
    sigma = 1,
    sigma_exposure = 1
  )
  pop <- tiny_pop(schema, n = 5000L, seed = 202)
  tab <- gen_person_custom(pop, schema, sc, seed = 202)
  tr <- get_truth(tab)
  expect_equal(tr$scenario_id, "confounding")
  expect_true(abs(tr$expected_naive - tr$expected_adjusted) > 0.3)
  expect_equal(tr$expected_adjusted, beta)
  expect_true(nzchar(tr$estimand))
  expect_true(nzchar(tr$naive_estimator))
  expect_true(nzchar(tr$adjusted_estimator))
  expect_false(identical(tr$naive_estimator, tr$adjusted_estimator))
  expect_true(length(tr$confounders) == 1L)

  naive_est <- unname(stats::coef(stats::lm(y ~ x, data = tab))[["x"]])
  adj_est <- unname(stats::coef(stats::lm(y ~ x + u, data = tab))[["x"]])
  expect_true(abs(naive_est - tr$expected_naive) < abs(naive_est - tr$expected_adjusted))
  expect_equal(adj_est, beta, tolerance = 0.08)
  expect_equal(naive_est, tr$expected_naive, tolerance = 0.12)
})

test_that("MNAR: stamped naive != adjusted; complete-case biased vs beta", {
  schema <- fixture_schema()
  beta <- 2.0
  sc <- scenario_mnar(
    exposure = "study.x",
    outcome = "study.y",
    link = "identity",
    coefficient = beta,
    mnar_intercept = -0.5,
    mnar_coefficient = 1.2,
    sigma = 1
  )
  pop <- tiny_pop(schema, n = 5000L, seed = 303)
  tab <- gen_person_custom(pop, schema, sc, seed = 303)
  tr <- get_truth(tab)
  expect_equal(tr$scenario_id, "mnar")
  expect_true(abs(tr$expected_naive - tr$expected_adjusted) > 1e-8)
  expect_equal(tr$expected_adjusted, beta)
  expect_true(length(tr$biases) == 1L)
  expect_equal(tr$biases[[1]]$type, "mnar")
  expect_true(anyNA(tab$y))
  expect_false(anyNA(tab$x))
  cc <- stats::na.omit(tab[, c("x", "y")])
  expect_true(nrow(cc) < nrow(tab))
  cc_est <- unname(stats::coef(stats::lm(y ~ x, data = cc))[["x"]])
  # Complete-case should not recover beta tightly under strong MNAR-on-Y.
  expect_true(abs(cc_est - beta) > 0.05)
  # Regression: expected_naive is simulated from this scenario's own
  # mnar_intercept/mnar_coefficient (see simulate_expected_naive_selection()
  # in R/truth.R), not a fixed beta*0.5 placeholder that ignored the actual
  # bias strength -- it should track the real naive fit, not just differ
  # from beta.
  expect_equal(tr$expected_naive, cc_est, tolerance = 0.1)
})

test_that("MNAR expected_naive tracks mnar_coefficient strength, not a fixed offset", {
  schema <- fixture_schema()
  beta <- 2.0
  weak <- scenario_mnar(
    exposure = "study.x", outcome = "study.y", coefficient = beta,
    mnar_intercept = -1, mnar_coefficient = 0.1
  )
  strong <- scenario_mnar(
    exposure = "study.x", outcome = "study.y", coefficient = beta,
    mnar_intercept = -1, mnar_coefficient = 5
  )
  pop <- tiny_pop(schema, n = 4000L, seed = 505)
  tab_weak <- gen_person_custom(pop, schema, weak, seed = 505)
  tab_strong <- gen_person_custom(pop, schema, strong, seed = 505)
  naive_weak <- get_truth(tab_weak)$expected_naive
  naive_strong <- get_truth(tab_strong)$expected_naive
  # Weak missingness should barely move the naive estimate off beta; strong
  # missingness should move it substantially further -- these must differ
  # (the old beta * 0.5 heuristic stamped the same 1.0 for both).
  expect_true(abs(naive_weak - beta) < 0.2)
  expect_true(abs(naive_strong - beta) > abs(naive_weak - beta) + 0.2)
})

test_that("complete-case selection: naive != adjusted as stamped", {
  schema <- fixture_schema()
  beta <- 1.8
  sc <- scenario_complete_case(
    exposure = "study.x",
    outcome = "study.y",
    link = "identity",
    coefficient = beta,
    selection_intercept = 0,
    selection_coefficient = 1.5,
    sigma = 1
  )
  pop <- tiny_pop(schema, n = 5000L, seed = 404)
  tab <- gen_person_custom(pop, schema, sc, seed = 404)
  tr <- get_truth(tab)
  expect_equal(tr$scenario_id, "complete_case")
  expect_true(abs(tr$expected_naive - tr$expected_adjusted) > 1e-8)
  expect_equal(tr$expected_adjusted, beta)
  expect_equal(tr$biases[[1]]$type, "complete_case")
  # Selected sample is smaller than population n (approx; annual → ~n rows).
  expect_true(nrow(tab) < 5000L)
  sel_est <- unname(stats::coef(stats::lm(y ~ x, data = tab))[["x"]])
  expect_true(abs(sel_est - beta) > 0.03)
})

test_that("coefficients not required in schema / custom column CSV", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 2000L, seed = 505)
  cols <- tibble::tibble(
    name = c("x", "y"),
    type = c("numeric", "numeric"),
    min = c(-2, -2),
    max = c(2, 2),
    coefficient = c(99, 99) # ignored — must not enter DGP
  )
  sc <- scenario_association(
    exposure = "study.x",
    outcome = "study.y",
    link = "identity",
    coefficient = 0.75,
    sigma = 0.5
  )
  tab <- generate_custom_register(
    id = "study",
    one_row_per = "person_reference_date",
    columns = cols,
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 505,
    scenario = sc,
    cadence = "annual"
  )
  expect_false("coefficient" %in% names(tab))
  # CSV coefficient column must not drive the DGP (scenario beta wins).
  est <- unname(stats::coef(stats::lm(y ~ x, data = tab))[["x"]])
  expect_equal(est, 0.75, tolerance = 0.1)
  expect_true(abs(est - 99) > 50)
})

test_that("fidelity clean default under scenario; messy does not rewrite truth", {
  schema <- fixture_schema()
  beta <- 1.1
  sc <- scenario_association(
    exposure = "study.x",
    outcome = "study.y",
    link = "identity",
    coefficient = beta
  )
  pop <- tiny_pop(schema, n = 80L, seed = 606)
  clean <- gen_person_custom(pop, schema, sc, seed = 606)
  expect_equal(register_stamps(clean)$fidelity, "clean")
  expect_equal(get_truth(clean)$expected_naive, beta)

  messy <- generate_custom_register(
    id = "study",
    one_row_per = "person_reference_date",
    columns = assoc_cols(),
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 606,
    scenario = sc,
    cadence = "annual",
    fidelity = "messy"
  )
  # Truth still stamps the scenario coefficient (messy is pipeline stress).
  expect_equal(get_truth(messy)$expected_adjusted, beta)
  expect_equal(register_stamps(messy)$fidelity, "messy")
})

test_that("logit and log links produce plausible outcomes", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 800L, seed = 707)
  sc_logit <- scenario_association(
    exposure = "study.x",
    outcome = "study.y",
    link = "logit",
    coefficient = 1.2,
    intercept = -0.2
  )
  tab_l <- gen_person_custom(pop, schema, sc_logit, seed = 707)
  expect_true(all(tab_l$y %in% c(0L, 1L)))
  expect_equal(get_truth(tab_l)$causal_effect$scale, "logit")

  sc_log <- scenario_association(
    exposure = "study.x",
    outcome = "study.y",
    link = "log",
    coefficient = 0.4,
    intercept = 0.1
  )
  tab_g <- gen_person_custom(pop, schema, sc_log, seed = 708)
  expect_true(all(tab_g$y > 0))
  expect_equal(get_truth(tab_g)$causal_effect$scale, "log")
})

test_that("cross-register association aligns on pnr even when a third batched register has no pnr", {
  # Regression: join_key_for_tables() used to be computed once over the
  # WHOLE batch, so a third register with no pnr (e.g. lpr_diag, keyed on
  # recnum) silently degraded the join key for every association in the
  # batch down to whatever column *is* shared by all tables (here: year) -
  # misaligning exposure/outcome by year instead of by person and silently
  # corrupting the planted association instead of raising an error.
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 1)
  sc <- scenario_association(
    exposure = "bef.alder", outcome = "udda.hfaudd",
    link = "identity", coefficient = 2
  )
  out <- generate_registers(
    registers = c("bef", "udda", "lpr_diag"),
    population = pop, schema = schema,
    from = win_from, to = win_to, seed = 1, scenario = sc
  )
  bef1 <- out$bef[!duplicated(out$bef$pnr), c("pnr", "alder")]
  udda1 <- out$udda[!duplicated(out$udda$pnr), c("pnr", "hfaudd")]
  m <- merge(bef1, udda1, by = "pnr")
  beta <- coef(lm(hfaudd ~ alder, data = m))[["alder"]]
  expect_equal(beta, 2, tolerance = 0.1)
})

test_that("generate_registers attaches scenario truth on the list", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 15L, seed = 809)
  sc <- scenario_independence()
  tabs <- generate_registers(
    registers = c("bef", "udda"),
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 809,
    scenario = sc
  )
  expect_equal(get_truth(tabs)$scenario_id, "independence")
  expect_equal(get_truth(tabs$bef)$scenario_id, "independence")
})
