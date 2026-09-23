#' Signal a missing fact in the live schema
#'
#' Stops with a message that starts with `SCHEMA GAP:`. Use this instead of
#' inventing column names, code lists, id formats, or relationships the YAML
#' does not provide.
#'
#' @param what What is missing.
#' @param needed What the schema would need to supply.
#' @export
schema_gap <- function(what, needed) {
  stop("SCHEMA GAP: ", what, " Needed: ", needed, call. = FALSE)
}

.schema_repo <- "steno-aarhus/registers-guide"
.schema_subdir <- "schema"

#' Load the registers-guide schema
#'
#' Consumes YAML at runtime from the live GitHub schema directory (or a local
#' schema root). Does not vendor the YAML into the installed package as the
#' source of truth. The git commit used is stamped as `schema_commit`.
#'
#' **Always also includes fiktive's own bundled DCH / DCH-NG cohort
#' metadata** (Diet, Cancer and Health / ...and Next Generations),
#' merged into the returned `registers` alongside the DST ones -- not a
#' second call to remember, and not something `source=` controls (that
#' argument only selects the DST/registers-guide half). This is fiktive's
#' own data, not registers-guide's: variable name, type, and Danish/English
#' label only (per KKH/DCH's data-sharing approval), shipped inside the
#' installed package at `system.file("extdata/dch-schema", package =
#' "fiktive")`, never fetched from or written to
#' `steno-aarhus/registers-guide`. Register ids (`dch`, `dchng`) are
#' distinct from any DST register id. Each column carries a `dataset`
#' field recording which of the ~27 real underlying SAS datasets it came
#' from (both cohorts were originally delivered as many separate tables,
#' not one) -- see [codebook()]. See `vignette("fiktive")` for more, and
#' [generate_register()] for how to generate them (same call as any DST
#' register -- no separate function).
#'
#' @param source Schema root for the DST/registers-guide half only. The
#'   default loads the live GitHub `steno-aarhus/registers-guide` schema
#'   directory (`registers/`, `code-systems/`, `families/`). Pass a local
#'   directory that contains `registers/` for offline use. Either way, the
#'   bundled DCH/DCH-NG registers are still merged in.
#'
#' @return A list with `registers` (named by id -- DST and DCH/DCH-NG
#'   together), `code_systems`, `families`, `schema_commit` (40-character
#'   SHA of the DST half; the bundled DCH/DCH-NG metadata is versioned with
#'   the installed fiktive package instead, not independently), and
#'   `schema_source`.
#' @export
load_registers_schema <- function(source = NULL) {
  primary <- if (!is.null(source) && dir.exists(source)) {
    root <- normalizePath(source, winslash = "/", mustWork = TRUE)
    if (!dir.exists(file.path(root, "registers"))) {
      stop("`source` must be a schema root containing a `registers/` directory.", call. = FALSE)
    }
    read_schema_root(root, schema_commit = local_schema_commit(root), schema_source = root)
  } else if (!is.null(source) && !identical(source, "live")) {
    stop("Unknown schema source: ", source, call. = FALSE)
  } else {
    load_live_schema()
  }
  merge_dch_schema(primary)
}

# Merges fiktive's own bundled DCH/DCH-NG register metadata into an
# already-resolved DST schema. dch-schema has no code-systems/families of
# its own (DCH columns carry no code_system -- structural noise only), so
# only `registers` needs merging. This still fails loudly rather than
# silently overwriting either side if a DST register id ever collides with
# `dch`/`dchng`.
merge_dch_schema <- function(schema) {
  dch_root <- system.file("extdata", "dch-schema", package = "fiktive")
  if (!nzchar(dch_root) || !dir.exists(file.path(dch_root, "registers"))) {
    return(schema)
  }
  dch <- read_schema_root(dch_root, schema_commit = NA_character_, schema_source = dch_root)
  collide <- intersect(names(schema$registers), names(dch$registers))
  if (length(collide)) {
    stop(
      "Bundled DCH/DCH-NG register id(s) collide with the DST schema: ",
      paste(collide, collapse = ", "),
      call. = FALSE
    )
  }
  schema$registers <- c(schema$registers, dch$registers)
  schema
}

# Ids of the bundled DCH/DCH-NG registers ("dch", "dchng"), read from the
# installed package's own YAML directory rather than hardcoded, so this
# can't drift if the bundled schema is ever rebuilt. Used by
# dispatch_generate_register() (R/generate.R) to extend the "implemented
# person-grain snapshot registers" whitelist without touching DST ids.
dch_register_ids <- function() {
  root <- system.file("extdata", "dch-schema", "registers", package = "fiktive")
  if (!nzchar(root) || !dir.exists(root)) {
    return(character())
  }
  tools::file_path_sans_ext(list.files(root, pattern = "\\.ya?ml$"))
}

# Per the KKH/DCH data-sharing approval: variable name, type, and
# Danish/English label only -- nothing else from the source catalogues,
# and no real data, is in fiktive. See data-raw/collapse_dch_registers.R
# for how the two bundled registers (dch, dchng) were built from the 27
# original per-real-dataset YAMLs (each column's `dataset` field records
# which one it came from).
#
# Two judgment calls made when those 27 were originally derived, kept here
# since the source catalogues aren't in this repo: DCH-NG's 27 near-empty
# `sca_v1`..`v27` dataset fragments were collapsed into one `sca` dataset
# (no SAS files were available to confirm whether they're really distinct
# tables), and the "??" / "done_all" placeholder dataset values were
# bundled into a new `admin` dataset rather than attached to an unrelated
# real table.
#
# dch's own kqn/fsdato and dchng's own fsdato/fsdato_c are dropped
# entirely from the bundled columns: neither catalogue documents a real
# code list or value range for them, and keeping them would mean inventing
# a domain fiktive has no source for, while also generating a second,
# independently-drawn value for a fact fiktive already has from the shared
# population (silently disagreeing with bef for the same pnr). dchng's
# `koen`/`sex` are kept, not dropped, since both are unambiguous: `koen`
# collides by name with the population's own column, and `sex`'s label
# states DST's exact 1=Male/2=Female coding -- see the `sex =` case in
# derived_column() (R/generate-columns.R).

read_schema_root <- function(root, schema_commit, schema_source) {
  registers <- read_yaml_dir(file.path(root, "registers"))
  code_systems <- read_yaml_dir(file.path(root, "code-systems"))
  families <- read_yaml_dir(file.path(root, "families"))
  structure(
    list(
      registers = registers,
      code_systems = code_systems,
      families = families,
      schema_commit = schema_commit,
      schema_source = schema_source
    ),
    class = c("fiktive_schema", "list")
  )
}

read_yaml_dir <- function(dir) {
  if (!dir.exists(dir)) {
    return(list())
  }
  files <- list.files(dir, pattern = "\\.ya?ml$", full.names = TRUE)
  if (!length(files)) {
    return(list())
  }
  parsed <- purrr::map(files, yaml::read_yaml)
  ids <- purrr::map_chr(parsed, function(x) {
    id <- x$id
    if (is.null(id) || !nzchar(as.character(id)[[1]])) {
      schema_gap("YAML file with no `id`", "an `id` field in each schema YAML file")
    }
    as.character(id)[[1]]
  })
  purrr::set_names(parsed, ids)
}

local_schema_commit <- function(root) {
  git <- Sys.which("git")
  if (!nzchar(git)) {
    return(strrep("0", 40L))
  }
  sha <- suppressWarnings(tryCatch(
    system2(git, c("-C", root, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  ))
  status <- attr(sha, "status")
  if (!is.null(status) && !identical(as.integer(status), 0L)) {
    return(strrep("0", 40L))
  }
  if (length(sha) >= 1L && grepl("^[0-9a-f]{40}$", sha[[1]])) {
    return(sha[[1]])
  }
  strrep("0", 40L)
}

fetch_schema_commit <- function() {
  git <- Sys.which("git")
  if (nzchar(git)) {
    out <- tryCatch(
      system2(
        git,
        c("ls-remote", sprintf("https://github.com/%s.git", .schema_repo), "HEAD"),
        stdout = TRUE,
        stderr = FALSE
      ),
      error = function(e) character()
    )
    if (length(out) >= 1L) {
      sha <- sub("[[:space:]].*$", "", out[[1]])
      if (grepl("^[0-9a-f]{40}$", sha)) {
        return(sha)
      }
    }
  }
  json <- github_get(sprintf("https://api.github.com/repos/%s/commits/main", .schema_repo))
  m <- regmatches(json, regexpr('"sha"[[:space:]]*:[[:space:]]*"[0-9a-f]{40}"', json))
  if (!length(m)) {
    stop("Could not parse schema commit SHA from the GitHub API.", call. = FALSE)
  }
  sub('.*"([0-9a-f]{40})".*', "\\1", m)
}

github_get <- function(url) {
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  ok <- tryCatch(
    utils::download.file(
      url,
      destfile = tmp,
      quiet = TRUE,
      mode = "wb",
      headers = c(
        "User-Agent" = "fiktive (https://github.com/sara-schwartz/fiktive)",
        "Accept" = "application/vnd.github+json"
      )
    ),
    error = function(e) 1L
  )
  if (!identical(ok, 0L) || !file.exists(tmp)) {
    stop("Failed to download: ", url, call. = FALSE)
  }
  paste(readLines(tmp, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

download_binary <- function(url, destfile) {
  ok <- tryCatch(
    utils::download.file(
      url,
      destfile = destfile,
      quiet = TRUE,
      mode = "wb",
      headers = c(
        "User-Agent" = "fiktive (https://github.com/sara-schwartz/fiktive)"
      )
    ),
    error = function(e) 1L
  )
  identical(ok, 0L) && file.exists(destfile) && file.info(destfile)$size > 0
}

load_live_schema <- function() {
  old_timeout <- getOption("timeout")
  options(timeout = max(60, old_timeout %||% 60))
  on.exit(options(timeout = old_timeout), add = TRUE)

  sha <- fetch_schema_commit()
  source_label <- sprintf(
    "https://github.com/%s/%s@%s",
    .schema_repo,
    .schema_subdir,
    sha
  )
  root <- fetch_schema_tarball(sha)
  if (is.null(root)) {
    root <- fetch_schema_by_contents(sha)
  }
  read_schema_root(root, schema_commit = sha, schema_source = source_label)
}

fetch_schema_tarball <- function(sha) {
  dest <- tempfile(fileext = ".tar.gz")
  exdir <- tempfile("fiktive-schema-")
  dir.create(exdir, recursive = TRUE)
  urls <- c(
    sprintf("https://codeload.github.com/%s/tar.gz/%s", .schema_repo, sha),
    sprintf("https://github.com/%s/archive/%s.tar.gz", .schema_repo, sha)
  )
  got <- FALSE
  for (u in urls) {
    if (download_binary(u, dest)) {
      got <- TRUE
      break
    }
  }
  if (!got) {
    unlink(c(dest, exdir), recursive = TRUE)
    return(NULL)
  }
  utils::untar(dest, exdir = exdir)
  unlink(dest)
  registers <- list.files(exdir, pattern = "^registers$", recursive = TRUE, include.dirs = TRUE, full.names = TRUE)
  registers <- registers[dir.exists(registers)]
  if (!length(registers)) {
    unlink(exdir, recursive = TRUE)
    return(NULL)
  }
  normalizePath(dirname(registers[[1]]), winslash = "/", mustWork = TRUE)
}

fetch_schema_by_contents <- function(sha) {
  root <- tempfile("fiktive-schema-")
  dir.create(root, recursive = TRUE)
  for (subdir in c("registers", "code-systems", "families")) {
    dest_dir <- file.path(root, subdir)
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
    names <- github_list_yaml(subdir, sha)
    purrr::walk(names, function(fname) {
      url <- sprintf(
        "https://raw.githubusercontent.com/%s/%s/%s/%s",
        .schema_repo,
        sha,
        file.path(.schema_subdir, subdir),
        fname
      )
      utils::download.file(
        url,
        destfile = file.path(dest_dir, fname),
        quiet = TRUE,
        mode = "wb",
        headers = c("User-Agent" = "fiktive (https://github.com/sara-schwartz/fiktive)")
      )
    })
  }
  root
}

github_list_yaml <- function(subdir, sha) {
  url <- sprintf(
    "https://api.github.com/repos/%s/contents/%s/%s?ref=%s",
    .schema_repo,
    .schema_subdir,
    subdir,
    sha
  )
  json <- github_get(url)
  m <- gregexpr('"name"[[:space:]]*:[[:space:]]*"[^"]+\\.ya?ml"', json)
  hits <- regmatches(json, m)[[1]]
  if (!length(hits)) {
    return(character())
  }
  sub('.*"([^"]+\\.ya?ml)".*', "\\1", hits)
}
