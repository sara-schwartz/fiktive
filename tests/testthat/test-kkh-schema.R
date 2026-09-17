test_that("load_registers_schema() always merges in the bundled KKH/KKHNG registers", {
  schema <- fixture_schema()
  kkh_ids <- grep("^kkh", names(schema$registers), value = TRUE)
  expect_true(length(kkh_ids) > 0L)
  expect_true("kkh_journal" %in% kkh_ids)
  expect_true("kkhng_admin" %in% kkh_ids)
})

test_that("bundled KKH registers have pnr, one_row_per person, and labelled columns", {
  schema <- fixture_schema()
  spec <- schema$registers[["kkh_journal"]]
  expect_equal(spec$one_row_per, "person")
  names_ <- vapply(spec$columns, function(c) c$name, character(1))
  expect_true("pnr" %in% names_)
  mdato_col <- spec$columns[[which(names_ == "mdato")]]
  expect_equal(mdato_col$label$en, "Date of participation")
})

test_that("kkh_journal/kkhng_lsq_general_final never disagree with pop koen/foed_dag", {
  # kqn/fsdato (kkh_journal) and fsdato/fsdato_c (kkhng_lsq_general_final)
  # are dropped entirely -- neither catalogue documents their real coding,
  # and keeping them would mean a second, independently-drawn value for the
  # same real-world fact fiktive already has from the population (pnr's own
  # koen/foed_dag), silently disagreeing with bef for the same person. See
  # kkh_register_ids() in R/schema.R.
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 6)
  kj <- generate_register(
    "kkh_journal", pop, schema,
    as.Date("1993-12-01"), as.Date("1997-05-31"),
    seed = 6
  )
  expect_false(any(c("kqn", "fsdato") %in% names(kj)))

  lg <- generate_register(
    "kkhng_lsq_general_final", pop, schema,
    as.Date("2015-03-01"), as.Date("2019-12-31"),
    seed = 6
  )
  expect_false(any(c("fsdato", "fsdato_c") %in% names(lg)))
  # koen (character) and sex (integer) are kept -- both documented well
  # enough (koen collides by name with pop$koen; sex's label states DST's
  # own 1=Male/2=Female coding) to map from pop$koen with no guessing.
  truth <- pop$koen[match(lg$pnr, pop$pnr)]
  expect_equal(as.integer(lg$koen), truth)
  expect_equal(lg$sex, truth)
})

test_that("no KKH/KKHNG register id collides with a DST register id", {
  schema <- fixture_schema()
  kkh_ids <- grep("^kkh", names(schema$registers), value = TRUE)
  dst_ids <- setdiff(names(schema$registers), kkh_ids)
  expect_length(intersect(kkh_ids, dst_ids), 0L)
})

test_that("generate_register() generates a KKH register exactly like a DST one", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 60L, seed = 4)
  kkh <- generate_register(
    "kkh_journal", pop, schema,
    as.Date("1993-12-01"), as.Date("1997-05-31"),
    seed = 4
  )
  expect_true("pnr" %in% names(kkh))
  expect_equal(nrow(kkh), length(unique(kkh$pnr)))
  expect_equal(max(table(kkh$pnr)), 1L)
})

test_that("generate_registers() handles a KKH id mixed with a DST id in one call", {
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 30L, seed = 4)
  out <- generate_registers(
    c("kkh_journal", "bef"),
    population = pop, schema = schema,
    from = as.Date("2008-01-01"), to = as.Date("2009-12-31"), seed = 4
  )
  expect_setequal(names(out), c("kkh_journal", "bef"))
  expect_true(nrow(out$bef) > 0L)
  joined <- dplyr::inner_join(out$kkh_journal, out$bef, by = "pnr", relationship = "many-to-many")
  expect_true(nrow(joined) > 0L)
})

test_that("codebook() works on a KKH register with no extra code", {
  schema <- fixture_schema()
  cb <- codebook(schema, "kkh_journal")
  expect_true(all(c("name", "label_da", "label_en", "type") %in% names(cb)))
  row <- cb[cb$name == "mdato", ]
  expect_equal(row$label_en, "Date of participation")
  expect_equal(row$type, "date")
})

test_that("person-grain registers with an explicit period cadence still ignore cadence internally", {
  # bef stays on the person_reference_date path -- confirms the person-grain
  # branch didn't change behaviour for existing snapshot registers.
  schema <- fixture_schema()
  pop <- tiny_pop(schema, n = 20L, seed = 5)
  bef <- generate_register("bef", pop, schema, as.Date("2008-01-01"), as.Date("2009-12-31"), seed = 5)
  expect_true(nrow(bef) > nrow(pop)) # multiple snapshots per person, unchanged
})
