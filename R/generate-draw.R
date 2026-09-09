# Column draw / code-system resolve (loaded with generate-columns.R).

draw_independent_column <- function(col, n, schema, register_id = NULL, when = NULL) {
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
  if (is.null(col$code_system) && identical(name, "borger_koen")) {
    schema_gap(
      "borger_koen has no published code_system / value set",
      "a documented value set on the column; do not map from BEF koen"
    )
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
      when = when
    ))
  }
  out <- vector(mode = mode_for_type(type), length = n)
  for (cid in unique_ids) {
    idx <- which(cs_ids == cid)
    out[idx] <- draw_from_code_system(
      cid, col, length(idx), schema, register_id = register_id, type = type, role = role, name = name,
      when = when[idx]
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
    if (identical(cs_id, "civst")) {
      keys <- setdiff(keys, "D")
    }
    return(sample(keys, n, replace = TRUE))
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
    if (identical(cs_id, "civst")) {
      keys <- setdiff(keys, "D")
    }
    return(sample(keys, n, replace = TRUE))
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
    if (identical(cs_id, "civst")) {
      keys <- setdiff(keys, "D")
    }
    out[idx] <- sample(keys, length(idx), replace = TRUE)
  }
  out
}

draw_from_code_system <- function(cs_id, col, n, schema, register_id, type, role, name, when = NULL) {
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
    return(coerce_schema_type(sample_icd10_who_codes(n), type))
  }
  if (identical(cs_id, "icd10_sks")) {
    return(draw_sks_dia_codes(name, n, type, register_id))
  }
  if (identical(cs_id, "icd8")) {
    schema_gap(
      sprintf("ICD-8 codes for column '%s' (values_from kind none / no catalogue)", name),
      "a published ICD-8 list in the schema, or leave previous_code_system rows as SCHEMA GAP"
    )
  }
  if (cs_id %in% c("sks", "kont_type")) {
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
