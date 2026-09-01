find_whocc_atc_cache <- function(cache_dir) {
  if (is.null(cache_dir) || !dir.exists(cache_dir)) {
    return(NULL)
  }
  rds <- file.path(cache_dir, "codes.rds")
  if (file.exists(rds)) {
    return(list(type = "file", path = normalizePath(rds, winslash = "/", mustWork = TRUE)))
  }
  files <- list.files(
    cache_dir,
    pattern = "\\.(xlsx|xml|csv|tsv|txt|xls)$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  files <- files[file.info(files)$isdir %in% FALSE]
  if (!length(files)) {
    return(NULL)
  }
  list(type = "file", path = normalizePath(files[[1]], winslash = "/", mustWork = TRUE))
}

fetch_whocc_atc_url <- function(url, cache_dir) {
  if (!nzchar(url) || grepl("atc_ddd_index/[?]code=", url, ignore.case = TRUE)) {
    return(NULL)
  }
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(cache_dir, basename(sub("[?#].*$", "", url)))
  if (!nzchar(basename(dest)) || identical(basename(dest), url)) {
    dest <- file.path(cache_dir, "whocc-atc-download")
  }
  if (isTRUE(download_binary(url, dest))) {
    return(list(type = "file", path = normalizePath(dest, winslash = "/", mustWork = TRUE)))
  }
  NULL
}

parse_whocc_atc_source <- function(resolved, cache_dir) {
  if (identical(resolved$type, "memory")) {
    return(whocc_atc_catalogue(
      codes = resolved$codes,
      version = resolved$version,
      path = resolved$path,
      cached = FALSE
    ))
  }
  path <- resolved$path
  ext <- tolower(sub(".*\\.", "", path))
  if (identical(ext, "rds")) {
    obj <- readRDS(path)
    if (is.list(obj) && !is.null(obj$codes)) {
      return(whocc_atc_catalogue(
        codes = obj$codes,
        version = obj$version %||% guess_whocc_version(path),
        path = path,
        cached = TRUE
      ))
    }
    return(whocc_atc_catalogue(
      codes = extract_atc_level5(obj),
      version = guess_whocc_version(path),
      path = path,
      cached = TRUE
    ))
  }

  codes <- switch(
    ext,
    xlsx = parse_whocc_atc_xlsx(path),
    xls = parse_whocc_atc_xlsx(path),
    xml = parse_whocc_atc_xml(path),
    csv = parse_whocc_atc_text(path, sep = ","),
    tsv = parse_whocc_atc_text(path, sep = "\t"),
    txt = parse_whocc_atc_text(path, sep = ""),
    extract_atc_level5(read_text_file(path))
  )
  catalogue <- whocc_atc_catalogue(
    codes = codes,
    version = guess_whocc_version(path),
    path = path,
    cached = FALSE
  )
  cache_whocc_atc_catalogue(catalogue, cache_dir)
  catalogue
}

whocc_atc_catalogue <- function(codes, version, path, cached) {
  codes <- extract_atc_level5(codes)
  list(
    codes = codes,
    version = as.character(version %||% "unknown"),
    source = "WHOCC Oslo ATC/DDD Index",
    path = path,
    cached = isTRUE(cached)
  )
}

cache_whocc_atc_catalogue <- function(catalogue, cache_dir) {
  if (is.null(cache_dir) || !length(catalogue$codes)) {
    return(invisible(catalogue))
  }
  if (!is.na(catalogue$path) && identical(basename(catalogue$path), "codes.rds")) {
    return(invisible(catalogue))
  }
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(
    list(
      codes = catalogue$codes,
      version = catalogue$version,
      source = catalogue$source,
      path = catalogue$path
    ),
    file.path(cache_dir, "codes.rds")
  )
  writeLines(
    sprintf(
      paste(
        "source: %s",
        "version: %s",
        "path: %s",
        "n_codes: %d",
        sep = "\n"
      ),
      catalogue$source,
      catalogue$version,
      catalogue$path %||% "",
      length(catalogue$codes)
    ),
    file.path(cache_dir, "stamp.txt")
  )
  invisible(catalogue)
}

extract_atc_level5 <- function(x) {
  x <- toupper(as.character(unlist(x, use.names = FALSE)))
  x <- gsub("[^A-Z0-9]", "", x)
  x <- x[!is.na(x) & nzchar(x)]
  unique(x[grepl(.ATC_LEVEL5, x)])
}

guess_whocc_version <- function(path) {
  opt <- getOption("fiktive.whocc_atc_version")
  if (!is.null(opt) && nzchar(as.character(opt)[[1]])) {
    return(as.character(opt)[[1]])
  }
  env <- Sys.getenv("FIKTIVE_WHOCC_ATC_VERSION", unset = "")
  if (nzchar(env)) {
    return(env)
  }
  if (is.null(path) || is.na(path) || !nzchar(path)) {
    return("unknown")
  }
  b <- basename(path)
  m <- regmatches(b, regexpr("20[0-9]{2}", b))
  if (length(m) && nzchar(m)) {
    return(m)
  }
  info <- file.info(path)
  if (!is.null(info$mtime) && !is.na(info$mtime)) {
    return(format(as.Date(info$mtime), "%Y-%m-%d"))
  }
  "unknown"
}

read_text_file <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

parse_whocc_atc_text <- function(path, sep = ",") {
  if (identical(sep, "")) {
    return(extract_atc_level5(read_text_file(path)))
  }
  tbl <- tryCatch(
    utils::read.table(
      path,
      header = TRUE,
      sep = sep,
      quote = "\"",
      comment.char = "",
      stringsAsFactors = FALSE,
      fileEncoding = "UTF-8",
      fill = TRUE
    ),
    error = function(e) NULL
  )
  if (is.null(tbl) || !ncol(tbl)) {
    return(extract_atc_level5(read_text_file(path)))
  }
  nms <- tolower(gsub("[^a-z0-9]", "", names(tbl)))
  prefer <- which(nms %in% c("atc", "atccode", "code", "key", "atckode"))
  cols <- if (length(prefer)) tbl[prefer] else tbl
  extract_atc_level5(cols)
}

parse_whocc_atc_xlsx <- function(path) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop(
      "WHOCC Excel dump found at ", path,
      " but package 'readxl' is not installed. install.packages(\"readxl\") ",
      "or export 7-character ATC codes to CSV and set FIKTIVE_WHOCC_ATC.",
      call. = FALSE
    )
  }
  sheets <- readxl::excel_sheets(path)
  codes <- character()
  for (sh in sheets) {
    tbl <- readxl::read_excel(path, sheet = sh, col_types = "text")
    nms <- tolower(gsub("[^a-z0-9]", "", names(tbl)))
    prefer <- which(nms %in% c("atc", "atccode", "code", "key", "atckode"))
    cols <- if (length(prefer)) tbl[prefer] else tbl
    codes <- unique(c(codes, extract_atc_level5(cols)))
  }
  codes
}

parse_whocc_atc_xml <- function(path) {
  # Official WHOCC dumps are XML; extract 7-character codes from the user-owned
  # file. Do not scrape the searchable website.
  extract_atc_level5(read_text_file(path))
}

sample_whocc_atc <- function(n) {
  n <- as.integer(n)
  if (length(n) != 1L || is.na(n) || n < 0L) {
    stop("`n` must be a non-negative integer.", call. = FALSE)
  }
  if (n == 0L) {
    return(character())
  }
  cat <- load_whocc_atc_catalogue(required = TRUE)
  sample(cat$codes, n, replace = TRUE)
}

reset_whocc_atc_catalogue <- function() {
  .fiktive_whocc_atc$catalogue <- NULL
  invisible(NULL)
}

stamp_whocc_atc <- function(tbl) {
  cat <- .fiktive_whocc_atc$catalogue
  if (is.null(cat) || !"atc" %in% names(tbl) || !nrow(tbl)) {
    return(tbl)
  }
  attr(tbl, "atc_catalogue") <- cat$source
  attr(tbl, "atc_catalogue_version") <- cat$version
  tbl
}
