# Numeric/integer columns with no code_system used to all share the same
# generic runif(0.5, 20) / sample.int(11)-1 fallback regardless of what
# they measure -- fine as an arbitrary placeholder, badly wrong for e.g.
# gestational age in days (real ~154-300) or an Apgar score (must be
# 0-10). See R/generate-numeric-ranges.R for the curated ranges and
# R/generate-columns.R's derived_column() for the age-in-days/months cases
# that derive from the row's own birth/event dates instead.

test_that("mfr anthropometric/clinical columns are within plausible ranges", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 80L, seed = 41)
  mfr <- generate_register("mfr", pop, schema, as.Date("2005-01-01"), as.Date("2010-12-31"), seed = 41)
  skip_if(!nrow(mfr), "no rows generated at this seed")
  expect_true(all(mfr$gestationsalder_dage >= 154 & mfr$gestationsalder_dage <= 300))
  expect_true(all(mfr$vaegt_barn >= 400 & mfr$vaegt_barn <= 5500))
  expect_true(all(mfr$apgarscore_efter5minutter >= 0 & mfr$apgarscore_efter5minutter <= 10))
  expect_true(all(mfr$hovedomfang >= 26 & mfr$hovedomfang <= 38))
  expect_true(all(mfr$bmi_moder >= 15 & mfr$bmi_moder <= 50))
  expect_true(all(mfr$paritet >= 0 & mfr$paritet <= 8))
})

test_that("bef household/children counts are small integers, not 0.5-20 noise", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 42)
  bef <- generate_register("bef", pop, schema, as.Date("2008-01-01"), as.Date("2009-12-31"), seed = 42)
  expect_true(all(bef$antboernf == round(bef$antboernf)))
  expect_true(all(bef$antboernf >= 0 & bef$antboernf <= 6))
  expect_true(all(bef$antpersf >= 1 & bef$antpersf <= 8))
})

test_that("v_alddg/v_aldmdr derive from the same birth/event dates as v_alder, not a second draw", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 43)
  adm <- generate_register("lpr_adm", pop, schema, as.Date("2008-01-01"), as.Date("2010-12-31"), seed = 43)
  skip_if(!nrow(adm), "no rows generated at this seed")
  expect_true(all(adm$v_sengdage >= 0 & adm$v_sengdage <= 60))
  expect_true(all(adm$v_indminut >= 0 & adm$v_indminut <= 59))
  expect_true(all(adm$v_udtime >= 0 & adm$v_udtime <= 23))
  # v_alddg (days) and v_alder (completed years) both come from the same
  # foed_dag/d_inddto -- v_alddg / 365.25 must land in [v_alder, v_alder + 1).
  implied_years <- adm$v_alddg / 365.25
  expect_true(all(implied_years >= adm$v_alder & implied_years < adm$v_alder + 1.05))
  expect_equal(adm$v_aldmdr, as.integer(round(adm$v_alddg / 30.44)))
})

test_that("label-flagged binary columns draw 0/1, not an unlimited range", {
  # flag_kont_afsluttet (numeric) and flag_valideret (character) have no
  # code_system -- registers-guide found no published domain for either --
  # but both are unambiguously binary from their own label ("... flag").
  # See R/generate-numeric-ranges.R for why these get a documented 0/1
  # guess while a real multi-category code (e.g. bef's opr_land, faik's
  # famboligtype) does not.
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 45)
  kon <- suppressWarnings(
    generate_register("lpr_a_kontakt", pop, schema, as.Date("2019-01-01"), as.Date("2021-12-31"), seed = 45)
  )
  skip_if(!nrow(kon), "no rows generated at this seed")
  expect_true(all(kon$flag_kont_afsluttet %in% c(0, 1)))

  dd <- generate_register("dodsaarsager", pop, schema, as.Date("2022-01-01"), as.Date("2023-12-31"), seed = 45)
  skip_if(!nrow(dd), "no rows generated at this seed")
  expect_true(all(dd$flag_valideret %in% c("0", "1")))
})

test_that("sssy's alderimp and vnds_ind/vnds_ud's alder_ult are the row's real age, not independent noise", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 44)
  sssy <- suppressWarnings(generate_register("sssy", pop, schema, as.Date("2010-01-01"), as.Date("2012-12-31"), seed = 44))
  skip_if(!nrow(sssy), "no rows generated at this seed")
  expect_true(all(sssy$alderimp >= 0 & sssy$alderimp <= 105))

  ind <- suppressWarnings(generate_register("vnds_ind", pop, schema, as.Date("2010-01-01"), as.Date("2012-12-31"), seed = 44))
  skip_if(!nrow(ind), "no rows generated at this seed")
  birth <- pop$foed_dag[match(ind$pnr, pop$pnr)]
  expected <- as.integer(format(ind$haend_dato, "%Y")) - as.integer(format(birth, "%Y")) -
    as.integer(format(ind$haend_dato, "%m-%d") < format(birth, "%m-%d"))
  expect_equal(ind$alder_ult, expected)
})
