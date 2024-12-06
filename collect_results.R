library(tidyverse)

eval_data <- fs::dir_ls("files", regexp = "RData") |>
  map(read_rds) |>
  bind_rows() |>
  mutate(sparsity = n_counts / (n_counts + n_numeric))

write_rds(eval_data, "simulation_results.rds")
