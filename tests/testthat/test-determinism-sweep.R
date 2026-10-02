# Section 5 audit: same-seed-same-output is tested in scattered individual
# tests, but nothing runs EVERY implemented register through the same
# check systematically. Catches a future refactor that accidentally
# introduces an unseeded sample()/runif() call anywhere, rather than
# relying on whichever specific test happens to notice.

test_that("every implemented register is deterministic: same seed -> identical output, across seeds", {
  schema <- fixture_schema()
  pop <- generate_background_population(
    n = 60L, seed = 1L, schema = schema,
    birth_from = as.Date("1950-01-01"), birth_to = as.Date("2010-12-31")
  )
  from <- as.Date("2008-01-01")
  to <- as.Date("2015-12-31")

  register_ids <- names(schema$registers)
  tested <- character()
  skipped <- character()

  for (rid in register_ids) {
    seeds <- list(7L, 99L)
    outs <- lapply(seeds, function(s) {
      tryCatch(
        suppressWarnings(suppressMessages(generate_register(rid, pop, schema, from, to, seed = s))),
        error = function(e) e
      )
    })
    if (inherits(outs[[1]], "error") || inherits(outs[[2]], "error")) {
      skipped <- c(skipped, rid)
      next
    }
    tested <- c(tested, rid)

    # Same seed twice -> identical.
    repeat_a <- suppressWarnings(suppressMessages(generate_register(rid, pop, schema, from, to, seed = seeds[[1]])))
    repeat_b <- suppressWarnings(suppressMessages(generate_register(rid, pop, schema, from, to, seed = seeds[[1]])))
    expect_identical(repeat_a, repeat_b, info = sprintf("register '%s' not deterministic at seed %s", rid, seeds[[1]]))

    # Different seeds are allowed to differ, but must at least not error and
    # must both be well-formed (same columns) -- a stray unseeded call could
    # otherwise still coincidentally produce identical output and hide here.
    expect_identical(
      names(outs[[1]]), names(outs[[2]]),
      info = sprintf("register '%s' column set differs across seeds", rid)
    )
  }

  # Sanity check on the sweep itself: most registers should actually be
  # exercised, not silently skipped (a schema/dispatch regression could
  # otherwise make every register error and this test would still "pass").
  expect_true(
    length(tested) >= 20L,
    info = sprintf(
      "only %d/%d registers were actually tested (skipped: %s) -- sweep may be broken",
      length(tested), length(register_ids), paste(skipped, collapse = ", ")
    )
  )
})
