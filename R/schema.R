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
#' @param source Schema root. The default loads the live GitHub
#'   `steno-aarhus/registers-guide` schema directory (`registers/`,
#'   `code-systems/`, `families/`). Pass a local directory that contains
#'   `registers/` for offline use.
#'
#' @return A list with `registers` (named by id), `code_systems`, `families`,
#'   `schema_commit` (40-character SHA), and `schema_source`.
#' @export
load_registers_schema <- function(source = NULL) {
  if (!is.null(source) && dir.exists(source)) {
    root <- normalizePath(source, winslash = "/", mustWork = TRUE)
    if (!dir.exists(file.path(root, "registers"))) {
      stop("`source` must be a schema root containing a `registers/` directory.", call. = FALSE)
    }
    return(read_schema_root(root, schema_commit = local_schema_commit(root), schema_source = root))
  }
  if (!is.null(source) && !identical(source, "live")) {
    stop("Unknown schema source: ", source, call. = FALSE)
  }
  load_live_schema()
}

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
