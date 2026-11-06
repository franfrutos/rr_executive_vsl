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

params <- load_analysis_objects("control_models")$params

alpha <- .02
sesoi <- .2 # H1: attenuation of 20% of the suppression effect
delta_h2 <- .18 # H2: equivalence bounds at +-18% of the suppression effect
nsim <- 500 # Replicates per cell
seed_base <- 20261103 # Seed of each cell: seed_base + cell_id x 1e5
n_cores <- min(18, parallel::detectCores() - 2)

skeletons <- make_skeletons(control_clean)
delta <- delta_h2 * params$a # H2 bounds in log units

# H1 and H2 ----
# About 16 h on 18 cores. Replicates in output/simulations are reused
n_grid <- c(140, 160, 60, 100, 200, 240)

cells <-
  bind_rows(
    tibble(n_load = n_grid, r = 1 - sesoi, cell_id = 500 + seq_along(n_grid)), # H1
    tibble(n_load = n_grid, r = 0, cell_id = 600 + seq_along(n_grid)), # H2
    tibble(n_load = 140, r = c(1, delta_h2, -delta_h2), cell_id = c(701, 711, 721)) # Type I error
  ) %>%
  mutate(seed = seed_base + cell_id * 1e5, nsim = nsim)

reps <-
  run_cells(cells, "output/simulations/power.csv", params, skeletons, delta, n_cores) %>%
  mutate(
    sig_h1 = p_gs < alpha,
    sig_h2 = p_equiv < alpha
  )

table(reps$re_step) # Final random-effects structure (1 = maximal)

power_conf <-
  reps %>%
  filter(cell_id %in% 501:506) %>%
  power_summary("sig_h1", n_load)

power_conf

calib <-
  reps %>%
  filter(cell_id == 701) %>%
  power_summary("sig_h1", n_load)

calib # Type I error of H1

reps_h2 <- filter(reps, cell_id %in% c(601:606, 711, 721))

se_h2 <-
  reps_h2 %>%
  group_by(n_load, r) %>%
  summarise(mean_se_supp_load = mean(se_supp_load[usable]), .groups = "drop")

h2 <-
  power_summary(reps_h2, "sig_h2", n_load, r) %>%
  rename(power_h2 = power) %>%
  left_join(se_h2, by = c("n_load", "r")) %>%
  mutate(
    scenario = case_when(
      r == 0 ~ "no suppression in the load group",
      r > 0 ~ "load suppression at the upper bound (type I error)",
      TRUE ~ "load suppression at the lower bound (type I error)"
    )
  )

h2

# Effect sizes in ms ----
scores <- control_participant_scores(control_clean)

es <- tibble(
  delta_suppression_ms = sesoi * mean(scores$suppression_ms),
  delta_coefficient = sesoi * params$a
)

h2_bound <- tibble(
  delta_h2 = delta_h2,
  control_suppression = params$a,
  delta_log = delta,
  control_suppression_ms = mean(scores$suppression_ms),
  delta_ms = delta_h2 * mean(scores$suppression_ms)
)

es
h2_bound

# ON1: counting task ----
# Worst case of the sampling plan: 140 of 160 participants at the inclusion
# threshold and the other 20 at chance
n_verif <- 72
threshold <- min_correct(n_verif, alpha)
accuracy <- rep(c(threshold / n_verif, .5), c(140, 20))

p_on1 <- vapply(
  seq_len(1000),
  function(i) simulate_on1(seed_base + 901 * 1e5 + i, accuracy, n_verif),
  numeric(1)
)

count_row <- tibble(
  n_load = length(accuracy),
  n_verif = n_verif,
  threshold = threshold,
  threshold_acc = threshold / n_verif,
  mean_acc = mean(accuracy),
  nsim = length(p_on1),
  power = mean(p_on1 < alpha)
)

count_row

# ON2: capture in the load group ----
# No suppression and a capture effect 10% as large as in the control group
cell_on2 <-
  tibble(n_load = 140, r = 0, r_capture = .1, cell_id = 801, nsim = nsim) %>%
  mutate(seed = seed_base + cell_id * 1e5)

reps_on2 <-
  run_cells(cell_on2, "output/simulations/capture.csv", params, skeletons, delta, n_cores) %>%
  mutate(sig_on2 = p_capt_load < alpha)

capt_power <-
  reps_on2 %>%
  power_summary("sig_on2", n_load) %>%
  mutate(r_capture = cell_on2$r_capture)

capt_power

save_analysis_objects(
  "power",
  power_conf = power_conf,
  calib = calib,
  h2 = h2,
  es = es,
  h2_bound = h2_bound,
  count_row = count_row,
  capt_power = capt_power
)
