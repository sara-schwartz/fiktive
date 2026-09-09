\name{generate_registers}
\alias{generate_registers}
\title{Generate several schema registers (opt-in batch)}
\usage{
generate_registers(
  registers,
  population,
  schema,
  from,
  to,
  seed = NULL,
  scenario = NULL,
  fidelity = c("clean", "messy"),
  na_rate = NULL,
  outlier_rate = NULL
)
}
\arguments{
\item{registers}{Character vector of schema register ids (\strong{required}).}

\item{population}{Persons table from \code{\link{generate_background_population}}.}

\item{schema}{Schema from \code{\link{load_registers_schema}}.}

\item{from}{Start of the requested window.}

\item{to}{End of the requested window.}

\item{seed}{Optional RNG seed. Restored on exit.}

\item{scenario}{Must be \code{NULL} (independence). Always attaches truth.}
\item{fidelity}{\code{"clean"} (default) or \code{"messy"}.}
\item{na_rate}{Optional override in \eqn{[0,1]}.}
\item{outlier_rate}{Optional override in \eqn{[0,1]}.}
}
\value{
A named list of tibbles, one per requested id (lowercase names).
}
\description{
Opt-in fidelity (\code{clean}/\code{messy}) and always-on independence truth (STEP 8a).
Builds only the named schema registers. \code{registers} is required — there
is no silent default of every implemented id. Customs are not accepted here;
use \code{\link{generate_custom_register}} one-at-a-time.
}
