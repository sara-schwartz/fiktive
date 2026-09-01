\name{generate_background_population}
\alias{generate_background_population}
\title{Generate a stable background population}
\usage{
generate_background_population(n, seed = NULL, schema = NULL, ...)
}
\arguments{
\item{n}{Number of people.}
\item{seed}{Optional RNG seed. Restored on exit.}
\item{schema}{Optional schema from \code{\link{load_registers_schema}}.}
\item{...}{Unused; reserved.}
}
\value{
A tibble with \code{pnr}, \code{foed_dag}, and \code{koen}.
}
\description{
One row per person. The same \code{pnr} always has the same \code{foed_dag} and
\code{koen}. \code{pnr} is a joinable character code, not a CPR number.
}
