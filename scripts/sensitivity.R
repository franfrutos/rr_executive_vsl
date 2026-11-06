## -----------------------------------------------------------------------------
## Author: Francisco Garre-Frutos
## -----------------------------------------------------------------------------

# Loading packages----
source("scripts/functions.R")
source("scripts/load_data.R")

if (!require(pacman)) {
  install.packages("pacman")
  library(pacman)
}

p_load(dplyr,# Data wrangling
       lme4,# LMMs
       lmerTest, # P-values in summary
       marginaleffects,# Equivalence test
       binom # Exact binomial CIs
)

ensure_project_dirs()

ctrl <- load_analysis_objects("control_models")
params <- ctrl$params
params_time <- ctrl$params_time
aw_ctrl <- ctrl$aw_ctrl

alpha <- .02
n_load <- 140
seed_base <- 20261103 # As in power.R
n_cores <- min(18, parallel::detectCores() - 2)

skeletons <- make_skeletons(control_clean)
scores <- control_participant_scores(control_clean)

# Time course ----
# An attenuation of the slope only moves the fixed part, so the fit is the same
# and only the tested coefficient shifts. The curve uses the same fits
cell_time <-
  tibble(cell_id = 801, n_load = n_load, r = 1, nsim = 500) %>%
  mutate(seed = seed_base + cell_id * 1e5)

# Fewer workers: the model with time needs more memory
reps <-
  run_cells(cell_time, "output/simulations/sensitivity.csv", params_time, skeletons, .18 * params$a,
            min(14, n_cores), time = TRUE)

# Attenuation of the slope of suppression in the load group
triple <-
  tibble(attenuation_pct = seq(0, 100, 10), r = 1 - attenuation_pct / 100) %>%
  bind_cols(
    shifted_power(reps, "est_gss", "se_gss", "df_gss",
                  lower = TRUE, shifts = (1 - seq(0, 100, 10) / 100 - 1) * params_time$s, alpha = alpha)
  ) %>%
  mutate(delta_learning_ms = attenuation_pct / 100 * mean(scores$learning_ms))

triple

# Explicit knowledge ----
aw_path <- "output/simulations/sensitivity_awareness.csv"

if (!file.exists(aw_path)) {
  cells_aw <-
    tibble(attenuation_pct = seq(0, 100, 10)) %>%
    mutate(
      attenuation = attenuation_pct / 100,
      cell_id = 400 + row_number(),
      seed = 20261031 + cell_id * 1e5
    )

  cl <- parallel::makeCluster(n_cores)
  invisible(parallel::clusterCall(cl, setwd, getwd()))
  invisible(parallel::clusterEvalQ(cl, suppressMessages(source("scripts/functions.R"))))

  reps_aw <- bind_rows(lapply(seq_len(nrow(cells_aw)), function(j) {
    bind_rows(parallel::parLapply(cl, seq_len(1000), run_awareness_rep,
                                  cell = as.list(cells_aw[j, ]), aw_ctrl = aw_ctrl, n_load = n_load))
  }))

  parallel::stopCluster(cl)
  write.csv(reps_aw, aw_path, row.names = FALSE)
}

reps_aw <- read.csv(aw_path)

# A fit that fails or does not converge counts as a non-rejection
aware <-
  reps_aw %>%
  group_by(attenuation_pct) %>%
  summarise(nsim = n(), n_reject = sum(converged & p < alpha, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    power = n_reject / nsim,
    ci_lower = binom::binom.confint(n_reject, nsim, methods = "exact")$lower,
    ci_upper = binom::binom.confint(n_reject, nsim, methods = "exact")$upper,
    p_hpdl_load = vapply((1 - attenuation_pct / 100) * aw_ctrl$mu,
                         function(m) p_dist_marginal(m, aw_ctrl$sd)[1], numeric(1))
  )

aware

save_analysis_objects(
  "sensitivity",
  triple = triple,
  aware = aware
)
