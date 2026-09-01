from <- as.Date("2008-01-01")
to <- as.Date("2009-12-31")

test_that("same seed yields identical BEF data", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 1)
  a <- generate_register("bef", pop, schema, from, to, seed = 42)
  b <- generate_register("bef", pop, schema, from, to, seed = 42)
  expect_equal(a, b)
})

test_that("pnr maps to stable foed_dag and koen across snapshots and persons table", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 2)
  bef <- generate_register("bef", pop, schema, from, to, seed = 2)
  joined <- merge(bef[, c("pnr", "foed_dag", "koen")], pop, by = "pnr", suffixes = c("", "_pop"))
  expect_equal(joined$foed_dag, joined$foed_dag_pop)
  expect_equal(joined$koen, joined$koen_pop)
  by_pnr <- split(bef, bef$pnr)
  for (part in by_pnr) {
    expect_equal(length(unique(part$foed_dag)), 1L)
    expect_equal(length(unique(part$koen)), 1L)
  }
})

test_that("alder matches foed_dag + referencetid", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 3)
  bef <- generate_register("bef", pop, schema, from, to, seed = 3)
  year_diff <- as.integer(format(bef$referencetid, "%Y")) - as.integer(format(bef$foed_dag, "%Y"))
  before <- (as.integer(format(bef$referencetid, "%m")) < as.integer(format(bef$foed_dag, "%m"))) |
    (as.integer(format(bef$referencetid, "%m")) == as.integer(format(bef$foed_dag, "%m")) &
       as.integer(format(bef$referencetid, "%d")) < as.integer(format(bef$foed_dag, "%d")))
  expect_equal(bef$alder, year_diff - as.integer(before))
})

test_that("generated columns are a subset of schema column names for bef", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 4)
  bef <- generate_register("bef", pop, schema, from, to, seed = 4)
  schema_names <- vapply(schema$registers$bef$columns, function(col) col$name, character(1))
  expect_true(all(names(bef) %in% schema_names))
})

test_that("grain is unique (pnr, referencetid) with quarterly snapshots since 2008", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 5)
  bef <- generate_register("bef", pop, schema, from, to, seed = 5)
  expect_equal(anyDuplicated(bef[, c("pnr", "referencetid")]), 0L)
  expected <- as.Date(c(
    "2008-03-31", "2008-06-30", "2008-09-30", "2008-12-31",
    "2009-03-31", "2009-06-30", "2009-09-30", "2009-12-31"
  ))
  expect_equal(sort(unique(bef$referencetid)), expected)
  mons <- as.integer(format(bef$referencetid, "%m"))
  days <- as.integer(format(bef$referencetid, "%d"))
  expect_true(all(mons %in% c(3L, 6L, 9L, 12L)))
  expect_true(all(days %in% c(30L, 31L)))
})

test_that("pre-2008 window is December-only", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 5)
  bef <- generate_register("bef", pop, schema, as.Date("2007-01-01"), as.Date("2007-12-31"), seed = 5)
  expect_equal(sort(unique(bef$referencetid)), as.Date("2007-12-31"))
})

test_that("no row has referencetid before foed_dag", {
  schema <- fixture_schema()
  pop <- generate_background_population(
    12,
    seed = 6,
    schema = schema,
    birth_from = as.Date("2007-06-01"),
    birth_to = as.Date("2009-06-01")
  )
  bef <- generate_register("bef", pop, schema, from, to, seed = 6)
  expect_true(nrow(bef) > 0)
  expect_true(all(bef$referencetid >= bef$foed_dag))
})

test_that("people persist across 2009 snapshots (not a yearly random pool)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 8)
  bef <- generate_register("bef", pop, schema, from, to, seed = 8)
  y2009 <- bef[format(bef$referencetid, "%Y") == "2009", ]
  snaps <- sort(unique(y2009$referencetid))
  expect_equal(length(snaps), 4L)
  first <- snaps[[1]]
  present_first <- unique(y2009$pnr[y2009$referencetid == first])
  born_by_all <- pop$pnr[pop$foed_dag <= snaps[[length(snaps)]]]
  expect_true(length(present_first) > 0)
  for (pnr in present_first) {
    birth <- pop$foed_dag[pop$pnr == pnr][[1]]
    later <- snaps[snaps >= birth]
    got <- sort(unique(y2009$referencetid[y2009$pnr == pnr]))
    expect_equal(got, later)
  }
})

test_that("year is derived from referencetid and civst is not D", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 9)
  bef <- generate_register("bef", pop, schema, from, to, seed = 9)
  expect_equal(bef$year, as.integer(format(bef$referencetid, "%Y")))
  expect_false(any(bef$civst == "D", na.rm = TRUE))
  expect_true(all(bef$civst %in% c("U", "G", "F", "E", "P", "O", "L", "9")))
  expect_type(bef$reg, "character")
  expect_true(all(bef$reg %in% c("0", "81", "82", "83", "84", "85")))
  expect_true(all(nchar(bef$kom) == 3L))
  expect_true(all(is.na(bef$van_vtil)))
  expect_false(all(is.na(bef$foerste_indvandring)))
})

test_that("get_truth stub has empty slots", {
  tr <- get_truth()
  expect_named(
    tr,
    c("estimand", "naive_estimator", "adjusted_estimator", "expected_naive", "expected_adjusted")
  )
  expect_true(all(vapply(tr, is.null, logical(1))))
})
