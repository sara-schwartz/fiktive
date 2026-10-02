test_that("codebook() returns one row per column with type and code_system", {
  schema <- fixture_schema()
  cb <- codebook("bef", schema)
  expect_true(all(c("name", "label_da", "label_en", "type", "code_system", "values") %in% names(cb)))
  expect_equal(nrow(cb), length(schema$registers[["bef"]]$columns))
  expect_true("koen" %in% cb$name)
})

test_that("codebook() pastes value labels for coded columns", {
  schema <- fixture_schema()
  cb <- codebook("bef", schema)
  koen_values <- cb$values[cb$name == "koen"]
  expect_true(grepl("1: Male", koen_values))
  expect_true(grepl("2: Female", koen_values))
  pnr_values <- cb$values[cb$name == "pnr"]
  expect_true(is.na(pnr_values))
})

test_that("codebook() with multiple registers adds a register column", {
  schema <- fixture_schema()
  one <- codebook("bef", schema)
  expect_false("register" %in% names(one))
  two <- codebook(c("bef", "lmdb"), schema)
  expect_true("register" %in% names(two))
  expect_setequal(unique(two$register), c("bef", "lmdb"))
})

test_that("codebook() errors clearly on schema = NULL and unknown register id", {
  expect_error(codebook("bef", NULL), "schema")
  schema <- fixture_schema()
  expect_error(codebook("not_a_real_register", schema), "^SCHEMA GAP:")
})
