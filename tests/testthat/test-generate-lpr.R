lpr2_from <- as.Date("2008-01-01")
lpr2_to <- as.Date("2010-12-31")
lpr3_from <- as.Date("2019-01-01")
lpr3_to <- as.Date("2021-12-31")

schema_names <- function(schema, register) {
  vapply(schema$registers[[register]]$columns, function(col) col$name, character(1))
}

test_that("lpr_diag recnum is a subset of lpr_adm recnum at the same seed", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 11)
  adm <- generate_register("lpr_adm", pop, schema, lpr2_from, lpr2_to, seed = 1)
  diag <- generate_register("lpr_diag", pop, schema, lpr2_from, lpr2_to, seed = 1)
  expect_true(all(names(adm) %in% schema_names(schema, "lpr_adm")))
  expect_true(all(names(diag) %in% schema_names(schema, "lpr_diag")))
  expect_true(nrow(adm) > 0L)
  expect_true(all(diag$recnum %in% adm$recnum))
  expect_equal(anyDuplicated(adm$recnum), 0L)
  adm2 <- generate_register("lpr_adm", pop, schema, lpr2_from, lpr2_to, seed = 1)
  expect_equal(adm, adm2)
})

test_that("lpr_sksopr and lpr_sksube recnum subset lpr_adm at the same seed", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 12)
  adm <- generate_register("lpr_adm", pop, schema, lpr2_from, lpr2_to, seed = 2)
  opr <- generate_register("lpr_sksopr", pop, schema, lpr2_from, lpr2_to, seed = 2)
  ube <- generate_register("lpr_sksube", pop, schema, lpr2_from, lpr2_to, seed = 2)
  expect_true(all(opr$recnum %in% adm$recnum))
  expect_true(all(ube$recnum %in% adm$recnum))
})

test_that("LPR3 child dw_ek_kontakt subsets lpr_a_kontakt at the same seed", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 13)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 3)
  dia <- generate_register("lpr_a_diagnose", pop, schema, lpr3_from, lpr3_to, seed = 3)
  pro <- generate_register("lpr_a_procregistrering", pop, schema, lpr3_from, lpr3_to, seed = 3)
  expect_true(nrow(kon) > 0L)
  expect_true(all(dia$dw_ek_kontakt %in% kon$dw_ek_kontakt))
  expect_true(all(pro$dw_ek_kontakt %in% kon$dw_ek_kontakt))
  expect_equal(anyDuplicated(kon$dw_ek_kontakt), 0L)
})

test_that("empty parent window yields 0 child rows with schema columns", {
  schema <- fixture_schema()
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

test_that("children have no pnr column when YAML has none", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 30L, seed = 15)
  diag <- generate_register("lpr_diag", pop, schema, lpr2_from, lpr2_to, seed = 4)
  opr <- generate_register("lpr_sksopr", pop, schema, lpr2_from, lpr2_to, seed = 4)
  ube <- generate_register("lpr_sksube", pop, schema, lpr2_from, lpr2_to, seed = 4)
  dia <- generate_register("lpr_a_diagnose", pop, schema, lpr3_from, lpr3_to, seed = 4)
  pro <- generate_register("lpr_a_procregistrering", pop, schema, lpr3_from, lpr3_to, seed = 4)
  expect_false("pnr" %in% names(diag))
  expect_false("pnr" %in% names(opr))
  expect_false("pnr" %in% names(ube))
  expect_false("pnr" %in% names(dia))
  expect_false("pnr" %in% names(pro))
  expect_false("year" %in% names(pro))
})

test_that("icd10 and sks are typed noise matching documented patterns, not a catalog", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 16)
  adm <- generate_register("lpr_adm", pop, schema, lpr2_from, lpr2_to, seed = 5)
  diag <- generate_register("lpr_diag", pop, schema, lpr2_from, lpr2_to, seed = 5)
  opr <- generate_register("lpr_sksopr", pop, schema, lpr2_from, lpr2_to, seed = 5)
  expect_type(adm$c_adiag, "character")
  expect_type(diag$c_diag, "character")
  expect_type(opr$c_opr, "character")
  if (nrow(adm)) {
    expect_true(all(grepl("^D[A-Z][0-9]{2}[0-9]*$", adm$c_adiag)))
    expect_true(all(adm$c_pattype %in% as.character(0:5)))
    expect_type(adm$c_spec, "character")
    expect_true(all(adm$d_uddto >= adm$d_inddto))
    birth <- pop$foed_dag[match(adm$pnr, pop$pnr)]
    year_diff <- as.integer(format(adm$d_inddto, "%Y")) - as.integer(format(birth, "%Y"))
    before <- format(adm$d_inddto, "%m-%d") < format(birth, "%m-%d")
    expect_equal(adm$v_alder, year_diff - as.integer(before))
    expect_equal(adm$year, as.integer(format(adm$d_inddto, "%Y")))
    expect_true(all(adm$d_inddto >= birth))
  }
  if (nrow(diag)) {
    expect_true(all(grepl("^D[A-Z][0-9]{2}[0-9]*$", diag$c_diag)))
    expect_true(all(diag$c_diagtype %in% c("A", "B", "G")))
  }
  if (nrow(opr)) {
    expect_true(all(grepl("^[A-Z][A-Z0-9]{3,}$", opr$c_opr)))
  }
  r_files <- list.files(
    file.path(testthat::test_path(), "..", "..", "R"),
    pattern = "[.]R$",
    full.names = TRUE
  )
  txt <- paste(unlist(lapply(r_files, readLines, warn = FALSE)), collapse = "\n")
  expect_false(grepl('c\\s*\\(\\s*"I10"', txt))
  expect_false(grepl('"E11"', txt))
  expect_false(grepl('"KJDB00"', txt))
  expect_false(grepl('"ALCA00"', txt))
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
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 18)
  kon <- generate_register("lpr_a_kontakt", pop, schema, "2017-01-01", "2018-12-31", seed = 7)
  dia <- generate_register("lpr_a_diagnose", pop, schema, "2017-01-01", "2018-12-31", seed = 7)
  expect_true(nrow(kon) > 0L)
  expect_equal(nrow(dia), 0L)
  expect_true("diag_kode" %in% names(dia))
})

test_that("lpr_a_kontakt copies person fields and uses datetime contact bounds", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 19)
  kon <- generate_register("lpr_a_kontakt", pop, schema, lpr3_from, lpr3_to, seed = 8)
  expect_true(nrow(kon) > 0L)
  expect_s3_class(kon$kont_starttidspunkt, "POSIXt")
  expect_s3_class(kon$kont_sluttidspunkt, "POSIXt")
  expect_true(all(kon$kont_sluttidspunkt >= kon$kont_starttidspunkt))
  birth <- pop$foed_dag[match(kon$pnr, pop$pnr)]
  sex <- pop$koen[match(kon$pnr, pop$pnr)]
  expect_equal(kon$borger_foedselsdato, birth)
  expect_equal(kon$borger_koen, sex)
  expect_equal(kon$year, as.integer(format(kon$kont_starttidspunkt, "%Y")))
  expect_true(all(nchar(kon$kont_type) == 6L))
  pro <- generate_register("lpr_a_procregistrering", pop, schema, lpr3_from, lpr3_to, seed = 8)
  if (nrow(pro)) {
    expect_s3_class(pro$proc_starttidspunkt, "POSIXt")
    expect_s3_class(pro$proc_sluttidspunkt, "POSIXt")
    expect_s3_class(pro$proc_indb_tidspunkt, "POSIXt")
    expect_true(all(grepl("^[A-Z][A-Z0-9]{3,}$", pro$proc_kode)))
  }
})
