from <- as.Date("2008-01-01")
to <- as.Date("2010-12-31")

# TEST DOUBLE only - a handful of well-known WHO ATC examples used to exercise
# sampling/prefixes. Not the WHOCC index, not the package source of truth.
.test_whocc_codes <- c("C09AA05", "A10BA02", "N02BE01", "C07AB02", "J01CA04")

with_whocc_test_double <- function(code) {
  reset_whocc_atc_catalogue()
  old <- options(
    fiktive.whocc_atc = .test_whocc_codes,
    fiktive.whocc_atc_version = "test-double",
    fiktive.whocc_atc_disable = FALSE
  )
  on.exit({
    options(old)
    reset_whocc_atc_catalogue()
  }, add = TRUE)
  force(code)
}

with_whocc_disabled <- function(code) {
  reset_whocc_atc_catalogue()
  old <- options(
    fiktive.whocc_atc = NULL,
    fiktive.whocc_atc_disable = TRUE
  )
  old_env <- Sys.getenv("FIKTIVE_WHOCC_ATC", unset = NA)
  old_url <- Sys.getenv("FIKTIVE_WHOCC_ATC_URL", unset = NA)
  Sys.unsetenv("FIKTIVE_WHOCC_ATC")
  Sys.unsetenv("FIKTIVE_WHOCC_ATC_URL")
  on.exit({
    options(old)
    if (!is.na(old_env)) Sys.setenv(FIKTIVE_WHOCC_ATC = old_env) else Sys.unsetenv("FIKTIVE_WHOCC_ATC")
    if (!is.na(old_url)) Sys.setenv(FIKTIVE_WHOCC_ATC_URL = old_url) else Sys.unsetenv("FIKTIVE_WHOCC_ATC_URL")
    reset_whocc_atc_catalogue()
  }, add = TRUE)
  force(code)
}

live_whocc_catalogue <- function() {
  reset_whocc_atc_catalogue()
  old <- options(fiktive.whocc_atc = NULL, fiktive.whocc_atc_disable = FALSE)
  on.exit({
    options(old)
    reset_whocc_atc_catalogue()
  }, add = TRUE)
  load_whocc_atc_catalogue(required = FALSE)
}

test_that("WHOCC text dump parses 7-character codes and stamps version", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(
    c("atc,name", "C09AA05,example", "A10BA02,example", "N02BE01,example"),
    tmp
  )
  reset_whocc_atc_catalogue()
  old <- options(fiktive.whocc_atc_disable = FALSE, fiktive.whocc_atc = NULL)
  on.exit({
    options(old)
    reset_whocc_atc_catalogue()
  }, add = TRUE)
  cat <- load_whocc_atc_catalogue(path = tmp, cache_dir = tempfile("whocc-cache-"))
  expect_true(all(c("C09AA05", "A10BA02", "N02BE01") %in% cat$codes))
  expect_true(all(nchar(cat$codes) == 7L))
  expect_equal(cat$source, "WHOCC Oslo ATC/DDD Index")
  expect_true(nzchar(cat$version))
})

test_that("missing WHOCC catalogue is SCHEMA GAP and does not emit sprintf ATC", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 3)
  with_whocc_disabled({
    err <- tryCatch(
      generate_register("lmdb", pop, schema, from, to, seed = 41),
      error = function(e) e
    )
    expect_s3_class(err, "error")
    expect_match(err$message, "^SCHEMA GAP:")
    expect_match(err$message, "WHOCC")
    expect_match(err$message, "orders\\.atcddd\\.fhi\\.no")
    expect_match(err$message, "Do not use decoder::atc")
  })
})

test_that("empty lmdb does not require the WHOCC catalogue", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 2)
  with_whocc_disabled({
    empty <- generate_register("lmdb", pop, schema, "1960-01-01", "1960-12-31", seed = 1)
    expect_equal(nrow(empty), 0L)
    expect_true("atc" %in% names(empty))
    expect_type(empty$atc, "character")
  })
})

test_that("sampled atc is in the WHOCC catalogue; atc1-atc4 are prefixes", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 3)
  with_whocc_test_double({
    lmdb <- generate_register("lmdb", pop, schema, from, to, seed = 41)
    schema_names <- vapply(schema$registers$lmdb$columns, function(col) col$name, character(1))
    expect_true(all(names(lmdb) %in% schema_names))
    expect_true(all(lmdb$pnr %in% pop$pnr))
    if (nrow(lmdb)) {
      expect_true(all(lmdb$atc %in% .test_whocc_codes))
      expect_true(all(nchar(lmdb$atc) == 7L))
      expect_equal(lmdb$atc1, substr(lmdb$atc, 1L, 1L))
      expect_equal(lmdb$atc2, substr(lmdb$atc, 1L, 3L))
      expect_equal(lmdb$atc3, substr(lmdb$atc, 1L, 4L))
      expect_equal(lmdb$atc4, substr(lmdb$atc, 1L, 5L))
      expect_equal(attr(lmdb, "atc_catalogue"), "WHOCC Oslo ATC/DDD Index")
      expect_equal(attr(lmdb, "atc_catalogue_version"), "test-double")
    }
  })
})

test_that("live WHOCC dump: sampled atc is in the WHO set (skip if unavailable)", {
  cat <- live_whocc_catalogue()
  skip_if(is.null(cat) || !length(cat$codes), "WHOCC Oslo ATC dump not installed")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 3)
  reset_whocc_atc_catalogue()
  old <- options(fiktive.whocc_atc_disable = FALSE)
  on.exit({
    options(old)
    reset_whocc_atc_catalogue()
  }, add = TRUE)
  lmdb <- generate_register("lmdb", pop, schema, from, to, seed = 41)
  skip_if(!nrow(lmdb), "no LMDB rows in this seed/window")
  expect_true(all(lmdb$atc %in% cat$codes))
  expect_equal(attr(lmdb, "atc_catalogue"), "WHOCC Oslo ATC/DDD Index")
  expect_true(nzchar(attr(lmdb, "atc_catalogue_version")))
})
