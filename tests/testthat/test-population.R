test_that("background population has stable pnr, foed_dag, koen", {
  schema <- fixture_schema()
  pop <- generate_background_population(12, seed = 7, schema = schema)
  expect_named(pop, c("pnr", "foed_dag", "koen"))
  expect_type(pop$pnr, "character")
  expect_s3_class(pop$foed_dag, "Date")
  expect_type(pop$koen, "integer")
  expect_true(all(pop$koen %in% c(1L, 2L)))
  expect_equal(length(unique(pop$pnr)), nrow(pop))
  expect_false(any(grepl("^[0-9]{6}-", pop$pnr)))
})

test_that("same seed yields identical persons", {
  schema <- fixture_schema()
  a <- generate_background_population(12, seed = 11, schema = schema)
  b <- generate_background_population(12, seed = 11, schema = schema)
  expect_equal(a, b)
})
