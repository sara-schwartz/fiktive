# DCH/DCH-NG numeric/categorical columns used to hit the same generic
# fallback as any other schema-driven register (runif(0.5, 20), a bare
# 3-digit code) regardless of what they measured -- see
# R/generate-dch-values.R and R/generate-dch-nutrients.R for the ported
# ranges/domains and their citations.

test_that("DCH anthropometric/clinical columns are within plausible ranges", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 80L, seed = 51)
  dch <- generate_register("dch", pop, schema, as.Date("1993-12-01"), as.Date("1997-05-31"), seed = 51)
  skip_if(!nrow(dch), "no rows generated at this seed")
  expect_true(all(dch$stahqjde >= 148 & dch$stahqjde <= 200))
  # vaegt (weight) is derived from bmi * (stahqjde/100)^2 (see
  # derived_column(), R/generate-columns.R) rather than independently
  # curated, so its range is bmi's 17-45 times height's 1.48-2.00 m
  # squared, not a hand-picked band.
  expect_true(all(dch$vaegt >= 17 * 1.48^2 - 0.1 & dch$vaegt <= 45 * 2.00^2 + 0.1))
  expect_equal(round(dch$vaegt, 1), round(dch$bmi * (dch$stahqjde / 100)^2, 1))
  expect_true(all(dch$id >= 1 & dch$id <= 60000))
  expect_true(all(dch$center %in% c("KBH", "AAR")))
  expect_true(all(dch$ualbumin %in% 0:3))
  expect_true(all(dch$fedtbiop %in% 0:1))
})

test_that("food-group columns (vaegtc01-60) get per-group ranges, not one shared draw", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 52)
  dchng <- generate_register("dchng", pop, schema, as.Date("2015-03-01"), as.Date("2019-12-31"), seed = 52)
  skip_if(!nrow(dchng), "no rows generated at this seed")
  expect_true(all(dchng$vaegtc01 >= 0 & dchng$vaegtc01 <= 200))   # small group
  expect_true(all(dchng$vaegtc35 >= 0 & dchng$vaegtc35 <= 2500))  # beverage group, much wider
})

test_that("nutrient columns honour the _ffq/_ktsk/_tot suffix", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 53)
  dch <- generate_register("dch", pop, schema, as.Date("1993-12-01"), as.Date("1997-05-31"), seed = 53)
  skip_if(!nrow(dch), "no rows generated at this seed")
  expect_true(all(dch$avit_ffq >= 200 & dch$avit_ffq <= 3000))

  dchng <- generate_register("dchng", pop, schema, as.Date("2015-03-01"), as.Date("2019-12-31"), seed = 53)
  skip_if(!nrow(dchng), "no rows generated at this seed")
  expect_true(all(dchng$c16x0 >= 4 & dchng$c16x0 <= 35))   # fatty acid
  expect_true(all(dchng$isoleu >= 1500 & dchng$isoleu <= 6000)) # amino acid
})

test_that("FFQ item columns are ranged by id-shape family, not one shared draw", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 54)
  dch <- generate_register("dch", pop, schema, as.Date("1993-12-01"), as.Date("1997-05-31"), seed = 54)
  skip_if(!nrow(dch), "no rows generated at this seed")
  expect_true(all(dch$g03001 >= 0 & dch$g03001 <= 2500)) # beverage item (dch's own "gpd6" dataset)
  other <- grep("^g0", names(dch), value = TRUE)
  other <- other[!startsWith(other, "g030")]
  if (length(other)) {
    expect_true(all(dch[[other[[1]]]] >= 0 & dch[[other[[1]]]] <= 300)) # food item
  }

  dchng <- generate_register("dchng", pop, schema, as.Date("2015-03-01"), as.Date("2019-12-31"), seed = 54)
  skip_if(!nrow(dchng), "no rows generated at this seed")
  # dchng's own "ffq_gpd" dataset uses a different id shape entirely (never
  # overlaps with dch's g0300x-style ids -- confirmed against the source
  # catalogues), so the same dispatcher must still get these right with no
  # register-specific branching (there's only one "dchng" register now).
  if ("gmorgmaelk" %in% names(dchng)) {
    expect_true(all(dchng$gmorgmaelk >= 0 & dchng$gmorgmaelk <= 250)) # milk in a drink
  }
})

test_that("dch_value_noise() is scoped to dch/dchng registers only", {
  # stahqjde (height), not vaegt -- vaegt is derived from bmi/stahqjde in
  # derived_column() now, so it never reaches dch_value_noise() at all.
  expect_null(fiktive:::dch_value_noise(NULL, "stahqjde", "numeric", 5L))
  expect_null(fiktive:::dch_value_noise("bef", "stahqjde", "numeric", 5L))
  expect_false(is.null(fiktive:::dch_value_noise("dch", "stahqjde", "numeric", 5L)))
})

test_that("dch_range_source() is register-aware, not a flat name lookup", {
  # `cho` means something different on each cohort: carbohydrate (dch,
  # nutri6ny) vs. cholesterol (dchng, a Zhang et al. 2025 cited anchor) --
  # a flat name-keyed lookup would wrongly tag one as the other.
  expect_equal(dch_range_source("dch", "cho"), "clinical")
  expect_match(dch_range_source("dchng", "cho"), "^Zhang et al\\. 2025.*cholesterol")

  # One from each cohort's real cited set.
  expect_match(dch_range_source("dch", "bmi"), "^Lacoppidan et al\\. 2015.*BMI")
  expect_match(dch_range_source("dchng", "scbia01"), "^Zhang et al\\. 2025.*BMI")

  # Everything else -- including a column that exists on neither cohort,
  # and an unknown register_id -- is "clinical", not an error.
  expect_equal(dch_range_source("dch", "livvidde_not_a_real_column"), "clinical")
  expect_equal(dch_range_source("bef", "koen"), "clinical")
})

test_that("codebook()'s value_source column matches dch_range_source(), NA for DST registers", {
  schema <- fixture_schema()
  cb <- codebook(c("dch", "dchng", "bef"), schema)
  expect_true(all(is.na(cb$value_source[cb$register == "bef"])))

  dch_bmi <- cb[cb$register == "dch" & cb$name == "bmi", "value_source"][[1]]
  expect_equal(dch_bmi, dch_range_source("dch", "bmi"))

  # The register-collision case, exercised through the public codebook()
  # interface too, not just the internal function directly.
  dch_cho <- cb[cb$register == "dch" & cb$name == "cho", "value_source"][[1]]
  dchng_cho <- cb[cb$register == "dchng" & cb$name == "cho", "value_source"][[1]]
  expect_equal(dch_cho, "clinical")
  expect_match(dchng_cho, "cholesterol")
})
