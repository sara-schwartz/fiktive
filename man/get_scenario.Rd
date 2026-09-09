\name{get_scenario}
\alias{get_scenario}
\title{Scenario attached to a generated run}
\usage{
get_scenario(x = NULL, ...)
}
\arguments{
\item{x}{A generated tibble or named list of tibbles, or \code{NULL}.}

\item{...}{Unused.}
}
\value{
A list of class \code{fiktive_scenario} (independence when absent).
}
\description{
Returns the \code{fiktive_scenario} attached by generators. Independence when
\code{scenario = NULL}.
}
