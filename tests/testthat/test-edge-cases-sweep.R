# Section 5 audit: edge cases that happened to get covered only for the
# specific register that needed them during development, not confirmed
# systematically everywhere. Locking in current (correct) behavior with
# explicit regression tests: empty population, a population of 1,
# from == to, a to before any population member's birth, fidelity =
# "messy" combined with every constraints= value, and scenario =
# "association" combined with constraints=.

test_that("n = 0 population errors clearly rather than crashing downstream", {
  schema <- fixture_schema()
  err <- tryCatch(
    generate_background_population(n = 0L, seed = 1, schema = schema),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "positive integer", ignore.case = TRUE)
})

test_that("a population of 1 generates without error across grains", {
  schema <- fixture_schema()
  pop <- generate_background_population(n = 1L, seed = 1, schema = schema)
  expect_equal(nrow(pop), 1L)

  bef <- generate_register("bef", pop, schema, as.Date("2008-01-01"), as.Date("2009-12-31"), seed = 1)
  expect_true(nrow(bef) >= 0L)

  dod <- generate_register("dod", pop, schema, as.Date("2008-01-01"), as.Date("2009-12-31"), seed = 1)
  expect_true(nrow(dod) >= 0L)

  dch <- generate_register("dch", pop, schema, as.Date("1993-12-01"), as.Date("1997-05-31"), seed = 1)
  expect_true(nrow(dch) >= 0L)
})

test_that("from == to yields 0 rows off-boundary and real rows on a valid boundary date, across grains", {
  schema <- fixture_schema()
  pop <- generate_background_population(n = 30L, seed = 1, schema = schema)

  # bef (person_reference_date, quarterly): an arbitrary mid-quarter day has
  # no snapshot date in [from, to] -- 0 rows, not an error.
  off <- generate_register("bef", pop, schema, as.Date("2008-06-01"), as.Date("2008-06-01"), seed = 1)
  expect_equal(nrow(off), 0L)
  # A real quarter-end date is itself the snapshot date -- rows for everyone alive.
  on_boundary <- generate_register("bef", pop, schema, as.Date("2008-06-30"), as.Date("2008-06-30"), seed = 1)
  expect_true(nrow(on_boundary) > 0L)

  # dod (event_from_person): from == to is a valid one-day window.
  event <- generate_register("dod", pop, schema, as.Date("2008-06-30"), as.Date("2008-06-30"), seed = 1)
  expect_true(nrow(event) >= 0L)

  # dch (person, staggered recruitment): from == to inside the real
  # recruitment window is a valid one-day window too.
  person <- generate_register("dch", pop, schema, as.Date("1994-03-01"), as.Date("1994-03-01"), seed = 1)
  expect_true(nrow(person) >= 0L)
})

test_that("a `to` before any population member's birth yields 0 rows, not an error", {
  schema <- fixture_schema()
  pop <- generate_background_population(
    n = 30L, seed = 1, schema = schema,
    birth_from = as.Date("1950-01-01"), birth_to = as.Date("2000-12-31")
  )
  expect_true(all(pop$foed_dag > as.Date("1800-06-01")))

  bef <- generate_register("bef", pop, schema, as.Date("1800-01-01"), as.Date("1800-06-01"), seed = 1)
  expect_equal(nrow(bef), 0L)

  dch <- generate_register("dch", pop, schema, as.Date("1800-01-01"), as.Date("1800-06-01"), seed = 1)
  expect_equal(nrow(dch), 0L)
})

test_that("fidelity = 'messy' combined with every known constraint value still works and still holds the constraint", {
  schema <- fixture_schema()
  pop <- generate_background_population(n = 200L, seed = 2, schema = schema)
  from <- as.Date("2008-01-01")
  to <- as.Date("2012-12-31")

  expect_setequal(
    fiktive:::.KNOWN_CONSTRAINTS,
    c("valid_diagnosis_sex_age", "weighted_municipality", "weighted_lprindberetningssystem")
  )

  # weighted_municipality: bef's kom should still only ever be a real kom code.
  bef <- generate_register(
    "bef", pop, schema, from, to, seed = 2,
    fidelity = "messy", constraints = "weighted_municipality"
  )
  expect_true(nrow(bef) > 0L)
  kom_cs <- schema$code_systems[["kom"]]
  valid_kom <- fiktive:::lookup_keys(kom_cs)
  expect_true(all(bef$kom[!is.na(bef$kom)] %in% valid_kom))

  # valid_diagnosis_sex_age + weighted_lprindberetningssystem together, on
  # the parent/child pair that needs both, still messy.
  out <- generate_registers(
    c("lpr_adm", "lpr_diag"),
    population = pop, schema = schema, from = from, to = to, seed = 2,
    fidelity = "messy",
    constraints = c("valid_diagnosis_sex_age", "weighted_lprindberetningssystem")
  )
  expect_true(nrow(out$lpr_adm) > 0L)
  skip_if(nrow(out$lpr_diag) == 0L, "no diagnosis rows drawn for this fixture/seed")
  koen <- pop$koen[match(out$lpr_adm$pnr[match(out$lpr_diag$recnum, out$lpr_adm$recnum)], pop$pnr)]
  o_on_male <- startsWith(out$lpr_diag$c_diag, "DO") & koen == 1L
  expect_false(any(o_on_male, na.rm = TRUE))
})

test_that("scenario = association combined with constraints= still plants the right truth", {
  schema <- fixture_schema()
  pop <- generate_background_population(n = 200L, seed = 3, schema = schema)
  sc <- scenario_association(exposure = "bef.antboernf", outcome = "bef.alder", coefficient = 0.5)

  bef <- generate_register(
    "bef", pop, schema, as.Date("2008-01-01"), as.Date("2009-12-31"), seed = 3,
    scenario = sc, constraints = "weighted_municipality"
  )
  expect_true(nrow(bef) > 0L)
  kom_cs <- schema$code_systems[["kom"]]
  valid_kom <- fiktive:::lookup_keys(kom_cs)
  expect_true(all(bef$kom[!is.na(bef$kom)] %in% valid_kom))

  truth <- get_truth(bef)
  expect_equal(truth$associations[[1]]$exposure, "bef.antboernf")
  expect_equal(truth$associations[[1]]$outcome, "bef.alder")
  expect_equal(truth$associations[[1]]$coefficient, 0.5)
})
