win_from <- as.Date("2008-01-01")
win_to <- as.Date("2009-12-31")

test_that("generate_register stamps schema_commit, seed, package version", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 8L, seed = 7)
  bef <- generate_register("bef", pop, schema, win_from, win_to, seed = 7)
  st <- register_stamps(bef)
  expect_equal(st$schema_commit, schema$schema_commit)
  expect_equal(st$seed, 7)
  expect_true(is.character(st$fiktive_version) && nzchar(st$fiktive_version))
})

test_that("write_register default CSV persists stamps in sidecar", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 6L, seed = 8)
  bef <- generate_register("bef", pop, schema, win_from, win_to, seed = 8)
  tmp <- tempfile("fiktive-write")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp)
  path <- write_register(bef, file.path(tmp, "bef"))
  expect_true(grepl("\\.csv$", path))
  expect_true(file.exists(path))
  meta_path <- paste0(path, ".meta.yaml")
  expect_true(file.exists(meta_path))
  meta <- yaml::read_yaml(meta_path)
  expect_equal(meta$schema_commit, schema$schema_commit)
  expect_equal(meta$seed, 8)
  expect_true(nzchar(meta$fiktive_version))
  re <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_equal(nrow(re), nrow(bef))
  expect_true(all(names(bef) %in% names(re)))
})

test_that("write_register parquet and hive_year are opt-in", {
  skip_if_not_installed("arrow")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 6L, seed = 9)
  bef <- generate_register("bef", pop, schema, win_from, win_to, seed = 9)
  tmp <- tempfile("fiktive-parquet")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp)
  pq <- write_register(bef, file.path(tmp, "bef"), format = "parquet")
  expect_true(grepl("\\.parquet$", pq))
  expect_true(file.exists(pq))
  expect_true(file.exists(paste0(pq, ".meta.yaml")))
  hive_root <- file.path(tmp, "bef_hive")
  write_register(bef, hive_root, format = "parquet", hive_year = TRUE)
  expect_true(dir.exists(hive_root))
  expect_true(file.exists(file.path(hive_root, "_fiktive_meta.yaml")))
  year_dirs <- list.files(hive_root, pattern = "^year=")
  expect_true(length(year_dirs) >= 1L)
})

test_that("generate_registers requires registers= (no silent dump)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 5L, seed = 10)
  expect_error(
    generate_registers(population = pop, schema = schema, from = win_from, to = win_to),
    "registers.*required|refusing a silent dump"
  )
  expect_error(
    generate_registers(NULL, pop, schema, win_from, win_to),
    "non-empty character"
  )
  out <- generate_registers(
    registers = c("bef", "udda"),
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 10
  )
  expect_equal(sort(names(out)), c("bef", "udda"))
  expect_true(nrow(out$bef) > 0L)
  expect_true(nrow(out$udda) > 0L)
  expect_equal(register_stamps(out$bef)$seed, 10)
})

test_that("generate_custom_register person_reference_date joins on pnr", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 10L, seed = 11)
  cols <- tibble::tibble(
    name = c("score", "flag"),
    type = c("integer", "logical"),
    min = c(0, NA),
    max = c(5, NA),
    values = c(NA_character_, NA_character_)
  )
  ext <- generate_custom_register(
    id = "ext_score",
    one_row_per = "person_reference_date",
    columns = cols,
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 11,
    cadence = "annual"
  )
  expect_true(all(c("pnr", "score", "flag") %in% names(ext)))
  expect_true(all(ext$pnr %in% pop$pnr))
  expect_true(all(ext$score >= 0L & ext$score <= 5L))
  expect_type(ext$flag, "logical")
  expect_equal(register_stamps(ext)$schema_commit, schema$schema_commit)
})

test_that("generate_custom_register household_year requires household join_keys", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 8L, seed = 12)
  cols <- tibble::tibble(
    name = "rooms",
    type = "integer",
    min = 1,
    max = 6
  )
  expect_error(
    generate_custom_register(
      id = "ext_hh",
      one_row_per = "household_year",
      columns = cols,
      population = pop,
      schema = schema,
      from = win_from,
      to = win_to,
      seed = 12
    ),
    "join_keys.*required|silent pnr"
  )
  expect_error(
    generate_custom_register(
      id = "ext_hh",
      one_row_per = "household_year",
      join_keys = "pnr",
      columns = cols,
      population = pop,
      schema = schema,
      from = win_from,
      to = win_to,
      seed = 12
    ),
    "household-side|not pnr"
  )
  hh <- generate_custom_register(
    id = "ext_hh",
    one_row_per = "household_year",
    join_keys = "familie_id",
    columns = cols,
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 12
  )
  expect_true("familie_id" %in% names(hh))
  expect_true(all(grepl("^H[0-9]{7}$", hh$familie_id)))
  expect_equal(anyDuplicated(hh[, c("familie_id", "year")]), 0L)
  expect_true(all(hh$rooms >= 1L & hh$rooms <= 6L))
})

test_that("generate_custom_register novel grain is SCHEMA GAP", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 5L, seed = 13)
  cols <- tibble::tibble(name = "x", type = "integer")
  expect_error(
    generate_custom_register(
      id = "ext_bad",
      one_row_per = "episode_spell",
      columns = cols,
      population = pop,
      schema = schema,
      from = win_from,
      to = win_to,
      seed = 13
    ),
    "SCHEMA GAP"
  )
})

test_that("generate_custom_register expand_from_parent needs explicit parent", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 8L, seed = 14)
  parent <- generate_register("lpr_adm", pop, schema, win_from, win_to, seed = 14)
  cols <- tibble::tibble(
    name = "note_code",
    type = "character",
    values = "A|B|C"
  )
  expect_error(
    generate_custom_register(
      id = "ext_child",
      one_row_per = "expand_from_parent",
      join_keys = "recnum",
      columns = cols,
      population = pop,
      schema = schema,
      from = win_from,
      to = win_to,
      seed = 14
    ),
    "parent.*required"
  )
  child <- generate_custom_register(
    id = "ext_child",
    one_row_per = "expand_from_parent",
    join_keys = "recnum",
    columns = cols,
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 14,
    parent = parent
  )
  expect_true("recnum" %in% names(child))
  if (nrow(child) > 0L) {
    expect_true(all(child$recnum %in% parent$recnum))
    expect_true(all(child$note_code %in% c("A", "B", "C")))
  }
})

test_that("generate_custom_register accepts columns CSV path", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 6L, seed = 15)
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv), add = TRUE)
  utils::write.csv(
    data.frame(
      name = c("grp", "val"),
      type = c("character", "numeric"),
      min = c(NA, 0.1),
      max = c(NA, 0.9),
      values = c("X|Y", NA),
      coefficient = c(1.5, -0.2), # ignored — no coeffs in structural CSV
      stringsAsFactors = FALSE
    ),
    csv,
    row.names = FALSE
  )
  ext <- generate_custom_register(
    id = "ext_csv",
    one_row_per = "event_from_person",
    columns = csv,
    population = pop,
    schema = schema,
    from = win_from,
    to = win_to,
    seed = 15
  )
  expect_true(all(c("pnr", "grp", "val") %in% names(ext)))
  expect_false("coefficient" %in% names(ext))
  if (nrow(ext) > 0L) {
    expect_true(all(ext$grp %in% c("X", "Y")))
    expect_true(all(ext$val >= 0.1 & ext$val <= 0.9))
  }
})

test_that("generate_register stays schema ids only (custom id gaps)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 4L, seed = 16)
  expect_error(
    generate_register("ext_score", pop, schema, win_from, win_to, seed = 16),
    "SCHEMA GAP"
  )
})
