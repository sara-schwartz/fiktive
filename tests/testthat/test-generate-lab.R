lab_from <- as.Date("2008-01-01")
lab_to <- as.Date("2010-12-31")

schema_names <- function(schema, register) {
  vapply(schema$registers[[register]]$columns, function(col) col$name, character(1))
}

with_labterm_fixture <- function(code) {
  path <- testthat::test_path("fixtures", "labterm", "npu-codes.csv")
  # Clear memoised catalogue between tests
  if (exists(".fiktive_labterm_cache", envir = asNamespace("fiktive"), inherits = FALSE)) {
    env <- get(".fiktive_labterm_cache", envir = asNamespace("fiktive"))
    env$catalogue <- NULL
  }
  if (exists(".fiktive_labterm_stamp", envir = asNamespace("fiktive"), inherits = FALSE)) {
    env <- get(".fiktive_labterm_stamp", envir = asNamespace("fiktive"))
    env$catalogue <- NULL
    env$version <- NULL
  }
  withr::with_options(list(fiktive.labterm = path, fiktive.labterm_disable = NULL), code)
}

test_that("lab_dm_forsker is event_from_person on patient_cpr with LabTerm NPU", {
  with_labterm_fixture({
    schema <- fixture_schema()
    expect_identical(schema$registers$lab_dm_forsker$one_row_per, "event_from_person")
    expect_identical(schema$registers$lab_dm_forsker$join_keys, "patient_cpr")
    expect_false("pnr" %in% schema_names(schema, "lab_dm_forsker"))
    # HARD GAP: no code_system / values_from on analysiscode
    ac <- schema$registers$lab_dm_forsker$columns[[
      which(vapply(schema$registers$lab_dm_forsker$columns, function(c) {
        identical(c$name, "analysiscode")
      }, logical(1)))
    ]]
    expect_null(ac$code_system)
    pop <- tiny_pop(schema, n = 40L, seed = 81)
    a <- generate_register("lab_dm_forsker", pop, schema, lab_from, lab_to, seed = 81)
    b <- generate_register("lab_dm_forsker", pop, schema, lab_from, lab_to, seed = 81)
    expect_equal(a, b)
    expect_true(all(names(a) %in% schema_names(schema, "lab_dm_forsker")))
    expect_true(nrow(a) > 0L)
    # join_keys: map carefully to population (BEF.pnr rehearsal).
    expect_true(all(a$patient_cpr %in% pop$pnr))
    expect_false("pnr" %in% names(a))
    expect_true(all(a$samplingdate >= lab_from & a$samplingdate <= lab_to))
    birth <- pop$foed_dag[match(a$patient_cpr, pop$pnr)]
    expect_true(all(a$samplingdate >= birth))
    # LabTerm / published NPU — never sprintf noise
    expect_type(a$analysiscode, "character")
    expect_true(all(grepl("^(NPU|DNK)[0-9]{5}$", a$analysiscode)))
    expect_true(all(a$analysiscode %in% load_labterm_codes()))
    expect_false(any(grepl("^[0-9]{3}$", a$analysiscode)))
    expect_true(!is.na(attr(a, "catalogue")))
    # value is character (live type) — honour it; bare role=code → typed noise
    expect_type(a$value, "character")
    expect_type(a$unit, "character")
    expect_type(a$resulttype, "character")
    expect_type(a$laboratorium_idcode, "character")
    expect_type(a$operator, "character")
    expect_type(a$samplingtime, "character")
  })
})

test_that("lab_dm_forsker empty outside 2008-2025 coverage", {
  with_labterm_fixture({
    schema <- fixture_schema()
    pop <- tiny_pop(schema, n = 12L, seed = 82)
    early <- generate_register(
      "lab_dm_forsker", pop, schema,
      as.Date("2000-01-01"), as.Date("2005-12-31"),
      seed = 82
    )
    expect_equal(nrow(early), 0L)
    expect_true(all(c("patient_cpr", "samplingdate", "analysiscode") %in% names(early)))
  })
})

test_that("lab_dm_forsker analysiscode SCHEMA GAPs without LabTerm", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 83)
  if (exists(".fiktive_labterm_cache", envir = asNamespace("fiktive"), inherits = FALSE)) {
    env <- get(".fiktive_labterm_cache", envir = asNamespace("fiktive"))
    env$catalogue <- NULL
  }
  err <- tryCatch(
    withr::with_options(
      list(fiktive.labterm = NULL, fiktive.labterm_disable = TRUE, fiktive.labterm_fetch_ifcc = FALSE),
      {
        Sys.unsetenv("FIKTIVE_LABTERM")
        Sys.unsetenv("FIKTIVE_LABTERM_URL")
        generate_register("lab_dm_forsker", pop, schema, lab_from, lab_to, seed = 83)
      }
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "^SCHEMA GAP:")
  expect_match(err$message, "LabTerm|NPU|analysiscode")
})

test_that("lab_dm_forsker is implemented in STEP 6c", {
  expect_true("lab_dm_forsker" %in% fiktive:::.IMPLEMENTED_EVENTS)
  expect_true("mfr" %in% fiktive:::.IMPLEMENTED_EVENTS)
  expect_true("cancer" %in% fiktive:::.IMPLEMENTED_EVENTS)
})
