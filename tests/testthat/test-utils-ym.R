test_that("YYYY-Qn coverage uses the quarter digit, not the letter Q", {
  expect_equal(ym_start("1995-Q2"), as.Date("1995-04-01"))
  expect_equal(ym_end("1995-Q2"), as.Date("1995-06-30"))
  expect_equal(ym_start("1995-Q1"), as.Date("1995-01-01"))
  expect_equal(ym_end("1995-Q4"), as.Date("1995-12-31"))
})
