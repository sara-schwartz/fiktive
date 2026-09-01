\name{generate_register}
\alias{generate_register}
\title{Generate a fictitious register table}
\usage{
generate_register(register, population, schema, from, to, seed = NULL, scenario = NULL)
}
\arguments{
\item{register}{Lowercase register id (fastreg name), e.g. `"bef"`.}
\item{population}{Persons table from \code{\link{generate_background_population}}.}
\item{schema}{Schema from \code{\link{load_registers_schema}}.}
\item{from}{Start of the requested window.}
\item{to}{End of the requested window.}
\item{seed}{Optional RNG seed. Restored on exit.}
\item{scenario}{Must be `NULL` (independence).}
}
\value{
A tibble whose columns are a subset of the schema column names for `register`.
Zero rows is a valid event table. Non-empty LMDB tables stamp
`atc_catalogue` and `atc_catalogue_version`.
}
\description{
`scenario = NULL` is independence. Snapshot grains: `bef` (quarterly),
`udda` and `akm` (annual). Event-from-person: `dod`, `lmdb`, `vnds`.
Never mix `vnds` with `vnds_hist`/`vnds_ind`/`vnds_ud`.

LMDB `atc` is sampled from official WHO ATC codes published by WHOCC Oslo
(https://atcddd.fhi.no/atc_ddd_index/), cached at runtime. It is not
`decoder::atc` and not sprintf noise. Missing catalogue is a SCHEMA GAP.
`atc1`-`atc4` are prefixes of the sampled 7-character code.
}
