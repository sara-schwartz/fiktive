from <- as.Date("2008-01-01")
to <- as.Date("2010-12-31")

test_that("udda is annual person x year, persistent, columns subset of schema", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 1)
  a <- generate_register("udda", pop, schema, from, to, seed = 21)
  b <- generate_register("udda", pop, schema, from, to, seed = 21)
  expect_equal(a, b)
  schema_names <- vapply(schema$registers$udda$columns, function(col) col$name, character(1))
  expect_true(all(names(a) %in% schema_names))
  expect_equal(anyDuplicated(a[, c("pnr", "year")]), 0L)
  expect_equal(sort(unique(a$year)), c(2008L, 2009L, 2010L))
  expect_type(a$hfaudd, "character")
  counts <- as.integer(table(a$pnr))
  expect_true(all(counts == 3L))
})

test_that("akm is annual, alder_ult_ink matches 31 Dec, socio13 samples CS lookup", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, seed = 2)
  akm <- generate_register("akm", pop, schema, from, to, seed = 22)
  schema_names <- vapply(schema$registers$akm$columns, function(col) col$name, character(1))
  expect_true(all(names(akm) %in% schema_names))
  expect_equal(anyDuplicated(akm[, c("pnr", "year")]), 0L)
  expect_equal(akm$year, as.integer(akm$year))
  snap <- as.Date(paste0(akm$year, "-12-31"))
  birth <- pop$foed_dag[match(akm$pnr, pop$pnr)]
  year_diff <- as.integer(format(snap, "%Y")) - as.integer(format(birth, "%Y"))
  before <- format(snap, "%m-%d") < format(birth, "%m-%d")
  expect_equal(akm$alder_ult_ink, year_diff - as.integer(before))
  expect_type(akm$socio13, "integer")
  socio_keys <- as.integer(lookup_keys(schema$code_systems$socio13))
  expect_true(all(akm$socio13 %in% socio_keys))
  expect_true(all(is.na(akm$socio_gl)))
  expect_false(all(is.na(akm$socio13)))
})

test_that("akm CS-wired cols sample published lookups (not typed noise)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 23)
  # Window covers beskst02 / disco08 / nace_db07 / omfang / discotyp eras.
  akm <- generate_register(
    "akm", pop, schema,
    as.Date("2010-01-01"), as.Date("2012-12-31"),
    seed = 23
  )
  expect_true(nrow(akm) > 0L)

  beskst02_keys <- as.numeric(lookup_keys(schema$code_systems$beskst02))
  expect_true(all(akm$beskst02 %in% beskst02_keys))
  expect_type(akm$beskst02, "double")
  expect_true(all(akm$beskst13 %in% as.integer(beskst02_keys)))
  expect_type(akm$beskst13, "integer")
  # Old beskst era ends 2001 -- NA in 2010-2012
  expect_true(all(is.na(akm$beskst)))

  discotyp_keys <- lookup_keys(schema$code_systems$discotyp)
  expect_true(all(akm$discotyp %in% discotyp_keys))
  expect_type(akm$discotyp, "character")

  omfang_keys <- lookup_keys(schema$code_systems$omfang)
  expect_true(all(akm$omfang %in% omfang_keys))
  expect_type(akm$omfang, "character")

  disco08_keys <- lookup_keys(schema$code_systems$disco08)
  expect_true(all(akm$disco08_alle_indk_13 %in% disco08_keys))
  expect_type(akm$disco08_alle_indk_13, "character")

  nace_keys <- lookup_keys(schema$code_systems$nace_db07)
  expect_true(all(akm$nace_db07_13 %in% nace_keys))
  # Undotted form as AKM holds (not 01.11.00)
  expect_true(all(!grepl("\\.", akm$nace_db07_13)))
  expect_type(akm$nace_db07_13, "character")

  # Pre-2010 disco_old / pre-2007 nace_old out of coverage -> NA
  expect_true(all(is.na(akm$disco_alle_indk_13)))
  expect_true(all(is.na(akm$nace_13)))
  expect_true(all(is.na(akm$branche_77)))
  expect_true(all(is.na(akm$nystgr)))
})

test_that("akm kind:none CS cols use typed noise in-era (no invented lookup)", {
  schema <- fixture_schema()
  expect_identical(as.character(schema$code_systems$branche_77$values_from$kind), "none")
  expect_identical(as.character(schema$code_systems$nystgr$values_from$kind), "none")
  expect_identical(as.character(schema$code_systems$disco_old$values_from$kind), "none")
  expect_identical(as.character(schema$code_systems$nace_old$values_from$kind), "none")
  expect_true(is.null(lookup_keys(schema$code_systems$branche_77)))
  expect_true(is.null(lookup_keys(schema$code_systems$nystgr)))

  pop <- tiny_pop(schema, n = 12L, seed = 24)
  akm <- generate_register(
    "akm", pop, schema,
    as.Date("1995-01-01"), as.Date("1998-12-31"),
    seed = 24
  )
  expect_true(nrow(akm) > 0L)
  expect_type(akm$branche_77, "character")
  expect_false(all(is.na(akm$branche_77)))
  expect_type(akm$nystgr, "character")
  expect_false(all(is.na(akm$nystgr)))
  expect_type(akm$disco_alle_indk_13, "character")
  expect_false(all(is.na(akm$disco_alle_indk_13)))
  expect_type(akm$nace_13, "character")
  expect_false(all(is.na(akm$nace_13)))
  # beskst (1976-2001) samples published lookup in this window
  beskst_keys <- as.numeric(lookup_keys(schema$code_systems$beskst))
  expect_true(all(akm$beskst %in% beskst_keys))
  expect_type(akm$beskst, "double")
  # Unwired code col stays typed noise
  expect_type(akm$cprtjek, "character")
  expect_false(all(is.na(akm$cprtjek)))
})

test_that("no annual snapshot before birth", {
  schema <- fixture_schema()
  pop <- tibble::tibble(
    pnr = "00000001",
    foed_dag = as.Date("2009-06-01"),
    koen = 1L
  )
  udda <- generate_register("udda", pop, schema, from, to, seed = 3)
  expect_false(2008L %in% udda$year)
  expect_true(all(udda$year >= 2009L))
})
