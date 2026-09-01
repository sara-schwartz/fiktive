from <- as.Date("2008-01-01")
to <- as.Date("2010-12-31")

test_that("dod is at most one death per person, after birth, columns subset", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 1)
  a <- generate_register("dod", pop, schema, from, to, seed = 31)
  b <- generate_register("dod", pop, schema, from, to, seed = 31)
  expect_equal(a, b)
  schema_names <- vapply(schema$registers$dod$columns, function(col) col$name, character(1))
  expect_true(all(names(a) %in% schema_names))
  expect_equal(anyDuplicated(a$pnr), 0L)
  if (nrow(a)) {
    birth <- pop$foed_dag[match(a$pnr, pop$pnr)]
    expect_true(all(a$doddato >= birth))
    expect_true(all(a$doddato >= from & a$doddato <= to))
    expect_equal(a$alder_haend, {
      year_diff <- as.integer(format(a$doddato, "%Y")) - as.integer(format(birth, "%Y"))
      before <- format(a$doddato, "%m-%d") < format(birth, "%m-%d")
      year_diff - as.integer(before)
    })
  }
})

test_that("empty dod table is valid", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 2)
  empty <- generate_register("dod", pop, schema, "1960-01-01", "1960-12-31", seed = 1)
  expect_equal(nrow(empty), 0L)
  expect_true(all(c("pnr", "doddato") %in% names(empty)))
})

test_that("lmdb events join pnr, year from eksd, atc from WHOCC not sprintf", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 3)
  reset_whocc_atc_catalogue()
  old <- options(
    fiktive.whocc_atc = c("C09AA05", "A10BA02", "N02BE01", "C07AB02", "J01CA04"),
    fiktive.whocc_atc_version = "test-double",
    fiktive.whocc_atc_disable = FALSE
  )
  on.exit({
    options(old)
    reset_whocc_atc_catalogue()
  }, add = TRUE)
  lmdb <- generate_register("lmdb", pop, schema, from, to, seed = 41)
  schema_names <- vapply(schema$registers$lmdb$columns, function(col) col$name, character(1))
  expect_true(all(names(lmdb) %in% schema_names))
  expect_true(all(lmdb$pnr %in% pop$pnr))
  if (nrow(lmdb)) {
    expect_true(all(lmdb$eksd >= from & lmdb$eksd <= to))
    expect_equal(lmdb$year, as.integer(format(lmdb$eksd, "%Y")))
    expect_type(lmdb$atc, "character")
    expect_true(all(nchar(lmdb$atc) == 7L))
    expect_true(all(lmdb$atc %in% c("C09AA05", "A10BA02", "N02BE01", "C07AB02", "J01CA04")))
    expect_equal(lmdb$atc1, substr(lmdb$atc, 1L, 1L))
    expect_type(lmdb$apk, "double")
  }
})

test_that("vnds uses indud_kode lookup, not mixed with successors, empty is valid", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 4)
  vnds <- generate_register("vnds", pop, schema, from, to, seed = 51)
  schema_names <- vapply(schema$registers$vnds$columns, function(col) col$name, character(1))
  expect_true(all(names(vnds) %in% schema_names))
  expect_false("vnds_ind" %in% names(vnds))
  if (nrow(vnds)) {
    expect_true(all(vnds$indud_kode %in% c("I", "U")))
    expect_true(all(vnds$haend_dato >= from & vnds$haend_dato <= to))
    expect_type(vnds$indud_land, "character")
  }
  empty <- generate_register("vnds", pop, schema, "1960-01-01", "1960-12-31", seed = 1)
  expect_equal(nrow(empty), 0L)
})

test_that("vnds_ind is not implemented (do not mix with vnds)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema)
  err <- tryCatch(
    generate_register("vnds_ind", pop, schema, from, to, seed = 1),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "not implemented yet")
  expect_false(grepl("^SCHEMA GAP:", err$message))
})
