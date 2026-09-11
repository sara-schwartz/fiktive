test_that("sample_icd10_coherent never draws a female-only chapter for a male", {
  codes <- c("O800", "O994", "N401", "N752", "E119", "I219")
  drawn <- fiktive:::sample_icd10_coherent(codes, 500, koen = rep(1L, 500))
  expect_false(any(substr(drawn, 1, 1) == "O"))
  expect_false(any(drawn %in% c("N752")))
})

test_that("sample_icd10_coherent never draws a male-only chapter for a female", {
  codes <- c("O800", "N401", "N752", "E119")
  drawn <- fiktive:::sample_icd10_coherent(codes, 500, koen = rep(2L, 500))
  expect_false(any(drawn == "N401"))
})

test_that("sample_icd10_coherent never draws a perinatal code for someone a year or older", {
  codes <- c("P071", "P966", "E119", "I219")
  drawn <- fiktive:::sample_icd10_coherent(codes, 500, age_years = rep(45, 500))
  expect_false(any(substr(drawn, 1, 1) == "P"))
})

test_that("sample_icd10_coherent allows perinatal codes for a newborn", {
  codes <- c("P071")
  drawn <- fiktive:::sample_icd10_coherent(codes, 20, age_years = rep(0, 20))
  expect_true(all(drawn == "P071"))
})

test_that("sample_icd10_coherent falls back to uniform with no koen/age info", {
  codes <- c("O800", "N401", "E119")
  drawn <- fiktive:::sample_icd10_coherent(codes, 300)
  expect_true(all(drawn %in% codes))
  expect_true(length(unique(drawn)) > 1L)
})

test_that("sample_icd10_coherent never leaves a row unfilled when a group's pool would be empty", {
  codes <- c("O800", "O994")
  drawn <- fiktive:::sample_icd10_coherent(codes, 50, koen = rep(1L, 50))
  expect_length(drawn, 50)
  expect_false(any(is.na(drawn)))
})

test_that("has_constraint() defaults to unset and with_constraints() restores it on exit", {
  expect_false(fiktive:::has_constraint("valid_diagnosis_sex_age"))
  fiktive:::with_constraints("valid_diagnosis_sex_age", {
    expect_true(fiktive:::has_constraint("valid_diagnosis_sex_age"))
  })
  expect_false(fiktive:::has_constraint("valid_diagnosis_sex_age"))
})

test_that("with_constraints() errors on an unknown constraint name", {
  expect_error(
    fiktive:::with_constraints("not_a_real_thing", NULL),
    "Unknown constraints"
  )
})

test_that("generate_register default (no constraints) does not gate koen/age_years", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 50L, seed = 5)
  # Smoke test: default generation still runs end-to-end with the
  # coherence-filter plumbing wired in but switched off.
  bef <- generate_register(
    "bef", pop, schema,
    as.Date("2008-01-01"), as.Date("2009-12-31"),
    seed = 5
  )
  expect_true(nrow(bef) > 0L)
})

test_that("lpr_diag never assigns a sex-incoherent icd10_sks chapter under valid_diagnosis_sex_age", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 400L, seed = 21)
  win_from <- as.Date("2008-01-01")
  win_to <- as.Date("2012-12-31")
  parent <- fiktive:::with_constraints("valid_diagnosis_sex_age", {
    generate_parent_contacts(
      pop, schema, schema$registers[["lpr_adm"]], win_from, win_to, seed = 21
    )
  })
  diag <- fiktive:::with_constraints("valid_diagnosis_sex_age", {
    generate_expand_from_parent(
      pop, schema, schema$registers[["lpr_diag"]], win_from, win_to, seed = 21
    )
  })
  skip_if(nrow(diag) == 0L, "no diagnosis rows drawn for this fixture/seed")
  koen <- pop$koen[match(parent$pnr[match(diag$recnum, parent$recnum)], pop$pnr)]
  num <- suppressWarnings(as.integer(substr(diag$c_diag, 3, 4)))
  o_on_male <- startsWith(diag$c_diag, "DO") & koen == 1L
  male_only_on_female <- substr(diag$c_diag, 2, 2) == "N" & num %in% 40:53 & koen == 2L
  female_only_on_male <- substr(diag$c_diag, 2, 2) == "N" & num %in% 70:98 & koen == 1L
  expect_false(any(o_on_male, na.rm = TRUE))
  expect_false(any(male_only_on_female, na.rm = TRUE))
  expect_false(any(female_only_on_male, na.rm = TRUE))
})
