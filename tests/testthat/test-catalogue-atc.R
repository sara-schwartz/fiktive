from <- as.Date("2008-01-01")
to <- as.Date("2010-12-31")

test_that("ATCKoodit yields WHO-form 7-character codes including C09AA05", {
  skip_if_not_installed("codeCollection")
  codes <- load_atckoodit_codes()
  expect_true(length(codes) > 100L)
  expect_true(all(nchar(codes) == 7L))
  expect_true("C09AA05" %in% codes)
  expect_false(any(startsWith(codes, "MC")))
})

test_that("missing ATC catalogues SCHEMA GAP and do not sprintf", {
  skip_if_not_installed("codeCollection")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 3)
  old <- options(fiktive.atckoodit_disable = TRUE, fiktive.whocc_atc_disable = TRUE)
  on.exit(options(old), add = TRUE)
  if (exists("reset_whocc_atc_catalogue", mode = "function", inherits = TRUE)) {
    reset_whocc_atc_catalogue()
  }
  err <- tryCatch(
    generate_register("lmdb", pop, schema, from, to, seed = 41),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "^SCHEMA GAP:")
  expect_false(grepl("sprintf\\(", err$message))
})
