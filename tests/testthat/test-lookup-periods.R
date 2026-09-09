test_that("lookup_keys_at honours c_dodsmaade periods (code 4 / 6 / 9 eras)", {
  schema <- fixture_schema()
  cs <- schema$code_systems$c_dodsmaade
  expect_true(!is.null(cs$periods))
  # Static lookup is the post-1990 collapsed set (no 6/9).
  static <- lookup_keys(cs)
  expect_true(all(c("1", "2", "3", "4", "5") %in% static))
  expect_false("6" %in% static)
  expect_false("9" %in% static)

  pre <- lookup_keys_at(cs, when = as.Date("1985-06-15"))
  expect_true(all(c("1", "2", "4", "6", "9") %in% pre))
  expect_false("3" %in% pre)
  expect_false("5" %in% pre)

  post <- lookup_keys_at(cs, when = as.Date("1995-06-15"))
  expect_true(all(c("1", "2", "3", "4", "5") %in% post))
  expect_false("6" %in% post)
  expect_false("9" %in% post)
})

test_that("c_dodsmaade_2002 is a distinct set (code 1 = Voldshandling)", {
  schema <- fixture_schema()
  cs <- schema$code_systems$c_dodsmaade_2002
  keys <- lookup_keys_at(cs, when = as.Date("2010-01-01"))
  expect_true(all(c("0", "1", "2", "4", "5") %in% keys))
  # Must not silently reuse the pre-2002 Natural-death=1 set.
  expect_false("3" %in% keys)
  expect_identical(cs$lookup[["1"]]$da, "Voldshandling")
  expect_identical(
    schema$code_systems$c_dodsmaade$lookup[["1"]]$da,
    "Naturlig dod"
  )
})

test_that("sample_lookup_keys date-filters across mixed event years", {
  schema <- fixture_schema()
  cs <- schema$code_systems$c_dodsmaade
  when <- as.Date(c("1985-01-01", "1985-01-01", "1995-01-01", "1995-01-01"))
  set.seed(7)
  drawn <- sample_lookup_keys(cs, "c_dodsmaade", length(when), when = when)
  expect_equal(length(drawn), 4L)
  expect_true(all(drawn[1:2] %in% c("1", "2", "4", "6", "9")))
  expect_true(all(drawn[3:4] %in% c("1", "2", "3", "4", "5")))
})

test_that("pattype periods date-filter LPR sheet codes (1 ends 2001; 3 ends 2013)", {
  schema <- fixture_schema()
  cs <- schema$code_systems$pattype
  expect_true(!is.null(cs$periods))

  y1980 <- lookup_keys_at(cs, when = as.Date("1980-06-15"))
  expect_true(all(c("0", "1", "2") %in% y1980))
  expect_false("3" %in% y1980)

  y1995 <- lookup_keys_at(cs, when = as.Date("1995-06-15"))
  expect_true(all(c("0", "1", "2", "3") %in% y1995))

  y2010 <- lookup_keys_at(cs, when = as.Date("2010-06-15"))
  expect_true(all(c("0", "2", "3") %in% y2010))
  expect_false("1" %in% y2010) # Deldoegnspatient ends 2001-12-31

  y2015 <- lookup_keys_at(cs, when = as.Date("2015-06-15"))
  expect_true(all(c("0", "2") %in% y2015))
  expect_false("1" %in% y2015)
  expect_false("3" %in% y2015) # Skadestue ends 2013-12-31

  # Periodised empty must not collapse to static 0-3.
  set.seed(11)
  when <- as.Date(c("2010-01-01", "2010-01-01", "2015-01-01", "2015-01-01"))
  drawn <- sample_lookup_keys(cs, "pattype", length(when), when = when)
  expect_true(all(drawn[1:2] %in% c("0", "2", "3")))
  expect_true(all(drawn[3:4] %in% c("0", "2")))
  expect_false(any(drawn[3:4] == "3"))
})

test_that("periodised lookup_keys_at does not fall back to static when empty", {
  schema <- fixture_schema()
  cs <- schema$code_systems$pattype
  # Far future: only codes with open-ended valid_to remain (0, 2).
  far <- lookup_keys_at(cs, when = as.Date("2099-01-01"))
  expect_true(all(far %in% c("0", "2")))
  expect_false("1" %in% far)
  expect_false("3" %in% far)
})
