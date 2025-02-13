library(tidymodels)
library(glue)
library(stringr)
library(fs)

# ------------------------------------------------------------------------------

tidymodels_prefer()
theme_set(theme_bw())
options(pillar.advice = FALSE, pillar.min_title_chars = Inf)

# ------------------------------------------------------------------------------

template <- readLines("template.R")

# ------------------------------------------------------------------------------

num_sim <- 2

set.seed(1)

combinations <- 
  crossing(
    sparse_data = c(TRUE, FALSE),
    model = c("xgboost", "glmnet", "ranger", "LiblineaR", "lightgbm"),
    seed = seq_len(num_sim),
    n_numeric = c(1, 10, 20, 30, 40, 50, 60, 70),
    n_counts = c(8, 16, 32, 64, 128, 256, 512, 1024),
    n_rows = c(100, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000)
  ) |>
  mutate(
    file = glue("files/{sparse_data}_{model}_{seed}_{n_numeric}_{n_counts}_{n_rows}.R")
  ) |>
  slice_sample(prop = 1)

new_file <- function(x, template) {
  template <- gsub("SPARSE_DATA", x$sparse_data, template)
  template <- gsub("MODEL", x$model, template)  
  template <- gsub("SEED", x$seed, template)   
  template <- gsub("N_NUMERIC", x$n_numeric, template)  
  template <- gsub("N_COUNTS", x$n_counts, template)     
  template <- gsub("N_ROWS", x$n_rows, template)  
  cat(template, sep = "\n", file = x$file)
  invisible(NULL)
}

if (!dir_exists("files")) {
  dir_create("files")
}

for (i in seq_len(nrow(combinations))) {
  new_file(combinations[i, ], template)
}

# ------------------------------------------------------------------------------

src_files <- list.files(path = "files", pattern = "*.*R$")
src_files <- sample(src_files)
rda_files <- gsub("R$", "RData", src_files)

target_list <- paste0(rda_files, collapse = " ")

target_list <- paste0("all: ", target_list, "\n\n")

instruct <- function(src_file) {
  glue(
"
{src_file}Data: {src_file} 
\t@date '+ %Y-%m-%d %H:%M:%S: + {src_file}'
\t@$(RCMD) BATCH --vanilla {src_file}
\t@date '+ %Y-%m-%d %H:%M:%S: - {src_file}'

"
  )
}

instructions <- map_chr(src_files, instruct)
instructions <- paste0(instructions, collapse = "\n")

header <- 
"SHELL = /bin/bash
R    ?= R 
RCMD  =@$(R) CMD
TIMESTAMP = $(shell  date '+%Y-%m-%d-%H-%M')
here=${PWD}/..
"

cat(header, file = "files/makefile", sep = "")

cat(target_list, file = "files/makefile", append = TRUE, sep = "")
cat(instructions, file = "files/makefile", append = TRUE, sep = "")
