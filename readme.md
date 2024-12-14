# Benchmark Sparsity Threshold Tidymodels


## How to run simulation

1.  Install {renv} package `pak::pak("renv")` and call
    `renv::restore()`. This will install the correct versions of
    packages.

2.  `source("make_files.R")` to set up simulation files.

3.  Call `make` from the terminal while being in `files/` directory.

4.  `source("collect_results.R")` to create a results data set.

5.  Run `quarto render readme.qmd` to update the readme with new
    results.

## Results

Loading packages and data.

``` r
library(tidyverse)

eval_data <- read_rds("simulation_results.rds") |>
  mutate(sparse_data = if_else(sparse_data, "sparse", "dense"))
```

`eval_data` data dictionary:

- `sparse_data`: Logical, whether data was encoded as a sparse tibble or
  not.
- `model`: Character, Which parsnip model was used.
- `n_numeric`: Numeric, Number of numeric columns. These columns are
  dense, meaning little to no 0 values.
- `n_counts`: Numeric, Number of counts columns. These columns are
  sparse, meaning almost all 0 values.
- `n_rows`: Numeric, Number of rows in the data set.
- `seed`: Numeric, seed value.
- `time`: Numeric, number of seconds it took to run
  `fit(wf_spec, data)`.
- `mem_alloc`: Numeric, amount of memory allocated when running
  `fit(wf_spec, data)`.
- `rmse`: Numeric, performance metric between predictions and true
  values.

Run-time by sparsity and encoding

``` r
eval_data |>
  ggplot(aes(sparsity, time, color = sparse_data)) +
  geom_point(alpha = 0.25) +
  theme_minimal() +
  scale_x_continuous(labels = scales::percent) +
  labs(
 x = "sparsity (percentage of 0s)",
 y = "time (seconds)",
 color = "encoding"
 )
```

![](readme_files/figure-commonmark/sparsity-vs-time-1.png)

Memory allocation by sparsity and encoding

``` r
eval_data |>
  ggplot(aes(sparsity, mem_alloc, color = sparse_data)) +
  geom_point(alpha = 0.25) +
  theme_minimal() +
  scale_x_continuous(labels = scales::percent) +
 bench::scale_y_bench_bytes() +
  labs(
 x = "sparsity (percentage of 0s)",
 y = "Memory Allocation",
 color = "encoding"
 )
```

![](readme_files/figure-commonmark/sparsity-vs-mem_alloc-1.png)

Each model is made to predict on the training data, and calculate the
`yardstick::rmse()`. This value is compared between using sparse
encoding and dense encoding of the data to try to detect differences in
model fits.

``` r
rmse_tbl <- eval_data |>
  select(sparse_data, model, n_numeric, n_counts, n_rows, seed, rmse) |>
  pivot_wider(values_from = rmse, names_from = sparse_data, 
 names_prefix = "rmse_") |>
  mutate(rmse_diff = rmse_sparse - rmse_dense, .before = everything())
  
rmse_tbl |>
  ggplot(aes(rmse_sparse, rmse_dense)) +
  geom_point() +
  theme_minimal() +
  labs(
 title = "RMSE of Model with ___ encoding",
 x = "sparse",
 y = "dense"
 )
```

![](readme_files/figure-commonmark/rsme-dense-vs-sparse-1.png)

``` r
rmse_tbl |>
  count(rmse_diff)
```

    # A tibble: 140 × 2
         rmse_diff     n
             <dbl> <int>
     1 -0.000110       1
     2 -0.0000427      1
     3 -0.0000291      1
     4 -0.0000270      1
     5 -0.0000103      1
     6 -0.00000655     1
     7 -0.00000540     1
     8 -0.00000521     1
     9 -0.00000331     1
    10 -0.00000298     1
    # ℹ 130 more rows
