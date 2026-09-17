# dodsaars/dodsaasg/dodsaarsager, sysi/sssy, vnds_hist/vnds_ind/vnds_ud,
# t_psyk_adm/t_psyk_diag -- registers-guide always documented these (grain,
# join keys, columns), but fiktive only just added them to the
# .IMPLEMENTED_* whitelists in R/generate.R. No new generic machinery was
# needed: pnr/recnum mapping, coverage clipping, and code_system lookups
# already worked for any register once whitelisted.

schema_names <- function(schema, register) {
  vapply(schema$registers[[register]]$columns, function(col) col$name, character(1))
}

test_that("dodsaarsager (current cause-of-death) is one row per pnr subset, reproducible", {
  skip_if_not_installed("codeCollection")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 21)
  a <- generate_register("dodsaarsager", pop, schema, as.Date("2022-01-01"), as.Date("2023-12-31"), seed = 1)
  b <- generate_register("dodsaarsager", pop, schema, as.Date("2022-01-01"), as.Date("2023-12-31"), seed = 1)
  expect_equal(a, b)
  expect_true(all(names(a) %in% schema_names(schema, "dodsaarsager")))
  expect_true(all(a$pnr %in% pop$pnr))
  if (nrow(a)) {
    expect_true(all(a$doedsdato >= as.Date("2022-01-01") & a$doedsdato <= as.Date("2023-12-31")))
  }
})

test_that("dodsaasg (2002-2022 cause of death) generates within its own coverage", {
  skip_if_not_installed("codeCollection")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 22)
  a <- generate_register("dodsaasg", pop, schema, as.Date("2005-01-01"), as.Date("2007-12-31"), seed = 1)
  expect_true(all(names(a) %in% schema_names(schema, "dodsaasg")))
  expect_true(all(a$pnr %in% pop$pnr))
})

test_that("dodsaars ICD-8 pre-1993 SCHEMA GAPs (no invented list), like lpr_diag", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 23)
  err <- tryCatch(
    generate_register("dodsaars", pop, schema, as.Date("1975-01-01"), as.Date("1985-12-31"), seed = 1),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "^SCHEMA GAP:")
  expect_match(err$message, "ICD-8|icd8", ignore.case = TRUE)
})

test_that("dodsaars generates within its post-1993 coverage", {
  skip_if_not_installed("codeCollection")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 24)
  a <- generate_register("dodsaars", pop, schema, as.Date("1994-01-01"), as.Date("1998-12-31"), seed = 1)
  expect_true(all(names(a) %in% schema_names(schema, "dodsaars")))
  expect_true(all(a$pnr %in% pop$pnr))
})

test_that("sysi (deprecated) and sssy (its continuation) both generate, never mixed", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 25)
  # sikrekom (code_system kom) is pre-2007-reform here -- suppress the
  # unrelated municipal-reform warning (see test-generate-bef.R), not what
  # this test is about.
  sysi <- suppressWarnings(
    generate_register("sysi", pop, schema, as.Date("1995-01-01"), as.Date("1997-12-31"), seed = 1)
  )
  sssy <- generate_register("sssy", pop, schema, as.Date("2010-01-01"), as.Date("2012-12-31"), seed = 1)
  expect_true(all(names(sysi) %in% schema_names(schema, "sysi")))
  expect_true(all(names(sssy) %in% schema_names(schema, "sssy")))
  expect_true(all(sysi$pnr %in% pop$pnr))
  expect_true(all(sssy$pnr %in% pop$pnr))
  expect_false("koenimp" %in% names(sysi))
  expect_false("afrper" %in% names(sssy))
  if (nrow(sssy)) {
    expect_true(all(sssy$behandlingsdato >= as.Date("2010-01-01") & sssy$behandlingsdato <= as.Date("2012-12-31")))
  }
})

test_that("vnds_hist/vnds_ind/vnds_ud each generate and are never mixed with vnds", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 26)
  hist <- generate_register("vnds_hist", pop, schema, as.Date("1980-01-01"), as.Date("1985-12-31"), seed = 1)
  ind <- generate_register("vnds_ind", pop, schema, as.Date("2010-01-01"), as.Date("2012-12-31"), seed = 1)
  ud <- generate_register("vnds_ud", pop, schema, as.Date("2010-01-01"), as.Date("2012-12-31"), seed = 1)
  expect_true(all(names(hist) %in% schema_names(schema, "vnds_hist")))
  expect_true(all(names(ind) %in% schema_names(schema, "vnds_ind")))
  expect_true(all(names(ud) %in% schema_names(schema, "vnds_ud")))
  expect_true(all(hist$pnr %in% pop$pnr))
  expect_true(all(ind$pnr %in% pop$pnr))
  expect_true(all(ud$pnr %in% pop$pnr))
  expect_false("indud_kode" %in% names(ind))
  if (nrow(ind)) {
    expect_true(all(ind$koen %in% pop$koen[match(ind$pnr, pop$pnr)]))
  }
})

test_that("t_psyk_diag recnum subsets t_psyk_adm at the same seed (like lpr_diag/lpr_adm)", {
  skip_if_not_installed("sksr")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 27)
  adm <- generate_register("t_psyk_adm", pop, schema, as.Date("1995-01-01"), as.Date("2019-12-31"), seed = 2)
  diag <- generate_register("t_psyk_diag", pop, schema, as.Date("1995-01-01"), as.Date("2019-12-31"), seed = 2)
  expect_true(nrow(adm) > 0L)
  expect_equal(anyDuplicated(adm$recnum), 0L)
  expect_true(all(diag$recnum %in% adm$recnum))
  expect_false("pnr" %in% names(diag))
  expect_true(all(startsWith(diag$c_diag, "D")))
})

test_that("t_psyk_adm/t_psyk_diag are separate from lpr_adm/lpr_diag (STEP note)", {
  expect_true("t_psyk_adm" %in% fiktive:::.IMPLEMENTED_PARENTS)
  expect_true("t_psyk_diag" %in% fiktive:::.IMPLEMENTED_EXPAND)
  expect_identical(fiktive:::lpr_parent_id("t_psyk_diag"), "t_psyk_adm")
})
