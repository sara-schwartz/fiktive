# Column draw / code-system resolve (loaded with generate-columns.R).

draw_independent_column <- function(col, n, schema, register_id = NULL, when = NULL,
                                     koen = NULL, age_years = NULL,
                                     lprindberetningssystem = NULL) {
  type <- col$type %||% "character"
  role <- col$role
  name <- as.character(col$name %||% col$id)
  if (n == 0L) {
    return(na_of_type(type, 0L))
  }
  if (identical(name, "atc") || identical(as.character(col$id %||% ""), "atc")) {
    # Cross-check values_from.kind=package against PLAN ATC lock before sampling.
    cs_atc <- schema$code_systems[["atc"]]
    if (!is.null(cs_atc)) {
      honour_values_from_or_gap(cs_atc, "atc", name)
    }
    return(sample_atc_codes(n))
  }
  # lab_dm_forsker analysiscode: HARD GAP (no CS/values_from). PLAN: LabTerm /
  # published NPU-DNK — never typed_noise / homemade lists.
  if (identical(name, "analysiscode") || identical(as.character(col$id %||% ""), "analysiscode")) {
    return(sample_labterm_codes(n))
  }
  # Unpublished value set: character code with no code_system (e.g. borger_koen).
  # registers-guide checked four separate DST/Sundhedsdatastyrelsen sources
  # and none publish one -- not a missing wiring (unlike a values_from.kind =
  # package gap), a genuine absence. NA rather than a hard stop, so the rest
  # of the register (and any other column) isn't blocked by this one gap; a
  # visible warning() so it isn't silent, since it's still a real limitation
  # worth knowing about, not a value fiktive is guessing at.
  if (is.null(col$code_system) && identical(name, "borger_koen")) {
    warning(
      "borger_koen has no documented value set anywhere in the schema ",
      "(registers-guide checked DST's variable list, Sundhedsdatastyrelsen's ",
      "LPR3_F guidance, the LPR3 reporting guidance, and esundhed's LPR docs -- ",
      "none publish one). Filled with NA rather than guessed or mapped from ",
      "BEF koen (a different field, not verified equivalent).",
      call. = FALSE
    )
    return(na_of_type(type, n))
  }
  if (is.null(col$code_system) && is.null(col$previous_code_system)) {
    return(typed_noise(type, n, role = role, name = name))
  }

  # Per-row previous_code_system (e.g. icd8 until 1993 on lpr_diag / dodsaars).
  cs_ids <- resolve_code_system_ids(col, n, when)
  unique_ids <- unique(cs_ids)
  if (length(unique_ids) == 1L) {
    return(draw_from_code_system(
      unique_ids[[1]], col, n, schema, register_id = register_id, type = type, role = role, name = name,
      when = when, koen = koen, age_years = age_years,
      lprindberetningssystem = lprindberetningssystem
    ))
  }
  out <- vector(mode = mode_for_type(type), length = n)
  for (cid in unique_ids) {
    idx <- which(cs_ids == cid)
    out[idx] <- draw_from_code_system(
      cid, col, length(idx), schema, register_id = register_id, type = type, role = role, name = name,
      when = when[idx],
      koen = if (is.null(koen)) NULL else koen[idx],
      age_years = if (is.null(age_years)) NULL else age_years[idx],
      lprindberetningssystem = if (is.null(lprindberetningssystem)) NULL else lprindberetningssystem[idx]
    )
  }
  coerce_schema_type(out, type)
}

mode_for_type <- function(type) {
  switch(
    type %||% "character",
    integer = "integer",
    numeric = "numeric",
    "character"
  )
}

resolve_code_system_ids <- function(col, n, when) {
  primary <- as.character(col$code_system %||% "")
  prev <- col$previous_code_system
  if (is.null(prev) || is.null(when) || !length(when) || n == 0L) {
    return(rep(primary, n))
  }
  prev_id <- as.character(prev$id %||% "")
  until <- prev$until
  if (!nzchar(prev_id) || is.null(until)) {
    return(rep(primary, n))
  }
  until_y <- as.integer(until)[[1]]
  years <- lubridate::year(as.Date(when))
  ifelse(!is.na(years) & years <= until_y, prev_id, primary)
}


# Real population by municipality (kom code), DST Statbank table FOLK1A --
# same table kom.yaml's own provenance already cites for the current 99-area
# list -- variable OMRÅDE, KØN=total, ALDER=total, CIVILSTAND=total,
# 2026Q3 (fetched 2026-09-10). Used to make default `kom` sampling reflect
# real municipality sizes instead of drawing Læsø (825, pop. 1,655) as often
# as Copenhagen (101, pop. 670,389). A snapshot, not a live figure -- do not
# expect it to track future population change.
.KOM_POPULATION_WEIGHTS <- c(
  "101" = 670389L, "147" = 105947L, "151" = 53962L, "153" = 40985L, "155" = 14482L,
  "157" = 75241L, "159" = 70869L, "161" = 25987L, "163" = 32107L, "165" = 29575L,
  "167" = 54234L, "169" = 60843L, "173" = 58671L, "175" = 45317L, "183" = 24968L,
  "185" = 44252L, "187" = 18768L, "190" = 43030L, "201" = 26434L, "210" = 42543L,
  "217" = 64460L, "219" = 55472L, "223" = 25326L, "230" = 58381L, "240" = 46514L,
  "250" = 47930L, "253" = 54262L, "259" = 64268L, "260" = 31827L, "265" = 93142L,
  "269" = 25081L, "270" = 42080L, "306" = 31947L, "316" = 75299L, "320" = 38169L,
  "326" = 47822L, "329" = 36098L, "330" = 80856L, "336" = 23990L, "340" = 31027L,
  "350" = 30108L, "360" = 38306L, "370" = 85276L, "376" = 58984L, "390" = 44823L,
  "400" = 38651L, "410" = 40773L, "411" = 91L, "420" = 40224L, "430" = 52268L,
  "440" = 24340L, "450" = 32477L, "461" = 213140L, "479" = 60075L, "480" = 29124L,
  "482" = 11804L, "492" = 5730L, "510" = 55119L, "530" = 27276L, "540" = 73874L,
  "550" = 36172L, "561" = 114824L, "563" = 3322L, "573" = 49454L, "575" = 42671L,
  "580" = 58249L, "607" = 53115L, "615" = 98999L, "621" = 96140L, "630" = 123947L,
  "657" = 90910L, "661" = 59331L, "665" = 18505L, "671" = 20100L, "706" = 44559L,
  "707" = 36355L, "710" = 50028L, "727" = 24448L, "730" = 100921L, "740" = 103293L,
  "741" = 3633L, "746" = 66617L, "751" = 378270L, "756" = 43484L, "760" = 55205L,
  "766" = 48813L, "773" = 19321L, "779" = 43913L, "787" = 42573L, "791" = 98104L,
  "810" = 36639L, "813" = 57428L, "820" = 35546L, "825" = 1655L, "840" = 31369L,
  "846" = 41565L, "849" = 37890L, "851" = 226404L, "860" = 62909L
)

# kom.yaml's own lookup: is current-era only (post-2007 municipalities) --
# the full pre/post-2007 classification mixes eras with no validity dates
# (values_from.mixes_eras: true) and reused codes (707, 849) meant something
# else before the reform. No verified pre-2007 mapping exists in the schema,
# so a row dated before the reform gets NA rather than an anachronistic
# current-day code. Always on, not gated behind a constraint -- this is
# avoiding an actively wrong value, not adding realism. Fiktive-side floor,
# not sourced from the schema (kom.yaml has no `periods:` of its own).
.KOM_REFORM_DATE <- as.Date("2007-01-01")

# kom is drawn per-row here (unlike sample_cs_keys' single sample() call)
# because whether a row even qualifies for the current-era lookup depends on
# that row's own date -- pre-reform rows get NA, post-reform rows get the
# normal (optionally population-weighted) draw.
sample_kom_keys_era_aware <- function(keys, n, when) {
  when <- as.Date(when)
  if (length(when) == 1L && n > 1L) {
    when <- rep(when, n)
  }
  post_reform <- !is.na(when) & when >= .KOM_REFORM_DATE
  n_pre <- sum(!post_reform)
  if (n_pre > 0L) {
    warning(
      sprintf(
        "kom is NA for %d row(s) dated before the 2007-01-01 municipal reform: ",
        n_pre
      ),
      "no verified pre-reform municipality code list exists in the schema ",
      "(the mixed-era source has no validity dates and reused codes meaning ",
      "something else pre-reform). Filled with NA rather than guessed or ",
      "backdated from the current 99-municipality list.",
      call. = FALSE
    )
  }
  out <- rep(NA_character_, n)
  n_post <- sum(post_reform)
  if (n_post > 0L) {
    out[post_reform] <- sample_cs_keys(keys, n_post, "kom")
  }
  out
}

# Order-of-magnitude only, reasoned from coverage windows and DARTER-team-
# confirmed facts (registers-guide code-systems/lprindberetningssystem.yaml
# provenance), NOT counted from a real delivery -- nobody has run
# count(lprindberetningssystem) on an actual DARTER extract. LPR3 weighted
# above its raw ~78% time-share (2019-03 to present, of lpr_a_kontakt's full
# 2017-present span) because it also reports at finer grain (a diagnosis
# per visit vs LPR2's per course). LPR1 near-zero: named as a possibility in
# dst-pitfalls.qmd pitfall 11, but lpr_a_kontakt only reaches back to 2017,
# decades after LPR1. Replace with the real split once someone has one.
.LPRINDBERETNINGSSYSTEM_WEIGHTS <- c(
  "LPR3" = 80, "LPR2" = 15, "MiniPAS" = 3, "LPR1" = 0.5
)

# Draw from a resolved set of lookup keys. civst never emits "D" (dead) for
# a living resident -- always on, a structural-validity fix, not "realism".
# kom weighted by real municipality population ("weighted_municipality"),
# lprindberetningssystem by the reasoned split above
# ("weighted_lprindberetningssystem"), instead of drawn uniformly -- both
# opt-in constraints (see with_constraints()); default is the original
# uniform draw. Falls back to uniform if a key is missing from the weight
# table (e.g. a future schema addition), rather than erroring.
sample_cs_keys <- function(keys, n, cs_id) {
  if (identical(cs_id, "civst")) {
    keys <- setdiff(keys, "D")
  }
  if (identical(cs_id, "kom") && has_constraint("weighted_municipality")) {
    w <- .KOM_POPULATION_WEIGHTS[keys]
    if (!anyNA(w)) {
      return(sample(keys, n, replace = TRUE, prob = as.numeric(w)))
    }
  }
  if (identical(cs_id, "lprindberetningssystem") && has_constraint("weighted_lprindberetningssystem")) {
    w <- .LPRINDBERETNINGSSYSTEM_WEIGHTS[keys]
    if (!anyNA(w)) {
      return(sample(keys, n, replace = TRUE, prob = as.numeric(w)))
    }
  }
  sample(keys, n, replace = TRUE)
}

# Sample from static or periodised lookup. Returns NULL when no keys available
# (caller falls through to catalogue / typed_noise). Never merges distinct
# code-system ids (c_dodsmaade vs c_dodsmaade_2002 stay separate files).
sample_lookup_keys <- function(cs, cs_id, n, when = NULL) {
  n <- as.integer(n)[[1]]
  if (n == 0L) {
    return(character())
  }
  periods <- cs$periods
  use_periods <- !is.null(periods) && length(periods) && !is.null(when) && length(when)
  if (!use_periods) {
    keys <- lookup_keys(cs)
    if (is.null(keys) || !length(keys)) {
      return(NULL)
    }
    if (identical(cs_id, "kom") && !is.null(when) && length(when)) {
      return(sample_kom_keys_era_aware(keys, n, when))
    }
    return(sample_cs_keys(keys, n, cs_id))
  }
  when <- as.Date(when)
  if (length(when) == 1L && n > 1L) {
    when <- rep(when, n)
  }
  if (length(when) != n) {
    keys <- lookup_keys_at(cs, when = when[[1]])
    if (is.null(keys) || !length(keys)) {
      return(NULL)
    }
    return(sample_cs_keys(keys, n, cs_id))
  }
  out <- character(n)
  for (d in unique(when)) {
    idx <- which(when == d)
    keys <- lookup_keys_at(cs, when = d)
    # Periods present: empty means no code valid on that date - do not invent
    # from the era-collapsed static lookup.
    if (is.null(keys) || !length(keys)) {
      return(NULL)
    }
    out[idx] <- sample_cs_keys(keys, length(idx), cs_id)
  }
  out
}

draw_from_code_system <- function(cs_id, col, n, schema, register_id, type, role, name, when = NULL,
                                   koen = NULL, age_years = NULL,
                                   lprindberetningssystem = NULL) {
  cs_id <- as.character(cs_id %||% "")
  if (!nzchar(cs_id)) {
    return(typed_noise(type, n, role = role, name = name))
  }
  cs <- schema$code_systems[[cs_id]]
  if (is.null(cs)) {
    schema_gap(
      sprintf("code system '%s' for column '%s'", cs_id, name),
      "a matching file in code-systems/"
    )
  }
  honour_values_from_or_gap(cs, cs_id, name)

  # kind:none must not use invented fixture lookups as SoT (hfaudd soft-warn).
  vf_kind <- as.character((cs$values_from$kind) %||% "")
  if (!identical(vf_kind, "none")) {
    drawn <- sample_lookup_keys(cs, cs_id, n, when = when)
    if (!is.null(drawn)) {
      return(coerce_schema_type(drawn, type))
    }
  }

  if (identical(cs_id, "icd10")) {
    return(coerce_schema_type(sample_icd10_who_codes(n, koen = koen, age_years = age_years), type))
  }
  if (identical(cs_id, "icd10_sks")) {
    return(draw_sks_dia_codes(name, n, type, register_id, koen = koen, age_years = age_years))
  }
  if (identical(cs_id, "icd8")) {
    schema_gap(
      sprintf("ICD-8 codes for column '%s' (values_from kind none / no catalogue)", name),
      "a published ICD-8 list in the schema, or leave previous_code_system rows as SCHEMA GAP"
    )
  }
  if (identical(cs_id, "kont_type")) {
    drawn <- draw_kont_type_codes(n, lprindberetningssystem)
    return(coerce_schema_type(drawn, type))
  }
  if (identical(cs_id, "sks")) {
    kind <- sks_kind_for(cs_id, register_id, name)
    drawn <- sample_sks_codes(n, kind, cs)
    return(coerce_schema_type(drawn, type))
  }
  if (identical(cs_id, "atc")) {
    return(sample_atc_codes(n))
  }
  typed_noise(type, n, role = role, name = name, code_system = cs_id, cs = cs)
}

# PLAN-locked package catalogues (do not invent). Soft-warn fix: cross-check
# values_from.kind=package against these before the hardcoded draw path runs.
.LOCKED_PACKAGE_CATALOGUES <- list(
  icd10 = list(
    packages = c("codeCollection"),
    dataset = "ICD10Koodit"
  ),
  icd10_sks = list(
    packages = c("sksr"),
    dataset = "SKS_labels",
    filter = list(column = "Prefix", value = "dia")
  ),
  atc = list(
    packages = c("codeCollection"),
    dataset = "ATCKoodit"
  ),
  sks = list(
    packages = c("sksr"),
    dataset = "SKS_labels"
  ),
  kont_type = list(
    packages = c("sksr"),
    dataset = "SKS_labels",
    filter = list(column = "Prefix", value = "adm")
  )
)

values_from_candidate_names <- function(candidates) {
  if (is.null(candidates)) {
    return(character())
  }
  if (is.character(candidates)) {
    return(as.character(candidates))
  }
  vapply(as.list(candidates), function(x) {
    if (is.null(x)) {
      return(NA_character_)
    }
    if (is.character(x) || is.numeric(x)) {
      return(as.character(x)[[1]])
    }
    if (is.list(x)) {
      return(as.character(x$name %||% x$package %||% x$id %||% "")[[1]])
    }
    as.character(x)[[1]]
  }, character(1))
}

package_values_from_matches_lock <- function(vf, lock) {
  cands <- values_from_candidate_names(vf$candidates)
  cands <- cands[!is.na(cands) & nzchar(cands)]
  if (!any(lock$packages %in% cands)) {
    return(FALSE)
  }
  dataset <- as.character(vf$dataset %||% "")
  if (!identical(dataset, lock$dataset)) {
    return(FALSE)
  }
  if (!is.null(lock$filter)) {
    filt <- vf$filter
    if (is.null(filt)) {
      return(FALSE)
    }
    col <- as.character(filt$column %||% "")
    val <- as.character(filt$value %||% "")
    if (!identical(col, lock$filter$column) || !identical(val, lock$filter$value)) {
      return(FALSE)
    }
  }
  TRUE
}

honour_values_from_or_gap <- function(cs, cs_id, name) {
  vf <- cs$values_from
  if (is.null(vf)) {
    return(invisible(NULL))
  }
  kind <- as.character(vf$kind %||% "")
  if (identical(kind, "none")) {
    # No published machine-readable catalogue (live hfaudd / icd8). Draw path
    # SCHEMA GAPs clinical gaps (icd8) or uses typed_noise for non-clinical
    # structural ids (hfaudd). Never treat a fixture lookup as SoT under kind:none.
    return(invisible(NULL))
  }
  if (identical(kind, "package")) {
    lock <- .LOCKED_PACKAGE_CATALOGUES[[cs_id]]
    if (is.null(lock)) {
      schema_gap(
        sprintf(
          "code system '%s' for column '%s' has values_from.kind = package with no PLAN-locked catalogue",
          cs_id,
          name
        ),
        "a locked package catalogue in PLAN (ICD10Koodit / sksr dia / ATCKoodit / sksr); do not invent one"
      )
    }
    if (!package_values_from_matches_lock(vf, lock)) {
      schema_gap(
        sprintf(
          "code system '%s' values_from package/dataset does not match PLAN lock (%s::%s)",
          cs_id,
          lock$packages[[1]],
          lock$dataset
        ),
        sprintf(
          "values_from candidates including %s and dataset %s (locked catalogues win over unverified decoder)",
          lock$packages[[1]],
          lock$dataset
        )
      )
    }
    return(invisible(NULL))
  }
  if (identical(kind, "csv")) {
    keys <- lookup_keys(cs)
    # Fixture may supply a CSV-aligned lookup subset (kom post-2007; disco08 /
    # nace_db07 level slices). Without loadable codes: SCHEMA GAP -- do not invent.
    if (is.null(keys) || !length(keys)) {
      if (isTRUE(vf$mixes_eras)) {
        schema_gap(
          sprintf(
            "code system '%s' CSV mixes eras (e.g. pre/post-2007 municipalities); no era-safe sampler",
            cs_id
          ),
          "validity-aware kom sampling or a post-reform-only lookup; do not emit abolished munis blindly"
        )
      }
      schema_gap(
        sprintf(
          "code system '%s' for column '%s' has values_from.kind=csv with no loadable codes",
          cs_id,
          name
        ),
        "a fixture/runtime CSV lookup (values_from.url); do not invent occupation/industry lists"
      )
    }
  }
  invisible(NULL)
}
