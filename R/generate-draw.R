# Column draw / code-system resolve (loaded with generate-columns.R).

draw_independent_column <- function(col, n, schema, register_id = NULL, when = NULL) {
  type <- col$type %||% "character"
  role <- col$role
  name <- as.character(col$name %||% col$id)
  if (n == 0L) {
    return(na_of_type(type, 0L))
  }
  if (identical(name, "atc") || identical(as.character(col$id %||% ""), "atc")) {
    return(sample_atc_codes(n))
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
      unique_ids[[1]], col, n, schema, register_id = register_id, type = type, role = role, name = name
    ))
  }
  out <- vector(mode = mode_for_type(type), length = n)
  for (cid in unique_ids) {
    idx <- which(cs_ids == cid)
    out[idx] <- draw_from_code_system(
      cid, col, length(idx), schema, register_id = register_id, type = type, role = role, name = name
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

draw_from_code_system <- function(cs_id, col, n, schema, register_id, type, role, name) {
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

  keys <- lookup_keys(cs)
  if (!is.null(keys) && length(keys)) {
    if (identical(cs_id, "civst")) {
      keys <- setdiff(keys, "D")
    }
    drawn <- sample(keys, n, replace = TRUE)
    return(coerce_schema_type(drawn, type))
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

honour_values_from_or_gap <- function(cs, cs_id, name) {
  vf <- cs$values_from
  if (is.null(vf)) {
    return(invisible(NULL))
  }
  kind <- as.character(vf$kind %||% "")
  if (identical(kind, "none")) {
    # Allow enumerated/lookup override; otherwise gap (e.g. icd8).
    keys <- lookup_keys(cs)
    if (!is.null(keys) && length(keys)) {
      return(invisible(NULL))
    }
    schema_gap(
      sprintf("code system '%s' for column '%s' has values_from.kind = none", cs_id, name),
      "a published catalogue or lookup; do not invent a code list"
    )
  }
  if (identical(kind, "csv") && isTRUE(vf$mixes_eras)) {
    keys <- lookup_keys(cs)
    # Fixture may supply an era-safe lookup subset; otherwise do not invent / download.
    if (is.null(keys) || !length(keys)) {
      schema_gap(
        sprintf(
          "code system '%s' CSV mixes eras (e.g. pre/post-2007 municipalities); no era-safe sampler",
          cs_id
        ),
        "validity-aware kom sampling or a post-reform-only lookup; do not emit abolished munis blindly"
      )
    }
  }
  invisible(NULL)
}
