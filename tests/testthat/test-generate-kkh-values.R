# KKH/KKHNG numeric/categorical columns used to hit the same generic
# fallback as any other schema-driven register (runif(0.5, 20), a bare
# 3-digit code) regardless of what they measured -- see
# R/generate-kkh-values.R and R/generate-kkh-nutrients.R for the ported
# ranges/domains and their citations.

test_that("KKH anthropometric/clinical columns are within plausible ranges", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 80L, seed = 51)
  kj <- generate_register("kkh_journal", pop, schema, as.Date("1993-12-01"), as.Date("1997-05-31"), seed = 51)
  skip_if(!nrow(kj), "no rows generated at this seed")
  expect_true(all(kj$stahqjde >= 148 & kj$stahqjde <= 200))
  expect_true(all(kj$vaegt >= 42 & kj$vaegt <= 145))
  expect_true(all(kj$id >= 1 & kj$id <= 60000))
  expect_true(all(kj$center %in% c("KBH", "AAR")))
  expect_true(all(kj$ualbumin %in% 0:3))
  expect_true(all(kj$fedtbiop %in% 0:1))
})

test_that("food-group columns (vaegtc01-60) get per-group ranges, not one shared draw", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 52)
  v <- generate_register("kkhng_vaegtc", pop, schema, as.Date("2015-03-01"), as.Date("2019-12-31"), seed = 52)
  skip_if(!nrow(v), "no rows generated at this seed")
  expect_true(all(v$vaegtc01 >= 0 & v$vaegtc01 <= 200))   # small group
  expect_true(all(v$vaegtc35 >= 0 & v$vaegtc35 <= 2500))  # beverage group, much wider
})

test_that("nutrient columns honour the _ffq/_ktsk/_tot suffix", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 53)
  vit <- generate_register("kkh_vitmin6_v2", pop, schema, as.Date("1993-12-01"), as.Date("1997-05-31"), seed = 53)
  skip_if(!nrow(vit), "no rows generated at this seed")
  expect_true(all(vit$avit_ffq >= 200 & vit$avit_ffq <= 3000))

  nutri <- generate_register("kkhng_nutri", pop, schema, as.Date("2015-03-01"), as.Date("2019-12-31"), seed = 53)
  skip_if(!nrow(nutri), "no rows generated at this seed")
  expect_true(all(nutri$c16x0 >= 4 & nutri$c16x0 <= 35))   # fatty acid
  expect_true(all(nutri$isoleu >= 1500 & nutri$isoleu <= 6000)) # amino acid
})

test_that("FFQ item columns are ranged by id-shape family, not one shared draw", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 54)
  gpd <- generate_register("kkh_gpd6", pop, schema, as.Date("1993-12-01"), as.Date("1997-05-31"), seed = 54)
  skip_if(!nrow(gpd), "no rows generated at this seed")
  expect_true(all(gpd$g03001 >= 0 & gpd$g03001 <= 2500)) # beverage item
  other <- grep("^g0", names(gpd), value = TRUE)
  other <- other[!startsWith(other, "g030")]
  if (length(other)) {
    expect_true(all(gpd[[other[[1]]]] >= 0 & gpd[[other[[1]]]] <= 300)) # food item
  }
})

test_that("kkh_value_noise() is scoped to KKH/KKHNG registers only", {
  expect_null(fiktive:::kkh_value_noise(NULL, "vaegt", "numeric", 5L))
  expect_null(fiktive:::kkh_value_noise("bef", "vaegt", "numeric", 5L))
  expect_false(is.null(fiktive:::kkh_value_noise("kkh_journal", "vaegt", "numeric", 5L)))
})
