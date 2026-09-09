\name{get_truth}
\alias{get_truth}
\title{Truth slots for a generated run}
\usage{
get_truth(x = NULL, ...)
}
\arguments{
\item{x}{A generated tibble or named list of tibbles, or \code{NULL}.}

\item{...}{Unused.}
}
\value{
A list of class \code{fiktive_truth}.
}
\description{
Always available, including under independence (\code{scenario = NULL}).
Under independence the expected association is 0 within Monte Carlo error.
Bias / confounding / MAR / MNAR claims are deferred to later steps.
}
