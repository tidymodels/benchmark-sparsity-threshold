sparse_data <- FALSE
model <- "LiblineaR"
seed <- 1
n_numeric <- 10
n_counts <- 16
n_rows <- 16000
file_name <- glue::glue("{sparse_data}_{model}_{seed}_{n_numeric}_{n_counts}_{n_rows}.RData")

## Packages --------------------------------------------------------------------

suppressPackageStartupMessages({
library(tidymodels)
})

## Simulate data ---------------------------------------------------------------

create_dummy <- function(n) {
  n_non_zero <- rpois(1, n / 1000) + 1
  positions <- sort(sample(n, n_non_zero))
  values <- rep(1, n_non_zero)

  sparsevctrs::sparse_integer(values, positions, length = n)
}

create_data <- function(n_rows, n_dense, n_sparse) {
  outcome <- rnorm(n_rows)

  dense_columns <- map(seq_len(n_dense), ~rnorm(n = n_rows))
  names(dense_columns) <- paste0("d", seq_len(n_dense))

  sparse_columns <- map(seq_len(n_sparse), ~create_dummy(n = n_rows))
  names(sparse_columns) <- paste0("s", seq_len(n_sparse))


  bind_cols(outcome = outcome, dense_columns, sparse_columns)
}

materialize_data <- function(data) {
  for (i in seq_along(data)) {
    data[[i]] <- data[[i]][]
  }
  data
}

set.seed(seed)

data <- create_data(n_rows, n_numeric, n_counts)

if (!sparse_data) {
  data <- materialize_data(data)
}

## Specify model ---------------------------------------------------------------

rec_spec <- recipe(outcome ~ ., data = data)
if (model == "xgboost") {
  mod_spec <- boost_tree(mode = "regression", engine = "xgboost")
} else if (model == "glmnet") {
  mod_spec <- linear_reg(mode = "regression", engine = "glmnet", penalty = 0)
} else if (model == "ranger") {
  mod_spec <- rand_forest(mode = "regression", engine = "ranger")
} else if (model == "LiblineaR") {
  mod_spec <- svm_linear(mode = "regression", engine = "LiblineaR")
} else if (model == "lightgbm") {
  library(bonsai)
  library(lightgbm)
  mod_spec <- boost_tree(mode = "regression", engine = "lightgbm")
}
wf_spec <- workflow(rec_spec, mod_spec)

## model fit -------------------------------------------------------------------

mem_alloc <- bench::bench_memory(
  time <- system.time(
    wf_fit <- fit(wf_spec, data)
  )
)

## Model performance -----------------------------------------------------------

preds <- predict(wf_fit, data)
rmse_value <- rmse_vec(preds$.pred, data$outcome)

## Session info ----------------------------------------------------------------

sessioninfo::session_info()

# Save results -----------------------------------------------------------------

readr::write_rds(
  list(
    sparse_data = sparse_data,
    model = model,
    n_numeric = n_numeric,
    n_counts = n_counts,
    n_rows = n_rows,
    seed = seed,
    time = time[["elapsed"]],
    rmse = rmse_value,
    mem_alloc = mem_alloc$mem_alloc
  ),
  file = file_name
)
