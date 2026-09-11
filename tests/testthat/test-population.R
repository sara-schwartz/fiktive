test_that("background population has stable pnr, foed_dag, koen", {
  schema <- fixture_schema()
  pop <- generate_background_population(12, seed = 7, schema = schema)
  expect_named(pop, c("pnr", "foed_dag", "koen"))
  expect_type(pop$pnr, "character")
  expect_s3_class(pop$foed_dag, "Date")
  expect_type(pop$koen, "integer")
  expect_true(all(pop$koen %in% c(1L, 2L, 9L)))
  expect_equal(length(unique(pop$pnr)), nrow(pop))
  expect_false(any(grepl("^[0-9]{6}-", pop$pnr)))
})

test_that("same seed yields identical persons", {
  schema <- fixture_schema()
  a <- generate_background_population(12, seed = 11, schema = schema)
  b <- generate_background_population(12, seed = 11, schema = schema)
  expect_equal(a, b)
})

test_that("schema = NULL is a SCHEMA GAP, not silent 1/2", {
  expect_error(
    generate_background_population(5, seed = 1, schema = NULL),
    "^SCHEMA GAP:"
  )
})

test_that("missing koen code system is a SCHEMA GAP", {
  schema <- fixture_schema()
  schema$code_systems[["koen"]] <- NULL
  expect_error(
    generate_background_population(5, seed = 1, schema = schema),
    "^SCHEMA GAP:"
  )
})

test_that("age_min/age_max produce birth dates within the requested age window", {
  schema <- fixture_schema()
  ref <- as.Date("2026-09-10")
  pop <- generate_background_population(
    200,
    seed = 3,
    schema = schema,
    age_min = 65,
    age_max = 80,
    reference_date = ref
  )
  age <- floor(as.numeric(difftime(ref, pop$foed_dag, units = "days")) / 365.25)
  expect_true(all(age >= 65 & age <= 80))
})

test_that("age_min/age_max cannot be combined with birth_from/birth_to", {
  schema <- fixture_schema()
  expect_error(
    generate_background_population(
      5,
      seed = 1,
      schema = schema,
      birth_from = as.Date("2000-01-01"),
      age_min = 10
    ),
    "not both"
  )
})

test_that("age_max must be >= age_min", {
  schema <- fixture_schema()
  expect_error(
    generate_background_population(5, seed = 1, schema = schema, age_min = 50, age_max = 10),
    "age_max"
  )
})

test_that("default birth window is unchanged when no age/birth args are given", {
  schema <- fixture_schema()
  a <- generate_background_population(30, seed = 5, schema = schema)
  expect_true(all(a$foed_dag >= as.Date("1940-01-01") & a$foed_dag <= as.Date("2007-12-31")))
})
