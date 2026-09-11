# Column and value labels, surfaced from registers-guide's own schema
# metadata (schema$registers[[id]]$columns[[i]]$label, and
# schema$code_systems[[cs_id]]$lookup[[code]]) rather than generated or
# invented here. Read-only convenience over data fiktive already loads.

#' Column and value labels for a schema register
#'
#' Danish register columns and codes have real names like `civst`, `hfaudd`,
#' `kom` — not self-explanatory — and their coded values (`civst = "U"`,
#' `koen = 1`) are even less so. registers-guide documents a human-readable
#' label for almost every column and almost every code, in Danish and
#' English. `codebook()` surfaces that instead of leaving you to read the
#' schema YAML yourself. It describes the schema, not a specific generated
#' table — it works the same whether or not you've generated anything yet.
#'
#' @param schema Schema from [load_registers_schema()].
#' @param register One or more schema register ids, e.g. `"bef"` or
#'   `c("bef", "lmdb")`.
#'
#' @return A tibble, one row per column: `name`, `label_da`, `label_en`
#'   (`NA` if the schema doesn't document one), `type`, `code_system` (`NA`
#'   if the column isn't coded), and `values` (a single `"code: label"`
#'   string per coded value it has a label for, `NA` for uncoded columns or
#'   ones with no lookup labels). A `register` column is added when
#'   `register` has more than one id.
#' @export
codebook <- function(schema, register) {
  if (is.null(schema) || is.null(schema$registers)) {
    stop("`schema` from load_registers_schema() is required.", call. = FALSE)
  }
  register <- tolower(as.character(register))
  if (!length(register) || anyNA(register) || any(!nzchar(register))) {
    stop("`register` must be one or more non-empty schema register ids.", call. = FALSE)
  }
  rows <- lapply(register, function(rid) {
    spec <- schema$registers[[rid]]
    if (is.null(spec)) {
      schema_gap(
        sprintf("register id '%s' is not in the schema.", rid),
        "a register id that exists in registers/*.yaml"
      )
    }
    codebook_one_register(spec, schema, rid)
  })
  out <- dplyr::bind_rows(rows)
  if (length(register) == 1L) {
    out$register <- NULL
  }
  out
}

codebook_one_register <- function(spec, schema, rid) {
  cols <- spec$columns %||% list()
  if (!length(cols)) {
    return(tibble::tibble(
      register = character(), name = character(), label_da = character(),
      label_en = character(), type = character(), code_system = character(),
      values = character()
    ))
  }
  chr1 <- function(x) {
    x <- x[[1]]
    if (is.null(x)) NA_character_ else as.character(x)
  }
  tibble::tibble(
    register = rid,
    name = vapply(cols, function(c) chr1(c$name %||% c$id %||% NA_character_), character(1)),
    label_da = vapply(cols, function(c) chr1(c$label$da %||% NA_character_), character(1)),
    label_en = vapply(cols, function(c) chr1(c$label$en %||% NA_character_), character(1)),
    type = vapply(cols, function(c) chr1(c$type %||% NA_character_), character(1)),
    code_system = vapply(cols, function(c) chr1(c$code_system %||% NA_character_), character(1)),
    values = vapply(cols, function(c) code_system_value_labels(c$code_system, schema), character(1))
  )
}

code_system_value_labels <- function(cs_id, schema) {
  if (is.null(cs_id) || !nzchar(as.character(cs_id))) {
    return(NA_character_)
  }
  cs <- schema$code_systems[[as.character(cs_id)]]
  if (is.null(cs) || is.null(cs$lookup) || !length(cs$lookup)) {
    return(NA_character_)
  }
  parts <- vapply(names(cs$lookup), function(code) {
    lbl <- cs$lookup[[code]]
    text <- lbl$en %||% lbl$da %||% NA_character_
    if (is.na(text)) {
      return(NA_character_)
    }
    sprintf("%s: %s", code, text)
  }, character(1), USE.NAMES = FALSE)
  parts <- parts[!is.na(parts)]
  if (!length(parts)) {
    return(NA_character_)
  }
  paste(parts, collapse = "; ")
}
