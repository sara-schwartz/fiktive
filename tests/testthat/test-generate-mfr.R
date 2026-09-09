mfr_from <- as.Date("2008-01-01")
mfr_to <- as.Date("2010-12-31")

schema_names <- function(schema, register) {
  vapply(schema$registers[[register]]$columns, function(col) col$name, character(1))
}

test_that("mfr is Levendefoedte event_from_person on cpr_barn", {
  schema <- fixture_schema()
  expect_identical(schema$registers$mfr$one_row_per, "event_from_person")
  expect_identical(schema$registers$mfr$join_keys, "cpr_barn")
  expect_true(isTRUE(schema$registers$mfr$deprecated))
  expect_match(schema$registers$mfr$name, "Levendefoedte", fixed = TRUE)
  # Schema relationship names BEF key `pnr`; register has no `pnr` column.
  expect_false("pnr" %in% schema_names(schema, "mfr"))
  pop <- tiny_pop(schema, n = 40L, seed = 71)
  a <- generate_register("mfr", pop, schema, mfr_from, mfr_to, seed = 71)
  b <- generate_register("mfr", pop, schema, mfr_from, mfr_to, seed = 71)
  expect_equal(a, b)
  expect_true(all(names(a) %in% schema_names(schema, "mfr")))
  expect_true(nrow(a) > 0L)
  # Primary join_keys: map carefully to population (BEF.pnr rehearsal).
  expect_true(all(a$cpr_barn %in% pop$pnr))
  expect_false("pnr" %in% names(a))
  expect_true(all(a$foedselsdato >= mfr_from & a$foedselsdato <= mfr_to))
  birth <- pop$foed_dag[match(a$cpr_barn, pop$pnr)]
  expect_true(all(a$foedselsdato >= birth))
  expect_equal(a$foedselsaar, as.character(format(a$foedselsdato, "%Y")))
  # cpr_moder is an extra join_key — structural noise, not a family-graph invent.
  expect_type(a$cpr_moder, "character")
  expect_true(all(nzchar(a$cpr_moder)))
  expect_false(all(a$cpr_moder %in% pop$pnr))
  # Bare role=code with no code_system → typed noise (do not invent lists).
  expect_type(a$koen_barn, "character")
  expect_type(a$levende_eller_doedfoedt, "character")
  expect_type(a$markoer_kejsersnit, "character")
  expect_type(a$laengde_barn, "character") # live type is character — honour it
  expect_type(a$vaegt_barn, "double")
  expect_type(a$gestationsalder_dage, "double")
  # bmi_moder / vaegt_moder coverage from 2003 — filled in 2008-2010 window
  expect_false(all(is.na(a$bmi_moder)))
  expect_false(all(is.na(a$vaegt_moder)))
})

test_that("mfr empty outside 1997-2018 coverage; no post-2018 invent", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 12L, seed = 72)
  early <- generate_register(
    "mfr", pop, schema,
    as.Date("1990-01-01"), as.Date("1995-12-31"),
    seed = 72
  )
  expect_equal(nrow(early), 0L)
  expect_true(all(c("cpr_barn", "foedselsdato", "cpr_moder") %in% names(early)))
  late <- generate_register(
    "mfr", pop, schema,
    as.Date("2019-01-01"), as.Date("2024-12-31"),
    seed = 72
  )
  expect_equal(nrow(late), 0L)
})

test_that("mfr column coverage blanks pre-1998 amnioinfusion and pre-2003 BMI", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 40L, seed = 73)
  out <- generate_register(
    "mfr", pop, schema,
    as.Date("1997-01-01"), as.Date("1997-12-31"),
    seed = 73
  )
  if (nrow(out)) {
    expect_true(all(is.na(out$amnioinfusion)))
    expect_true(all(is.na(out$bmi_moder)))
    expect_true(all(is.na(out$vaegt_moder)))
    expect_false(all(is.na(out$vaegt_barn)))
    expect_false(all(is.na(out$markoer_kejsersnit)))
  }
})

test_that("lab_dm_forsker stays unimplemented in this step", {
  schema <- fixture_schema()
  expect_false("lab_dm_forsker" %in% fiktive:::.IMPLEMENTED_EVENTS)
  expect_true("mfr" %in% fiktive:::.IMPLEMENTED_EVENTS)
})
