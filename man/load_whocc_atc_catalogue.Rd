\name{load_whocc_atc_catalogue}
\alias{load_whocc_atc_catalogue}
\title{Load official WHO ATC codes from WHOCC Oslo}
\usage{
load_whocc_atc_catalogue(path = NULL, cache_dir = NULL, required = TRUE)
}
\arguments{
\item{path}{Path to a WHOCC Excel (`.xlsx`), XML, CSV, TSV, or text dump.
Default: option `fiktive.whocc_atc`, then env `FIKTIVE_WHOCC_ATC`,
then the user cache.}
\item{cache_dir}{Runtime cache directory. Default:
`file.path(tools::R_user_dir("fiktive", "cache"), "whocc-atc")`.}
\item{required}{If `TRUE` (default), missing catalogue is a SCHEMA GAP
with an install/account message. If `FALSE`, return `NULL`.}
}
\value{
A list with `codes` (unique 7-character WHO ATC codes), `version`,
`source`, and `path`. `NULL` when `required = FALSE` and nothing is found.
}
\description{
Denmark's LMDB uses the WHO Anatomical Therapeutic Chemical classification
published by the WHO Collaborating Centre for Drug Statistics Methodology
(WHOCC) in Oslo: https://atcddd.fhi.no/atc_ddd_index/.

The complete structured index (Excel or XML) is not an unauthenticated public
dump. WHOCC documents that it is downloaded from a registered user account at
https://orders.atcddd.fhi.no/. This function does not scrape the searchable
website into the package, does not vendor the index in git, and does not use
`decoder::atc` (Swedish MPA). Parsed codes are cached under
`tools::R_user_dir()`, not `inst/extdata`.
}
