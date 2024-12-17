
library(tidymodels)
library(probably)
library(baguette)
library(readr)

# ------------------------------------------------------------------------------

tidymodels_prefer()
theme_set(theme_bw())
options(pillar.advice = FALSE, pillar.min_title_chars = Inf)

# ------------------------------------------------------------------------------

eval_data <- read_rds("simulation_results.rds") |>
  mutate(sparse_data = if_else(sparse_data, "sparse", "dense"))

time_data <-
  eval_data %>%
  select(sparsity, n_numeric, n_counts, n_rows, sparse_data, seed, time) %>%
  pivot_wider(
    id_cols = c(sparsity, n_numeric, n_counts, n_rows, seed),
    names_from = "sparse_data",
    values_from = "time"
  ) %>%
  mutate(
    log_fold = log(dense / sparse)
  ) %>%
  select(-sparse, -dense) %>%
  summarize(
    log_fold = median(log_fold),
    .by = c(sparsity, n_numeric, n_counts, n_rows)
  )

# ------------------------------------------------------------------------------

set.seed(3872)
time_split <- initial_split(time_data, strata = sparsity)
time_tr <- training(time_split)
time_te <- testing(time_split)

set.seed(1)
time_rs <- vfold_cv(time_tr, repeats = 10)

# ------------------------------------------------------------------------------

cart_spec <- decision_tree() %>% set_mode("regression")

cart_res <-
  cart_spec %>%
  fit_resamples(
    log_fold ~ .,
    resamples = time_rs,
    control = control_resamples(save_pred = TRUE, save_workflow = TRUE)
  )

collect_metrics(cart_res)

cart_fit <- fit_best(cart_res)

# ------------------------------------------------------------------------------

bag_spec <- bag_tree() %>% set_mode("regression")

bag_res <-
  bag_spec %>%
  fit_resamples(
    log_fold ~ .,
    resamples = time_rs,
    control = control_resamples(save_pred = TRUE, save_workflow = TRUE)
  )

collect_metrics(bag_res)

cal_plot_regression(bag_res)

bag_fit <- fit_best(bag_res)

# ------------------------------------------------------------------------------

glmn_spec <-
  linear_reg(penalty = tune()) %>%
  set_mode("regression") %>%
  set_engine("glmnet")

glmn_rec <-
  recipe(log_fold ~ ., data = time_tr) %>%
  step_YeoJohnson(all_predictors()) %>%
  step_normalize(all_predictors())

glmn_res <-
  glmn_spec %>%
  tune_grid(
    glmn_rec,
    resamples = time_rs,
    grid = 50,
    control = control_resamples(save_pred = TRUE, save_workflow = TRUE)
  )

autoplot(glmn_res)

glmn_fit <- fit_best(glmn_res)

cal_plot_regression(glmn_res, parameters = select_best(glmn_res, metric = "rmse"))

glmn_fit %>%
  extract_fit_parsnip() %>%
  autoplot()

# ------------------------------------------------------------------------------

mars_spec <-
  mars(num_terms = tune(), prod_degree = tune(), prune_method = "none") %>%
  set_mode("regression")

mars_param <-
  mars_spec %>%
  extract_parameter_set_dials() %>%
  update(num_terms = num_terms(c(2, 50)))

mars_res <-
  mars_spec %>%
  tune_grid(
    log_fold ~ .,
    resamples = time_rs,
    grid = 50,
    param_info = mars_param,
    control = control_resamples(save_pred = TRUE, save_workflow = TRUE)
  )

autoplot(mars_res)

show_best(mars_res, metric = "rmse")
show_best(mars_res, metric = "rsq")

mars_fit <- fit_best(mars_res)

cal_plot_regression(mars_res, parameters = select_best(mars_res, metric = "rmse"))

mars_fit %>%
  extract_fit_engine() %>%
  format(style = "pmax") %>%
  cat()

# ------------------------------------------------------------------------------

augment(mars_fit, time_te) %>%
  cal_plot_regression(log_fold, .pred)

augment(mars_fit, time_te) %>%
  metrics(log_fold, .pred)

