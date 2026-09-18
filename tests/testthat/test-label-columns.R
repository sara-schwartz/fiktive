test_that("label_columns() attaches label attributes without renaming columns", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 1)
  bef <- generate_register("bef", pop, schema, as.Date("2010-01-01"), as.Date("2010-12-31"), seed = 1)
  before_names <- names(bef)
  out <- label_columns(bef, schema, "bef")
  expect_identical(names(out), before_names)
  expect_equal(attr(out$koen, "label"), "Sex")
})

test_that("label_columns() falls back to the other language when one is missing", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 2)
  kj <- generate_register("kkh_journal", pop, schema, as.Date("1993-12-01"), as.Date("1997-05-31"), seed = 2)
  out_en <- label_columns(kj, schema, "kkh_journal", lang = "en")
  out_da <- label_columns(kj, schema, "kkh_journal", lang = "da")
  expect_equal(attr(out_en$center, "label"), "Study center")
  expect_equal(attr(out_da$center, "label"), "Center")
  # pnr has no label in either language on kkh_journal -- must stay unlabeled,
  # not error and not silently invent one.
  expect_null(attr(out_en$pnr, "label"))
})

test_that("label_columns() skips a column fiktive has no label for, and an unknown column in data", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 3)
  bef <- generate_register("bef", pop, schema, as.Date("2010-01-01"), as.Date("2010-12-31"), seed = 3)
  bef$made_up_col <- 1
  out <- label_columns(bef, schema, "bef")
  expect_null(attr(out$made_up_col, "label"))
})
