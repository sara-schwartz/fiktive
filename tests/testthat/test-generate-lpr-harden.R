lpr2_from <- as.Date("2008-01-01")
lpr2_to <- as.Date("2010-12-31")
lpr3_from <- as.Date("2019-01-01")
lpr3_to <- as.Date("2021-12-31")

schema_names <- function(schema, register) {
  vapply(schema$registers[[register]]$columns, function(col) col$name, character(1))
}

published_sks_kode <- function() {
  as.character(sksr::SKS_labels$Kode)
}

# LPR3 fixtures include borger_koen (character, no CS) → warning() + NA on
# fill (see test-generate-lpr.R). Drop it for happy-path contact/child
# tests that aren't about that column, so they don't also assert on it.
schema_without_borger_koen <- function(schema) {
  cols <- schema$registers$lpr_a_kontakt$columns
  keep <- !vapply(cols, function(col) {
    identical(as.character(col$id %||% col$name), "borger_koen")
  }, logical(1))
  schema$registers$lpr_a_kontakt$columns <- cols[keep]
  schema
}

test_that("children have no pnr column when YAML has none", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 30L, seed = 15)
  empty_diag <- generate_register("lpr_diag", pop, schema, "1960-01-01", "1960-12-31", seed = 4)
  opr <- generate_register("lpr_sksopr", pop, schema, lpr2_from, lpr2_to, seed = 4)
  ube <- generate_register("lpr_sksube", pop, schema, lpr2_from, lpr2_to, seed = 4)
  empty_dia <- generate_register("lpr_a_diagnose", pop, schema, "2010-01-01", "2010-12-31", seed = 4)
  pro <- generate_register("lpr_a_procregistrering", pop, schema, lpr3_from, lpr3_to, seed = 4)
  expect_false("pnr" %in% names(empty_diag))
  expect_false("pnr" %in% names(opr))
  expect_false("pnr" %in% names(ube))
  expect_false("pnr" %in% names(empty_dia))
  expect_false("pnr" %in% names(pro))
  expect_false("year" %in% names(pro))
})

test_that("SKS procedures sample sksr; pattype is 0-3; ICD not invented", {
  skip_if_not_installed("sksr")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 16)
  adm <- generate_register("lpr_adm", pop, schema, lpr2_from, lpr2_to, seed = 5)
  opr <- generate_register("lpr_sksopr", pop, schema, lpr2_from, lpr2_to, seed = 5)
  expect_type(adm$c_adiag, "character")
  expect_true(all(is.na(adm$c_adiag)))
  expect_type(opr$c_opr, "character")
  if (nrow(adm)) {
    expect_true(all(adm$c_pattype %in% as.character(0:3)))
    expect_false(any(adm$c_pattype %in% c("4", "5")))
    expect_type(adm$c_spec, "character")
    expect_true(all(adm$d_uddto >= adm$d_inddto))
    birth <- pop$foed_dag[match(adm$pnr, pop$pnr)]
    year_diff <- as.integer(format(adm$d_inddto, "%Y")) - as.integer(format(birth, "%Y"))
    before <- format(adm$d_inddto, "%m-%d") < format(birth, "%m-%d")
    expect_equal(adm$v_alder, year_diff - as.integer(before))
    expect_equal(adm$year, as.integer(format(adm$d_inddto, "%Y")))
    expect_true(all(adm$d_inddto >= birth))
  }
  if (nrow(opr)) {
    pub <- published_sks_kode()
    expect_true(all(opr$c_opr %in% pub))
    expect_true(all(startsWith(opr$c_opr, "K")))
    expect_equal(attr(opr, "catalogue"), "sksr::SKS_labels")
    expect_equal(attr(opr, "catalogue_version"), as.character(utils::packageVersion("sksr")))
    pref <- as.character(sksr::SKS_labels$Prefix[match(opr$c_opr, sksr::SKS_labels$Kode)])
    expect_true(all(pref == "opr"))
  }
  r_files <- list.files(
    file.path(testthat::test_path(), "..", "..", "R"),
    pattern = "[.]R$",
    full.names = TRUE
  )
  txt <- paste(unlist(lapply(r_files, readLines, warn = FALSE)), collapse = "\n")
  expect_false(grepl('c\\s*\\(\\s*"I10"', txt))
  expect_false(grepl('"KJDB00"', txt))
  expect_false(grepl('"ALCA00"', txt))
  expect_false(grepl("decoder::icd10se[(]", txt))
  expect_false(grepl("decoder::atc[(]", txt))
})

test_that("missing sksr does not emit sprintf SKS codes", {
  testthat::local_mocked_bindings(sksr_is_installed = function() FALSE)
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 12)
  err <- tryCatch(
    generate_register("lpr_sksopr", pop, schema, lpr2_from, lpr2_to, seed = 2),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "sksr")
  expect_false(grepl("^SCHEMA GAP:", err$message))
})

test_that("t_psyk_adm is not implemented (not a SCHEMA GAP)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema)
  err <- tryCatch(
    generate_register("t_psyk_adm", pop, schema, lpr2_from, lpr2_to, seed = 1),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "not implemented yet")
  expect_false(grepl("^SCHEMA GAP:", err$message))
  err2 <- tryCatch(
    generate_register("t_psyk_diag", pop, schema, lpr2_from, lpr2_to, seed = 1),
    error = function(e) e
  )
  expect_match(err2$message, "not implemented yet")
  expect_false(grepl("^SCHEMA GAP:", err2$message))
})

test_that("faik household_year dispatches (implemented in test-generate-faik.R)", {
  schema <- fixture_schema()
  expect_identical(as.character(schema$registers$faik$one_row_per), "household_year")
  pop <- tiny_pop(schema, n = 8L, seed = 1)
  faik <- generate_register("faik", pop, schema, lpr2_from, lpr2_to, seed = 1)
  expect_true(nrow(faik) > 0L)
  expect_equal(anyDuplicated(faik[, c("familie_id", "year")]), 0L)
})

test_that("novel one_row_per is SCHEMA GAP", {
  schema <- fixture_schema()
  schema$registers$faik$one_row_per <- "person_x_molecule"
  pop <- tiny_pop(schema)
  err <- tryCatch(
    generate_register("faik", pop, schema, lpr2_from, lpr2_to, seed = 1),
    error = function(e) e
  )
  expect_match(err$message, "^SCHEMA GAP:")
  expect_match(err$message, "one_row_per")
})

test_that("procedure coverage is narrower than contacts", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 17)
  early_from <- as.Date("1985-01-01")
  early_to <- as.Date("1990-12-31")
  adm <- generate_register("lpr_adm", pop, schema, early_from, early_to, seed = 6)
  opr <- generate_register("lpr_sksopr", pop, schema, early_from, early_to, seed = 6)
  ube <- generate_register("lpr_sksube", pop, schema, early_from, early_to, seed = 6)
  expect_true(nrow(adm) > 0L)
  expect_equal(nrow(opr), 0L)
  expect_equal(nrow(ube), 0L)
  expect_true("c_opr" %in% names(opr))
})

test_that("lpr_a_diagnose coverage starts 2019 while contacts exist from 2017", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 40L, seed = 18)
  kon <- generate_register("lpr_a_kontakt", pop, schema, "2017-01-01", "2018-12-31", seed = 7)
  dia <- generate_register("lpr_a_diagnose", pop, schema, "2017-01-01", "2018-12-31", seed = 7)
  expect_true(nrow(kon) > 0L)
  expect_equal(nrow(dia), 0L)
  expect_true("diag_kode" %in% names(dia))
})

test_that("kont_type falls back to always-SKS-adm when the schema has no lprindberetningssystem", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  # Drop lprindberetningssystem entirely -- simulates a schema that hasn't
  # picked up registers-guide's newer code system yet.
  cols <- schema$registers$lpr_a_kontakt$columns
  keep <- !vapply(cols, function(col) {
    identical(as.character(col$id %||% col$name), "lprindberetningssystem")
  }, logical(1))
  schema$registers$lpr_a_kontakt$columns <- cols[keep]
  pop <- tiny_pop(schema, n = 20L, seed = 8)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 8)
  expect_false("lprindberetningssystem" %in% names(kon))
  expect_true(all(nchar(kon$kont_type) == 6L))
})

test_that("lprindberetningssystem is drawn uniformly by default (realistic = FALSE)", {
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 400L, seed = 8)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 8)
  share <- prop.table(table(kon$lprindberetningssystem))
  expect_true(all(share > 0.15 & share < 0.35))
})

test_that("lprindberetningssystem is weighted toward LPR3 under realistic = TRUE", {
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 400L, seed = 8)
  kon <- generate_register(
    "lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to,
    seed = 8, realistic = TRUE
  )
  share <- prop.table(table(kon$lprindberetningssystem))
  expect_gt(unname(share[["LPR3"]]), 0.6)
  expect_lt(unname(share[["LPR1"]]), 0.05)
})

test_that("kont_type format always agrees with its own row's lprindberetningssystem", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 400L, seed = 8)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 8)
  is_sks_format <- nchar(kon$kont_type) == 6L
  expect_equal(is_sks_format, kon$lprindberetningssystem == "LPR3")
})

test_that("kont_type has a PLAN-locked sksr catalogue (adm prefix) for LPR3 rows", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 20L, seed = 8)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 8)
  expect_true(nrow(kon) > 0L)
  lpr3 <- kon[kon$lprindberetningssystem == "LPR3", ]
  pub <- published_sks_kode()
  expect_true(all(lpr3$kont_type %in% pub))
})

test_that("kont_type is a legacy digit for non-LPR3 lprindberetningssystem", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 40L, seed = 8)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 8)
  legacy <- kon[kon$lprindberetningssystem != "LPR3", ]
  skip_if(nrow(legacy) == 0L, "no legacy rows drawn for this seed")
  expect_true(all(legacy$kont_type %in% c("0", "2")))
})

test_that("lpr_a_kontakt copies person fields and uses datetime contact bounds", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 40L, seed = 19)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 8)
  expect_true(nrow(kon) > 0L)
  expect_s3_class(kon$kont_starttidspunkt, "POSIXt")
  expect_s3_class(kon$kont_sluttidspunkt, "POSIXt")
  expect_true(all(kon$kont_sluttidspunkt >= kon$kont_starttidspunkt))
  birth <- pop$foed_dag[match(kon$pnr, pop$pnr)]
  expect_equal(kon$borger_foedselsdato, birth)
  expect_false("borger_koen" %in% names(kon))
  expect_equal(kon$year, as.integer(format(kon$kont_starttidspunkt, "%Y")))
  expect_true(all(is.na(kon$adiag)))
  lpr3 <- kon[kon$lprindberetningssystem == "LPR3", ]
  expect_true(all(nchar(lpr3$kont_type) == 6L))
  pub <- published_sks_kode()
  expect_true(all(lpr3$kont_type %in% pub))
  adm_pref <- as.character(sksr::SKS_labels$Prefix[match(lpr3$kont_type, sksr::SKS_labels$Kode)])
  expect_true(all(adm_pref == "adm"))
  expect_equal(attr(kon, "catalogue"), "sksr::SKS_labels")
  pro <- generate_register("lpr_a_procregistrering", pop, schema, lpr3_from, lpr3_to, seed = 8)
  if (nrow(pro)) {
    expect_s3_class(pro$proc_starttidspunkt, "POSIXt")
    expect_s3_class(pro$proc_sluttidspunkt, "POSIXt")
    expect_s3_class(pro$proc_indb_tidspunkt, "POSIXt")
    expect_true(all(pro$proc_kode %in% pub))
    expect_true(all(grepl("^[A-Z][A-Z0-9]{3,}$", pro$proc_kode)))
    expect_equal(attr(pro, "catalogue"), "sksr::SKS_labels")
    expect_equal(attr(pro, "catalogue_version"), as.character(utils::packageVersion("sksr")))
  }
})
