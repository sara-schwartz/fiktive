\name{generate_background_population}
\alias{generate_background_population}
\title{Generate a stable background population}
\usage{
generate_background_population(n, seed = NULL, schema = NULL,
  birth_from = NULL, birth_to = NULL, age_min = NULL, age_max = NULL,
  reference_date = NULL, ...)
}
\arguments{
\item{n}{Number of people.}
\item{seed}{Optional RNG seed. Restored on exit.}
\item{schema}{Schema from \code{\link{load_registers_schema}}. Required for \code{koen}.}
\item{birth_from, birth_to}{Date bounds on birth date (inclusive). Default
1940-01-01 to 2007-12-31. Cannot be combined with \code{age_min}/\code{age_max}.}
\item{age_min, age_max}{Age in whole years (inclusive) at \code{reference_date},
as a friendlier alternative to \code{birth_from}/\code{birth_to} (e.g.
\code{age_min = 65} for a retirement-age cohort). Default \code{0}/\code{100} when only
one of the pair is given. Cannot be combined with \code{birth_from}/\code{birth_to}.}
\item{reference_date}{Date the \code{age_min}/\code{age_max} window is measured
from. Default \code{Sys.Date()}. Ignored unless \code{age_min}/\code{age_max} is used.}
\item{...}{Unused; reserved.}
}
\value{
A tibble with \code{pnr}, \code{foed_dag}, and \code{koen}.
}
\description{
One row per person. The same \code{pnr} always has the same \code{foed_dag} and
\code{koen}. \code{pnr} is a joinable character code, not a CPR number.
\code{schema = NULL} is a SCHEMA GAP: sex codes come from \code{koen.yaml}.
}
