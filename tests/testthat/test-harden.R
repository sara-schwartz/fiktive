test_that("koen fixture includes published 9", {
  schema <- fixture_schema()
  keys <- names(schema$code_systems$koen$lookup)
  expect_true(all(c("1", "2", "9") %in% keys | all(c(1, 2, 9) %in% as.integer(keys))))
  # population may sample 9
  pop <- generate_background_population(200L, seed = 99, schema = schema)
  expect_true(all(pop$koen %in% c(1L, 2L, 9L)))
})

test_that("kom mixes_eras without lookup SCHEMA GAPs", {
  schema <- fixture_schema()
  schema$code_systems$kom$lookup <- NULL
  pop <- tiny_pop(schema, n = 10L, seed = 1)
  err <- tryCatch(
    generate_register("bef", pop, schema, as.Date("2020-01-01"), as.Date("2020-12-31"), seed = 1),
    error = function(e) e
  )
  expect_match(err$message, "^SCHEMA GAP:")
  expect_match(err$message, "mixes eras|kom", ignore.case = TRUE)
})

test_that("single-year column coverage is softened against multi-year register", {
  schema <- fixture_schema()
  # Inject a bogus 2025-only stamp on foed_dag while register spans decades.
  cols <- schema$registers$bef$columns
  for (i in seq_along(cols)) {
    if (identical(as.character(cols[[i]]$id), "familie_type")) {
      cols[[i]]$coverage <- list(from = 2025, to = 2025)
    }
  }
  schema$registers$bef$columns <- cols
  pop <- tiny_pop(schema, n = 12L, seed = 5)
  bef <- generate_register("bef", pop, schema, as.Date("2008-01-01"), as.Date("2009-12-31"), seed = 5)
  expect_true(nrow(bef) > 0L)
  # Softened: values still filled in 2008-2009 (not NA-masked by 2025 stamp).
  expect_false(all(is.na(bef$familie_type)))
})

test_that("PLAN clinical catalogue lock still distinguishes icd10 vs icd10_sks", {
  plan <- paste(readLines(testthat::test_path("..", "..", "notes", "PLAN.md"), warn = FALSE), collapse = "\n")
  expect_match(plan, "icd10_sks")
  expect_match(plan, "ICD10Koodit")
  expect_match(plan, "Prefix == \"dia\"|Prefix `dia`|Prefix dia")
})

test_that("values_from.kind=package is cross-checked against PLAN locks", {
  schema <- fixture_schema()
  expect_identical(schema$code_systems$icd10$values_from$dataset, "ICD10Koodit")
  expect_identical(schema$code_systems$atc$values_from$dataset, "ATCKoodit")
  expect_identical(schema$code_systems$icd10_sks$values_from$filter$value, "dia")

  # Mismatch: wrong dataset under package kind → SCHEMA GAP (no silent override).
  schema$code_systems$atc$values_from$dataset <- "WrongDataset"
  pop <- tiny_pop(schema, n = 40L, seed = 3)
  err <- tryCatch(
    generate_register("lmdb", pop, schema, as.Date("2015-01-01"), as.Date("2016-12-31"), seed = 3),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "^SCHEMA GAP:")
  expect_match(err$message, "PLAN lock|ATCKoodit|does not match", ignore.case = TRUE)
})

test_that("hfaudd fixture matches kind:none (no invented lookup catalogue)", {
  schema <- fixture_schema()
  cs <- schema$code_systems$hfaudd
  expect_identical(as.character(cs$values_from$kind), "none")
  expect_true(is.null(lookup_keys(cs)) || !length(lookup_keys(cs)))
  pop <- tiny_pop(schema, n = 10L, seed = 7)
  udda <- generate_register("udda", pop, schema, as.Date("2008-01-01"), as.Date("2009-12-31"), seed = 7)
  expect_type(udda$hfaudd, "character")
  expect_true(nrow(udda) > 0L)
})
