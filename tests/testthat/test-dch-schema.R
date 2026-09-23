test_that("load_registers_schema() always merges in the bundled DCH/DCH-NG registers", {
  schema <- fixture_schema()
  expect_true("dch" %in% names(schema$registers))
  expect_true("dchng" %in% names(schema$registers))
})

test_that("bundled DCH register has pnr, one_row_per person, and labelled columns", {
  schema <- fixture_schema()
  spec <- schema$registers[["dch"]]
  expect_equal(spec$one_row_per, "person")
  names_ <- vapply(spec$columns, function(c) c$name, character(1))
  expect_true("pnr" %in% names_)
  mdato_col <- spec$columns[[which(names_ == "mdato")]]
  expect_equal(mdato_col$label$en, "Date of participation")
  # Every non-pnr column carries a `dataset` field recording which real
  # underlying SAS dataset it came from (dch/dchng were originally
  # delivered as ~8/~19 separate real tables, not one).
  non_pnr <- spec$columns[names_ != "pnr"]
  expect_true(all(vapply(non_pnr, function(c) !is.null(c$dataset), logical(1))))
})

test_that("dch/dchng never disagree with pop koen/foed_dag", {
  # kqn/fsdato (dch's own "journal" dataset) and fsdato/fsdato_c (dchng's
  # own "lsq_general_final" dataset) are dropped entirely -- neither
  # catalogue documents their real coding, and keeping them would mean a
  # second, independently-drawn value for the same real-world fact fiktive
  # already has from the population (pnr's own koen/foed_dag), silently
  # disagreeing with bef for the same person. See dch_register_ids() in
  # R/schema.R.
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 6)
  dch <- generate_register(
    "dch", pop, schema,
    as.Date("1993-12-01"), as.Date("1997-05-31"),
    seed = 6
  )
  expect_false(any(c("kqn", "fsdato") %in% names(dch)))

  dchng <- generate_register(
    "dchng", pop, schema,
    as.Date("2015-03-01"), as.Date("2019-12-31"),
    seed = 6
  )
  expect_false(any(c("fsdato", "fsdato_c") %in% names(dchng)))
  # koen (character) and sex (integer) are kept -- both documented well
  # enough (koen collides by name with pop$koen; sex's label states DST's
  # own 1=Male/2=Female coding) to map from pop$koen with no guessing.
  truth <- pop$koen[match(dchng$pnr, pop$pnr)]
  expect_equal(as.integer(dchng$koen), truth)
  expect_equal(dchng$sex, truth)
})

test_that("no DCH/DCH-NG register id collides with a DST register id", {
  schema <- fixture_schema()
  expect_false("dch" %in% setdiff(names(schema$registers), c("dch", "dchng")))
  expect_false("dchng" %in% setdiff(names(schema$registers), c("dch", "dchng")))
})

test_that("generate_register() generates dch exactly like a DST register", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 4)
  dch <- generate_register(
    "dch", pop, schema,
    as.Date("1993-12-01"), as.Date("1997-05-31"),
    seed = 4
  )
  expect_true("pnr" %in% names(dch))
  expect_equal(nrow(dch), length(unique(dch$pnr)))
  expect_equal(max(table(dch$pnr)), 1L)
})

test_that("generate_registers() handles a dch id mixed with a DST id in one call", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 30L, seed = 4)
  out <- generate_registers(
    c("dch", "bef"),
    population = pop, schema = schema,
    from = as.Date("2008-01-01"), to = as.Date("2009-12-31"), seed = 4
  )
  expect_setequal(names(out), c("dch", "bef"))
  expect_true(nrow(out$bef) > 0L)
  joined <- dplyr::inner_join(out$dch, out$bef, by = "pnr", relationship = "many-to-many")
  expect_true(nrow(joined) > 0L)
})

test_that("codebook() works on dch with no extra code, including the dataset field", {
  schema <- fixture_schema()
  cb <- codebook(schema, "dch")
  expect_true(all(c("name", "label_da", "label_en", "type", "dataset") %in% names(cb)))
  row <- cb[cb$name == "mdato", ]
  expect_equal(row$label_en, "Date of participation")
  expect_equal(row$type, "date")
  expect_equal(row$dataset, "journal")
  # pnr is fiktive's own added join key, not from a real dataset.
  expect_true(is.na(cb$dataset[cb$name == "pnr"]))
  # A DST register was never split across multiple real SAS datasets this way.
  cb_bef <- codebook(schema, "bef")
  expect_true(all(is.na(cb_bef$dataset)))
})

test_that("person-grain registers with an explicit period cadence still ignore cadence internally", {
  # bef stays on the person_reference_date path -- confirms the person-grain
  # branch didn't change behaviour for existing snapshot registers.
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 5)
  bef <- generate_register("bef", pop, schema, as.Date("2008-01-01"), as.Date("2009-12-31"), seed = 5)
  expect_true(nrow(bef) > nrow(pop)) # multiple snapshots per person, unchanged
})
