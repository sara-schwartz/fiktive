test_that("load_registers_schema stamps a schema_commit and sees register id bef", {
  schema <- fixture_schema()
  expect_match(schema$schema_commit, "^[0-9a-f]{40}$")
  expect_true("bef" %in% names(schema$registers))
  expect_equal(schema$registers$bef$id, "bef")
  expect_true("koen" %in% names(schema$code_systems))
})

test_that("live GitHub schema load stamps commit and sees bef", {
  skip_on_cran()
  skip_if_offline("github.com")
  schema <- load_registers_schema()
  expect_match(schema$schema_commit, "^[0-9a-f]{40}$")
  expect_false(identical(schema$schema_commit, strrep("0", 40L)))
  expect_true("bef" %in% names(schema$registers))
  expect_true(grepl("registers-guide", schema$schema_source))
})

test_that("schema_gap() messages start with SCHEMA GAP:", {
  expect_error(schema_gap("column foo", "a documented name"), "^SCHEMA GAP:")
})

test_that("unknown register id is a SCHEMA GAP", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema)
  expect_error(
    generate_register("not_a_register", pop, schema, "2008-01-01", "2008-12-31", seed = 1),
    "^SCHEMA GAP:"
  )
})

test_that("expand-from-parent register is not implemented yet", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema)
  err <- tryCatch(
    generate_register("vnds_ind", pop, schema, "2008-01-01", "2008-12-31", seed = 1),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "not implemented yet")
  expect_false(grepl("^SCHEMA GAP:", err$message))
})

test_that("untyped column with no code_system is a SCHEMA GAP", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema)
  schema$registers$udda$columns <- c(
    schema$registers$udda$columns,
    list(list(id = "mystery", name = "mystery"))
  )
  expect_error(
    generate_register("udda", pop, schema, "2008-01-01", "2008-12-31", seed = 1),
    "^SCHEMA GAP:"
  )
})
