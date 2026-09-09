cancer_from <- as.Date("2008-01-01")
cancer_to <- as.Date("2010-12-31")

schema_names <- function(schema, register) {
  vapply(schema$registers[[register]]$columns, function(col) col$name, character(1))
}

test_that("cancer is event_from_person on k_cprnr with WHO ICD10Koodit", {
  skip_if_not_installed("codeCollection")
  schema <- fixture_schema()
  expect_identical(schema$registers$cancer$one_row_per, "event_from_person")
  pop <- tiny_pop(schema, n = 40L, seed = 61)
  a <- generate_register("cancer", pop, schema, cancer_from, cancer_to, seed = 61)
  b <- generate_register("cancer", pop, schema, cancer_from, cancer_to, seed = 61)
  expect_equal(a, b)
  expect_true(all(names(a) %in% schema_names(schema, "cancer")))
  expect_true(nrow(a) > 0L)
  expect_true(all(a$k_cprnr %in% pop$pnr))
  expect_true(all(a$d_diagnosedato >= cancer_from & a$d_diagnosedato <= cancer_to))
  birth <- pop$foed_dag[match(a$k_cprnr, pop$pnr)]
  expect_true(all(a$d_diagnosedato >= birth))
  expect_equal(a$d_fdsdato, birth)
  expect_equal(
    a$v_diagnosealder,
    as.numeric(age_years(birth, a$d_diagnosedato))
  )
  expect_equal(a$v_diagaar, as.numeric(format(a$d_diagnosedato, "%Y")))
  expect_equal(a$v_diagmd, as.numeric(format(a$d_diagnosedato, "%m")))
  # Plain WHO ICD-10 — never sksr dia / D-prefix
  expect_type(a$c_icd10, "character")
  expect_false(any(grepl("^D[A-Z]", a$c_icd10)))
  expect_true(all(a$c_icd10 %in% load_icd10koodit_codes()))
  expect_false(any(grepl("^D[A-Z]", a$c_orggr_idc10)))
  expect_equal(attr(a, "catalogue"), "codeCollection::ICD10Koodit")
  expect_true(all(a$c_kommune %in% names(schema$code_systems$kom$lookup)))
  # c_region coverage from 2006 — filled in 2008-2010 window
  expect_true(all(a$c_region %in% names(schema$code_systems$reg$lookup)))
  # Local codes without published lists → soft typed noise (character)
  expect_type(a$c_sex, "character")
  expect_type(a$k_tumornr, "character")
  expect_type(a$c_topo3, "character")
  expect_false(all(is.na(a$c_topo3)))
})

test_that("cancer empty table is valid outside coverage / no events", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 12L, seed = 62)
  early <- generate_register(
    "cancer", pop, schema,
    as.Date("1900-01-01"), as.Date("1901-12-31"),
    seed = 62
  )
  expect_equal(nrow(early), 0L)
  expect_true(all(c("k_cprnr", "d_diagnosedato", "c_icd10") %in% names(early)))
})

test_that("cancer column coverage blanks pre-1978 ICD and pre-2006 region", {
  skip_if_not_installed("codeCollection")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 30L, seed = 63)
  # Window straddles 1978 ICD start and includes pre-2006 for region
  out <- generate_register(
    "cancer", pop, schema,
    as.Date("1975-01-01"), as.Date("1977-12-31"),
    seed = 63
  )
  if (nrow(out)) {
    expect_true(all(is.na(out$c_icd10)))
    expect_true(all(is.na(out$c_orggr_idc10)))
    expect_true(all(is.na(out$c_region)))
    expect_true(all(is.na(out$c_kommune)))
    # c_behandling covered through 2003 — still filled in mid-1970s
    expect_false(all(is.na(out$c_behandling)))
  }
})

test_that("lab_dm_forsker stays unimplemented after cancer step", {
  # STEP 6b implements mfr separately; lab remains later.
  expect_false("lab_dm_forsker" %in% fiktive:::.IMPLEMENTED_EVENTS)
})
