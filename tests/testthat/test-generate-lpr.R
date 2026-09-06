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

# LPR3 fixtures include borger_koen (character, no CS) → SCHEMA GAP on fill.
# Drop it for happy-path contact/child tests; dedicated test covers the gap.
schema_without_borger_koen <- function(schema) {
  cols <- schema$registers$lpr_a_kontakt$columns
  keep <- !vapply(cols, function(col) {
    identical(as.character(col$id %||% col$name), "borger_koen")
  }, logical(1))
  schema$registers$lpr_a_kontakt$columns <- cols[keep]
  schema
}

test_that("lpr_adm recnum is unique and reproducible at the same seed", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 11)
  adm <- generate_register("lpr_adm", pop, schema, lpr2_from, lpr2_to, seed = 1)
  expect_true(all(names(adm) %in% schema_names(schema, "lpr_adm")))
  expect_true(nrow(adm) > 0L)
  expect_equal(anyDuplicated(adm$recnum), 0L)
  adm2 <- generate_register("lpr_adm", pop, schema, lpr2_from, lpr2_to, seed = 1)
  expect_equal(adm, adm2)
})

test_that("lpr_diag samples icd10_sks D-prefix from sksr dia (not plain WHO)", {
  skip_if_not_installed("sksr")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 11)
  diag <- generate_register("lpr_diag", pop, schema, lpr2_from, lpr2_to, seed = 1)
  expect_true(nrow(diag) > 0L)
  expect_type(diag$c_diag, "character")
  expect_true(all(startsWith(diag$c_diag, "D")))
  expect_false(any(grepl("^D[0-9]", diag$c_diag))) # not bare WHO chapter D
  pub <- published_sks_kode()
  expect_true(all(diag$c_diag %in% pub))
  pref <- as.character(sksr::SKS_labels$Prefix[match(diag$c_diag, sksr::SKS_labels$Kode)])
  expect_true(all(pref == "dia"))
  expect_equal(attr(diag, "catalogue"), "sksr::SKS_labels")
  expect_true(all(diag$c_diagtype %in% c("A", "B", "G", "H", "M", "C")))
})

test_that("plain icd10 draws WHO ICD10Koodit without D-prefix", {
  skip_if_not_installed("codeCollection")
  codes <- sample_icd10_who_codes(50L)
  expect_true(all(grepl("^[A-Z][0-9]{2}", codes)))
  expect_false(any(grepl("^D[A-Z]", codes)))
  expect_true("E119" %in% load_icd10koodit_codes())
  expect_false("DE119" %in% load_icd10koodit_codes())

  schema <- fixture_schema()
  # Force diagnosis columns onto plain icd10 (cancer/death form), no sks leftover.
  for (i in seq_along(schema$registers$lpr_diag$columns)) {
    col <- schema$registers$lpr_diag$columns[[i]]
    if (identical(as.character(col$code_system %||% ""), "icd10_sks")) {
      schema$registers$lpr_diag$columns[[i]]$code_system <- "icd10"
      schema$registers$lpr_diag$columns[[i]]$previous_code_system <- NULL
    }
  }
  pop <- tiny_pop(schema, n = 30L, seed = 11)
  diag <- generate_register("lpr_diag", pop, schema, lpr2_from, lpr2_to, seed = 2)
  expect_true(nrow(diag) > 0L)
  expect_false(any(grepl("^D[A-Z]", diag$c_diag)))
  expect_true(all(diag$c_diag %in% load_icd10koodit_codes()))
  expect_equal(attr(diag, "catalogue"), "codeCollection::ICD10Koodit")
})

test_that("icd8 previous_code_system until 1993 SCHEMA GAPs (no invented list)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 11)
  err <- tryCatch(
    generate_register("lpr_diag", pop, schema, as.Date("1990-01-01"), as.Date("1992-12-31"), seed = 1),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "^SCHEMA GAP:")
  expect_match(err$message, "ICD-8|icd8", ignore.case = TRUE)
})

test_that("lpr_sksopr and lpr_sksube recnum subset lpr_adm at the same seed", {
  skip_if_not_installed("sksr")
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 12)
  adm <- generate_register("lpr_adm", pop, schema, lpr2_from, lpr2_to, seed = 2)
  opr <- generate_register("lpr_sksopr", pop, schema, lpr2_from, lpr2_to, seed = 2)
  ube <- generate_register("lpr_sksube", pop, schema, lpr2_from, lpr2_to, seed = 2)
  expect_true(all(opr$recnum %in% adm$recnum))
  expect_true(all(ube$recnum %in% adm$recnum))
})

test_that("LPR3 procedure dw_ek_kontakt subsets lpr_a_kontakt at the same seed", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 40L, seed = 13)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 3)
  pro <- generate_register("lpr_a_procregistrering", pop, schema, lpr3_from, lpr3_to, seed = 3)
  expect_true(nrow(kon) > 0L)
  expect_true(all(pro$dw_ek_kontakt %in% kon$dw_ek_kontakt))
  expect_equal(anyDuplicated(kon$dw_ek_kontakt), 0L)
})

test_that("lpr_a_diagnose samples icd10_sks D-prefix", {
  skip_if_not_installed("sksr")
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, n = 40L, seed = 13)
  dia <- generate_register("lpr_a_diagnose", pop, schema, lpr3_from, lpr3_to, seed = 3)
  expect_true(nrow(dia) > 0L)
  expect_true(all(startsWith(dia$diag_kode, "D")))
  expect_false(any(grepl("^D[0-9]", dia$diag_kode)))
  pref <- as.character(sksr::SKS_labels$Prefix[match(dia$diag_kode, sksr::SKS_labels$Kode)])
  expect_true(all(pref == "dia"))
})

test_that("borger_koen character with no code_system is SCHEMA GAP (not pop koen)", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 19)
  err <- tryCatch(
    generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 8),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(err$message, "^SCHEMA GAP:")
  expect_match(err$message, "borger_koen")
  expect_match(err$message, "do not map from BEF koen")
})

test_that("empty parent window yields 0 child rows with schema columns", {
  schema <- schema_without_borger_koen(fixture_schema())
  pop <- tiny_pop(schema, seed = 14)
  empty_adm <- generate_register("lpr_adm", pop, schema, "1960-01-01", "1960-12-31", seed = 1)
  empty_diag <- generate_register("lpr_diag", pop, schema, "1960-01-01", "1960-12-31", seed = 1)
  empty_opr <- generate_register("lpr_sksopr", pop, schema, "1960-01-01", "1960-12-31", seed = 1)
  expect_equal(nrow(empty_adm), 0L)
  expect_equal(nrow(empty_diag), 0L)
  expect_equal(nrow(empty_opr), 0L)
  expect_true(all(c("recnum", "c_diag") %in% names(empty_diag)))
  expect_true(all(names(empty_diag) %in% schema_names(schema, "lpr_diag")))
  empty_kon <- generate_register("lpr_a_kontakt", pop, schema, "2010-01-01", "2010-12-31", seed = 1)
  empty_dia <- generate_register("lpr_a_diagnose", pop, schema, "2010-01-01", "2010-12-31", seed = 1)
  expect_equal(nrow(empty_kon), 0L)
  expect_equal(nrow(empty_dia), 0L)
  expect_true("dw_ek_kontakt" %in% names(empty_dia))
  expect_s3_class(empty_kon$kont_starttidspunkt, "POSIXt")
})
