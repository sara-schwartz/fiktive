fixture_schema <- function() {
  load_registers_schema(source = testthat::test_path("fixtures", "schema"))
}

tiny_pop <- function(schema, n = 12L, seed = 1L) {
  generate_background_population(n = n, seed = seed, schema = schema)
}
