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
  # -- and, since a household can have more than one member (see
  # generate_background_population()), fewer households than people.
  n_hh <- length(unique(a$familie_id))
  expect_equal(nrow(a), n_hh * 3L)
  expect_equal(n_hh, length(unique(pop$familie_id)))
  expect_true(n_hh <= nrow(pop))
  # Join key present and structural
  expect_type(a$familie_id, "character")
  expect_true(all(grepl("^H[0-9]{7}$", a$familie_id)))
  # Same household keeps one id across years
  by_hh <- split(a$year, a$familie_id)
  expect_true(all(vapply(by_hh, function(y) length(unique(y)) == 3L, logical(1))))
})

test_that("bef and faik share real, joinable familie_id values (regression: bef/faik household join)", {
  # Bug: bef and faik used to draw familie_id independently (bef via
  # typed_noise()'s generic join_key fallback, faik via its own fresh
  # sample.int() draw), so the standard SEPLINE-style household-income join
  # (look up a person's familie_id in bef for a year, then that
  # familie_id+year in faik) matched almost nothing -- ~1% pure collision
  # noise, not a real join. Both now read familie_id from the same
  # population (generate_background_population()).
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 200L, seed = 61)
  bef <- generate_register("bef", pop, schema, as.Date("2010-01-01"), as.Date("2011-12-31"), seed = 61)
  faik <- generate_register("faik", pop, schema, as.Date("2010-01-01"), as.Date("2011-12-31"), seed = 61)
  skip_if(!nrow(bef) || !nrow(faik), "no rows generated at this seed")

  year <- sort(unique(bef$year))[[1]]
  bef_y <- bef[bef$year == year, ]
  faik_y <- faik[faik$year == year, ]
  skip_if(!nrow(bef_y) || !nrow(faik_y), "no rows for the shared year at this seed")

  matched <- mean(bef_y$familie_id %in% faik_y$familie_id)
  expect_gt(matched, 0.95) # was ~0.01 (pure random-string collision) before the fix

  # A person's familie_id must also be stable across bef's own snapshots
  # (quarters/years), not re-randomized on every row.
  by_person <- split(bef$familie_id, bef$pnr)
  expect_true(all(vapply(by_person, function(x) length(unique(x)) == 1L, logical(1))))
})

test_that("generate_household_year() errors clearly on a population with no familie_id", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 10L, seed = 62)
  pop$familie_id <- NULL
  err <- tryCatch(
    generate_register("faik", pop, schema, faik_from, faik_to, seed = 62),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "familie_id")
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
