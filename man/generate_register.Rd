\name{generate_register}
\alias{generate_register}
\title{Generate a fictitious register table}
\usage{
generate_register(register, population, schema, from, to, seed = NULL, scenario = NULL)
}
\arguments{
\item{register}{Lowercase register id (fastreg name), e.g. \code{"bef"}.}
\item{population}{Persons table from \code{\link{generate_background_population}}.}
\item{schema}{Schema from \code{\link{load_registers_schema}}.}
\item{from}{Start of the requested window.}
\item{to}{End of the requested window.}
\item{seed}{Optional RNG seed. Restored on exit.}
\item{scenario}{Must be \code{NULL} (independence).}
}
\value{
A tibble whose columns are a subset of the schema column names for \code{register}.
Zero rows is a valid event table.
}
\description{
\code{scenario = NULL} is independence. Snapshot grains: \code{bef} (quarterly),
\code{udda} and \code{akm} (annual). Event-from-person: \code{dod}, \code{lmdb},
\code{vnds}. Never mix \code{vnds} with \code{vnds_hist}/\code{vnds_ind}/\code{vnds_ud}.
}
