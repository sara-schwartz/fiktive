# Tier 1 (t_psyk_sksopr/sksube -- same shape as the already-implemented
# lpr_sksopr/lpr_sksube) and Tier 2 (lpr_adm's and t_psyk_adm's other real
# child tables: operations, outpatient visits, waiting-period tracking,
# accident codes, discharge destination, birth records) registers, added
# as a batch once the generic expand_from_parent/event_from_person
# machinery was confirmed to already handle this shape -- see
# _ignore/plan.md section 2 for the tier breakdown.

from <- as.Date("2008-01-01")
to <- as.Date("2012-12-31")

test_that("lpr_adm's new expand_from_parent children generate with real referential integrity", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 300L, seed = 60)
  out <- generate_registers(
    c("lpr_adm", "lpr_afl", "lpr_bes", "lpr_opr", "lpr_pas", "lpr_ulyk", "lpr_vente"),
    population = pop, schema = schema, from = from, to = to, seed = 60
  )
  for (child in c("lpr_afl", "lpr_bes", "lpr_opr", "lpr_pas", "lpr_ulyk", "lpr_vente")) {
    skip_if(!nrow(out[[child]]), paste("no rows generated for", child, "at this seed"))
    expect_true(all(out[[child]]$recnum %in% out$lpr_adm$recnum), info = child)
  }
})

test_that("t_psyk_adm's new expand_from_parent children generate with real referential integrity", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 300L, seed = 61)
  out <- generate_registers(
    c(
      "t_psyk_adm", "t_psyk_afl", "t_psyk_opr", "t_psyk_pas", "t_psyk_pers",
      "t_psyk_sksopr", "t_psyk_sksube", "t_psyk_ulyk", "t_psyk_vente"
    ),
    population = pop, schema = schema, from = from, to = to, seed = 61
  )
  for (child in c(
    "t_psyk_afl", "t_psyk_opr", "t_psyk_pas", "t_psyk_pers",
    "t_psyk_sksopr", "t_psyk_sksube", "t_psyk_ulyk", "t_psyk_vente"
  )) {
    skip_if(!nrow(out[[child]]), paste("no rows generated for", child, "at this seed"))
    expect_true(all(out[[child]]$recnum %in% out$t_psyk_adm$recnum), info = child)
  }
})

test_that("t_psyk_sksopr/sksube draw real SKS codes, same kind mapping as lpr_sksopr/sksube", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 300L, seed = 62)
  out <- generate_registers(
    c("t_psyk_adm", "t_psyk_sksopr", "t_psyk_sksube"),
    population = pop, schema = schema, from = from, to = to, seed = 62
  )
  # t_psyk_sksopr is the "opr" kind (surgical), same as lpr_sksopr --
  # real SKS surgical codes are K-prefixed.
  skip_if(!nrow(out$t_psyk_sksopr), "no rows generated for t_psyk_sksopr at this seed")
  expect_true(all(grepl("^K", out$t_psyk_sksopr$c_opr)))
  expect_true(all(out$t_psyk_sksopr$recnum %in% out$t_psyk_adm$recnum))
  # t_psyk_sksube is the "pro_und" kind (non-surgical procedures/exams),
  # same as lpr_sksube -- no single shared prefix, just real SKS codes.
  skip_if(!nrow(out$t_psyk_sksube), "no rows generated for t_psyk_sksube at this seed")
  expect_true(all(nzchar(out$t_psyk_sksube$c_opr)))
  expect_true(all(out$t_psyk_sksube$recnum %in% out$t_psyk_adm$recnum))
})

test_that("v_ominut/v_otime are curated (0-59/0-23) on the new operation-time child tables, not generic noise", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 300L, seed = 63)
  out <- generate_registers(
    c("lpr_adm", "lpr_afl", "t_psyk_adm", "t_psyk_afl", "t_psyk_sksopr"),
    population = pop, schema = schema, from = from, to = to, seed = 63
  )
  for (nm in c("lpr_afl", "t_psyk_afl", "t_psyk_sksopr")) {
    tbl <- out[[nm]]
    skip_if(!nrow(tbl), paste("no rows generated for", nm, "at this seed"))
    expect_true(all(tbl$v_ominut >= 0 & tbl$v_ominut <= 59), info = nm)
    expect_true(all(tbl$v_otime >= 0 & tbl$v_otime <= 23), info = nm)
  }
})

test_that("new event_from_person registers (t_psyk_psykio/udtilsgh, lpr_foedsler/udtilsgh) generate with unique, non-NA recnum", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 300L, seed = 64)
  for (id in c("t_psyk_psykio", "t_psyk_udtilsgh", "lpr_foedsler", "lpr_udtilsgh")) {
    out <- suppressWarnings(generate_register(id, pop, schema, from, to, seed = 64))
    skip_if(!nrow(out), paste("no rows generated for", id, "at this seed"))
    expect_false(anyNA(out$recnum), info = id)
    expect_equal(length(unique(out$recnum)), nrow(out), info = id)
  }
})

test_that("lpr_foedsler's newborn/visit-count columns are curated, not the generic 0.5-20 fallback", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 300L, seed = 65)
  out <- suppressWarnings(generate_register("lpr_foedsler", pop, schema, from, to, seed = 65))
  skip_if(!nrow(out), "no rows generated for lpr_foedsler at this seed")
  expect_true(all(out$v_langde >= 35 & out$v_langde <= 58))
  expect_true(all(out$v_vagt >= 400 & out$v_vagt <= 5500))
  expect_true(all(out$v_paritet >= 0 & out$v_paritet <= 8))
  expect_true(all(out$v_jmbes >= 0 & out$v_jmbes <= 15))
  expect_true(all(out$v_lbes >= 0 & out$v_lbes <= 15))
  expect_true(all(out$v_spbes >= 0 & out$v_spbes <= 10))
})

test_that("an expand_from_parent register not in .IMPLEMENTED_EXPAND still errors 'not implemented yet'", {
  # Regression guard for the whitelist gate itself, now that every real
  # expand_from_parent register in the schema is implemented -- see
  # test-schema.R's "expand-from-parent register is not implemented yet"
  # for the same check using a cloned fake id.
  schema <- fixture_schema()
  schema$registers[["fake_expand_register_2"]] <- schema$registers[["lpr_opr"]]
  schema$registers[["fake_expand_register_2"]]$id <- "fake_expand_register_2"
  pop <- tiny_pop(schema, n = 10L, seed = 66)
  expect_error(
    generate_register("fake_expand_register_2", pop, schema, from, to, seed = 66),
    "not implemented yet"
  )
})
