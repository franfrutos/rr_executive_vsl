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
       lmerTest # P-values in summary
)

ensure_project_dirs()

# Confirmatory model in the control group ----
fit_no_time <-
  fit_control_model(
    "log_rt ~ condition",
    c(maximal = "(suppression + capture | participant_uid)",
      intercept = "(1 | participant_uid)"),
    control_clean,
    "control_no_time"
  )

summary(fit_no_time$fit)

params <- control_params(fit_no_time, control_clean)
params$a # Suppression effect (log RT)

# Model with time ----
# Time is 0 in the last block
fit_time <-
  fit_control_model(
    "log_rt ~ condition * log_time_end",
    c(maximal = "((suppression + capture) * log_time_end | participant_uid)",
      no_interaction_slopes = "(suppression + capture + log_time_end | participant_uid)",
      condition_slopes = "(suppression + capture | participant_uid)",
      time_slope = "(log_time_end | participant_uid)",
      intercept = "(1 | participant_uid)"),
    control_clean,
    "control_time"
  )

summary(fit_time$fit)

params_time <- control_params(fit_time, control_clean)
params_time$s # Increase of suppression over blocks (log RT)

# Awareness model ----
# Experiment 1, the same test as in the load group
m_aw <- fit_glmmtmb(choice_sets(circ_dist(aw_control$chosen, aw_control$HPDL)))

aw_ctrl <- tibble(n = nrow(aw_control), mu = m_aw$mu, sd = m_aw$sd)
aw_ctrl

# Suppression effect of the control group ----
# Compared with Wang and Theeuwes (2018): t(23) = 9.82
supp_scores <-
  control_clean %>%
  filter(condition %in% c("HPDL", "LPDL")) %>%
  group_by(participant_uid, condition) %>%
  summarise(rt = mean(rt), .groups = "drop") %>%
  pivot_wider(names_from = condition, values_from = rt) %>%
  mutate(supp = LPDL - HPDL)

g_ctrl <- g_z(mean(supp_scores$supp) / sd(supp_scores$supp), nrow(supp_scores))
g_wt <- g_z(9.82 / sqrt(24), 24)
g_ctrl
g_wt

save_analysis_objects(
  "control_models",
  params = params,
  params_time = params_time,
  aw_ctrl = aw_ctrl,
  g_ctrl = g_ctrl,
  g_wt = g_wt
)
