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
