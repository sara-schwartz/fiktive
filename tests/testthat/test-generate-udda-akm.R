from <- as.Date("2008-01-01")
to <- as.Date("2010-12-31")

test_that("udda is annual person x year, persistent, columns subset of schema", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 1)
  a <- generate_register("udda", pop, schema, from, to, seed = 21)
  b <- generate_register("udda", pop, schema, from, to, seed = 21)
  expect_equal(a, b)
  schema_names <- vapply(schema$registers$udda$columns, function(col) col$name, character(1))
  expect_true(all(names(a) %in% schema_names))
  expect_equal(anyDuplicated(a[, c("pnr", "year")]), 0L)
  expect_equal(sort(unique(a$year)), c(2008L, 2009L, 2010L))
  expect_type(a$hfaudd, "character")
  counts <- as.integer(table(a$pnr))
  expect_true(all(counts == 3L))
})

test_that("akm is annual, alder_ult_ink matches 31 Dec, socio13 is typed noise", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 2)
  akm <- generate_register("akm", pop, schema, from, to, seed = 22)
  schema_names <- vapply(schema$registers$akm$columns, function(col) col$name, character(1))
  expect_true(all(names(akm) %in% schema_names))
  expect_equal(anyDuplicated(akm[, c("pnr", "year")]), 0L)
  expect_equal(akm$year, as.integer(akm$year))
  snap <- as.Date(paste0(akm$year, "-12-31"))
  birth <- pop$foed_dag[match(akm$pnr, pop$pnr)]
  year_diff <- as.integer(format(snap, "%Y")) - as.integer(format(birth, "%Y"))
  before <- format(snap, "%m-%d") < format(birth, "%m-%d")
  expect_equal(akm$alder_ult_ink, year_diff - as.integer(before))
  expect_type(akm$socio13, "integer")
  expect_true(all(is.na(akm$socio_gl)))
  expect_false(all(is.na(akm$socio13)))
})

test_that("no annual snapshot before birth", {
  schema <- fixture_schema()
  pop <- tibble::tibble(
    pnr = "00000001",
    foed_dag = as.Date("2009-06-01"),
    koen = 1L
  )
  udda <- generate_register("udda", pop, schema, from, to, seed = 3)
  expect_false(2008L %in% udda$year)
  expect_true(all(udda$year >= 2009L))
})
