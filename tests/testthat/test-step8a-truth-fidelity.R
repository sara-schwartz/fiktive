win_from <- as.Date("2008-01-01")
win_to <- as.Date("2009-12-31")

test_that("independence always returns fiktive_truth with expected association 0", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 42)
  bef <- generate_register("bef", pop, schema, win_from, win_to, seed = 42)
  tr <- get_truth(bef)
  expect_s3_class(tr, "fiktive_truth")
  expect_equal(tr$scenario_id, "independence")
  expect_equal(tr$causal_effect, 0)
  expect_equal(tr$expected_naive, 0)
  expect_equal(tr$expected_adjusted, 0)
  expect_true(is.character(tr$estimand) && nzchar(tr$estimand))
  expect_true(is.character(tr$naive_estimator) && nzchar(tr$naive_estimator))
  expect_true(is.character(tr$adjusted_estimator) && nzchar(tr$adjusted_estimator))
  expect_equal(tr$associations, list())
  expect_equal(tr$confounders, list())
  expect_equal(tr$biases, list())
  sc <- get_scenario(bef)
  expect_s3_class(sc, "fiktive_scenario")
  expect_equal(sc$id, "independence")
  expect_equal(sc$associations, list())
  expect_equal(sc$backend, "core")
})

test_that("generate_registers and custom attach the same independence truth", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 12L, seed = 43)
  tabs <- generate_registers(
    registers = c("bef", "udda"),
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 43
  )
  expect_equal(get_truth(tabs)$expected_naive, 0)
  expect_equal(get_truth(tabs$bef)$scenario_id, "independence")

  cols <- tibble::tibble(
    name = c("score", "grp"),
    type = c("numeric", "character"),
    min = c(0, NA),
    max = c(10, NA),
    values = c(NA_character_, "A|B|C")
  )
  ext <- generate_custom_register(
    id = "ext_score",
    one_row_per = "person_reference_date",
    columns = cols,
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 43,
    cadence = "annual"
  )
  expect_equal(get_truth(ext)$expected_adjusted, 0)
})

test_that("canned association under independence is null within MC error", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 80L, seed = 44)
  bef <- generate_register("bef", pop, schema, win_from, win_to, seed = 44)
  # Prefer two noisy value/code columns that are not derived ages.
  if ("antboernf" %in% names(bef) && "familie_type" %in% names(bef)) {
    a <- as.numeric(bef$antboernf)
    b <- as.integer(factor(as.character(bef$familie_type)))
    ok <- is.finite(a) & is.finite(b)
    expect_true(sum(ok) > 30L)
    ct <- suppressWarnings(cor.test(a[ok], b[ok]))
    # Independence: association near 0; generous MC band.
    expect_true(abs(ct$estimate) < 0.35)
  }
})

test_that("fidelity clean defaults rates 0 and stamps preset", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 10L, seed = 45)
  bef <- generate_register("bef", pop, schema, win_from, win_to, seed = 45)
  st <- register_stamps(bef)
  expect_equal(st$fidelity, "clean")
  expect_equal(st$na_rate, 0)
  expect_equal(st$outlier_rate, 0)
  expect_false(anyNA(bef$pnr))
  expect_false(anyNA(bef$alder))
})

test_that("fidelity messy stamps preset and applies NA off keys/derived", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 46)
  bef <- generate_register(
    "bef", pop, schema, win_from, win_to,
    seed = 46, fidelity = "messy"
  )
  st <- register_stamps(bef)
  expect_equal(st$fidelity, "messy")
  expect_equal(st$na_rate, 0.03)
  expect_equal(st$outlier_rate, 0.01)
  # Join keys + derived stay complete.
  expect_false(anyNA(bef$pnr))
  expect_false(anyNA(bef$alder))
  expect_false(anyNA(bef$familie_id))
  expect_false(anyNA(bef$foed_dag))
  expect_false(anyNA(bef$koen))
  # Some eligible non-key column should see NA under messy rates on a large table.
  eligible <- setdiff(
    names(bef),
    c("pnr", "familie_id", "koen", "foed_dag", "referencetid", "year", "alder", "fdato")
  )
  na_counts <- vapply(eligible, function(nm) sum(is.na(bef[[nm]])), integer(1))
  expect_true(sum(na_counts) > 0L)
})

test_that("na_rate / outlier_rate overrides win and are stamped", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 30L, seed = 47)
  bef <- generate_register(
    "bef", pop, schema, win_from, win_to,
    seed = 47, fidelity = "clean", na_rate = 0.2, outlier_rate = 0.05
  )
  st <- register_stamps(bef)
  expect_equal(st$fidelity, "clean")
  expect_equal(st$na_rate, 0.2)
  expect_equal(st$outlier_rate, 0.05)
  expect_false(anyNA(bef$pnr))
  expect_false(anyNA(bef$alder))
  expect_true(sum(is.na(bef$antboernf)) > 0L || sum(is.na(bef$opr_land)) > 0L)
})

test_that("fidelity eligibility helpers protect keys derived presence", {
  schema <- fixture_schema()
  spec <- schema$registers$bef
  pop <- tiny_pop(schema, n = 8L, seed = 48)
  bef <- generate_register("bef", pop, schema, win_from, win_to, seed = 48)
  na_el <- fidelity_na_eligible(bef, spec)
  expect_false("pnr" %in% na_el)
  expect_false("alder" %in% na_el)
  expect_false("familie_id" %in% na_el)
  expect_true("antboernf" %in% na_el)

  # Synthetic presence column meta.
  spec2 <- spec
  spec2$columns <- c(
    spec$columns,
    list(list(id = "present_flag", name = "present_flag", type = "logical", role = "presence"))
  )
  bef$present_flag <- TRUE
  expect_false("present_flag" %in% fidelity_na_eligible(bef, spec2))

  out_el <- fidelity_outlier_eligible(bef, spec)
  expect_true("antboernf" %in% out_el)
  # code_system columns must not get inventing outliers
  expect_false("koen" %in% out_el)
  expect_false("kom" %in% out_el)
})

test_that("write_register sidecar includes fidelity stamps", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 6L, seed = 49)
  bef <- generate_register(
    "bef", pop, schema, win_from, win_to,
    seed = 49, fidelity = "messy"
  )
  tmp <- tempfile("fiktive-fid")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp)
  path <- write_register(bef, file.path(tmp, "bef"))
  meta <- yaml::read_yaml(paste0(path, ".meta.yaml"))
  expect_equal(meta$fidelity, "messy")
  expect_equal(meta$na_rate, 0.03)
  expect_equal(meta$outlier_rate, 0.01)
})

test_that("invalid fidelity rates error", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 4L, seed = 50)
  expect_error(
    generate_register("bef", pop, schema, win_from, win_to, na_rate = 2),
    "na_rate"
  )
  expect_error(
    generate_register("bef", pop, schema, win_from, win_to, fidelity = "nope"),
    "clean|messy"
  )
})
