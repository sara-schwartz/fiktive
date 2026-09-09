faik_from <- as.Date("2008-01-01")
faik_to <- as.Date("2010-12-31")

schema_names <- function(schema, register) {
  vapply(schema$registers[[register]]$columns, function(col) col$name, character(1))
}

test_that("faik is household x year on familie_id, not person-level", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 12L, seed = 41)
  a <- generate_register("faik", pop, schema, faik_from, faik_to, seed = 41)
  b <- generate_register("faik", pop, schema, faik_from, faik_to, seed = 41)
  expect_equal(a, b)
  expect_true(all(names(a) %in% schema_names(schema, "faik")))
  expect_true(nrow(a) > 0L)
  # Grain: one row per (familie_id, year)
  expect_equal(anyDuplicated(a[, c("familie_id", "year")]), 0L)
  expect_equal(sort(unique(a$year)), c(2008L, 2009L, 2010L))
  # Scale is households x years, not persons expanded into FAIK rows via pnr
  n_hh <- length(unique(a$familie_id))
  expect_equal(nrow(a), n_hh * 3L)
  expect_equal(n_hh, nrow(pop))
  # Join key present and structural
  expect_type(a$familie_id, "character")
  expect_true(all(grepl("^H[0-9]{7}$", a$familie_id)))
  # Same household keeps one id across years
  by_hh <- split(a$year, a$familie_id)
  expect_true(all(vapply(by_hh, function(y) length(unique(y)) == 3L, logical(1))))
})

test_that("faik pnr is blank NA (not a real FAIK key / not person grain)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 10L, seed = 42)
  faik <- generate_register("faik", pop, schema, faik_from, faik_to, seed = 42)
  expect_true("pnr" %in% names(faik))
  expect_type(faik$pnr, "character")
  expect_true(all(is.na(faik$pnr)))
  # Must not echo population pnrs
  expect_false(any(faik$pnr %in% pop$pnr, na.rm = TRUE))
})

test_that("faik CS-wired cols sample published lookups (not typed noise)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 43)
  faik <- generate_register("faik", pop, schema, faik_from, faik_to, seed = 43)
  expect_true(nrow(faik) > 0L)

  famtype_keys <- as.numeric(lookup_keys(schema$code_systems$famtype))
  expect_true(all(faik$famtype %in% famtype_keys))
  expect_false(5 %in% faik$famtype) # published set has no code 5
  expect_type(faik$famtype, "double")

  bolig_keys <- as.numeric(lookup_keys(schema$code_systems$famboligform))
  expect_true(all(faik$famboligform %in% bolig_keys))
  expect_type(faik$famboligform, "double")

  socio_keys <- as.numeric(lookup_keys(schema$code_systems$socio13))
  expect_true(all(faik$famsociogrup_13 %in% socio_keys))
  expect_type(faik$famsociogrup_13, "double")
})

test_that("faik cols without code_system stay typed noise from schema types", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 10L, seed = 43)
  faik <- generate_register("faik", pop, schema, faik_from, faik_to, seed = 43)
  for (nm in c("famboligtype", "famsociogrup", "version")) {
    expect_true(nm %in% names(faik), info = nm)
    expect_type(faik[[nm]], "double")
    expect_false(all(is.na(faik[[nm]])), info = nm)
  }
  expect_type(faik$famhoejstudda, "character")
  expect_false(all(is.na(faik$famhoejstudda)))
  expect_type(faik$famaekvivadisp_13, "double")
})

test_that("faik respects register coverage ~1987-2024", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 8L, seed = 44)
  early <- generate_register(
    "faik", pop, schema,
    as.Date("1980-01-01"), as.Date("1985-12-31"),
    seed = 44
  )
  expect_equal(nrow(early), 0L)
  late <- generate_register(
    "faik", pop, schema,
    as.Date("2020-01-01"), as.Date("2030-12-31"),
    seed = 44
  )
  expect_true(nrow(late) > 0L)
  expect_true(all(late$year >= 2020L & late$year <= 2024L))
})
