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
       tidyr,
       purrr,
       lme4,# LMMs
       lmerTest, # P-values in summary
       marginaleffects,# Equivalence test and capture in the load group
       glmmTMB # Awareness model
)

ensure_project_dirs()

ctrl <- load_analysis_objects("control_models")

alpha <- .02
delta <- .18 * ctrl$params$a # Equivalence bounds of H2 (log RT)

# Load group data ----
# A simulated load group until Input/load_group contains the data
files <- list.files("Input/load_group", pattern = "^ast_.*\\.csv$", full.names = TRUE)
simulated <- length(files) == 0

if (simulated) {
  sessions <- simulate_load_group(ctrl$params_time, ctrl$aw_ctrl, raw_control)
} else {
  sessions <- bind_rows(lapply(files, read.csv, stringsAsFactors = FALSE, colClasses = c(participant = "character")))
}

sessions$participant_uid <- paste0("L_", sessions$participant)

raw_load <-
  sessions %>%
  filter(phase == "experimental") %>%
  transmute(
    participant_uid,
    block,
    trial_in_block,
    condition = factor(condition, levels = c("HPDL", "LPDL", "ND")),
    correct,
    rt = as.numeric(rt_ms)
  )

# Exclusions ----
# Same search criteria as in the control group
load_search <- preprocess_search(raw_load)

# Keeping participants performing above chance in the counting task
verification <-
  sessions %>%
  filter(phase == "verification") %>%
  group_by(participant_uid) %>%
  summarise(correct = sum(verify_correct), n = n(), .groups = "drop") %>%
  mutate(p_value = map2_dbl(correct, n, ~ binom.test(.x, .y, alternative = "greater")$p.value))

count_in <-
  verification %>%
  filter(p_value < alpha) %>%
  pull(participant_uid)

load_clean <- filter(load_search, participant_uid %in% count_in)

exclusions <- tibble(
  recruited = n_distinct(raw_load$participant_uid),
  excluded_search = recruited - n_distinct(load_search$participant_uid),
  excluded_counting = n_distinct(load_search$participant_uid) - n_distinct(load_clean$participant_uid),
  analysable = n_distinct(load_clean$participant_uid)
)

exclusions

# Confirmatory model ----
d_RT <- bind_rows(
  mutate(control_clean, group_c = -.5),
  mutate(load_clean, group_c = .5)
)

f.conf <- fit_lmer_planned(d_RT, "log_rt ~ group_c * (suppression + capture)", re_steps$no_time)

re_steps$no_time[f.conf$step] # Selected random-effects structure
summary(f.conf$fit)

coefs <- summary(f.conf$fit)$coefficients

# Rows of the design matrix, to express the effects in ms
X <- function(group_c, condition) design_row(f.conf$fit, group_c, condition)

# H1: Group x Suppression, smaller suppression in the load group
h1 <-
  as_tibble(coefs["group_c:suppression", , drop = FALSE]) %>%
  transmute(
    estimate = Estimate,
    se = `Std. Error`,
    df,
    t = `t value`,
    p = pt(t, df),
    ci_lower = estimate - qt(.975, df) * se,
    ci_upper = estimate + qt(.975, df) * se,
    supported = p < alpha
  ) %>%
  bind_cols(ms_effect(f.conf$fit, rbind(X(.5, "LPDL"), X(-.5, "HPDL")), rbind(X(.5, "HPDL"), X(-.5, "LPDL"))))

h1

# H2: TOST of the suppression effect in the load group
w_supp <- load_weights(f.conf$fit, "suppression")
df_supp <- lmerTest::contest(f.conf$fit, w_supp, joint = FALSE)$df

tost <-
  hypotheses(
    f.conf$fit,
    hypothesis = unname(w_supp),
    equivalence = c(-delta, delta),
    df = df_supp,
    conf_level = .96
  )

h2 <-
  tibble(
    estimate = tost$estimate,
    se = tost$std.error,
    df = df_supp,
    ci96_lower = tost$conf.low,
    ci96_upper = tost$conf.high,
    ci_lower = estimate - qt(.975, df) * se,
    ci_upper = estimate + qt(.975, df) * se,
    p_noninf = tost$p.value.noninf,
    p_nonsup = tost$p.value.nonsup,
    p_equiv = tost$p.value.equiv,
    supported = p_equiv < alpha
  ) %>%
  bind_cols(ms_effect(f.conf$fit, rbind(X(.5, "LPDL")), rbind(X(.5, "HPDL"))))

h2

# Outcome-neutral criteria ----
# ON1: all participants who completed the session, before exclusions
completed <-
  raw_load %>%
  count(participant_uid) %>%
  filter(n == 720) %>%
  pull(participant_uid)

f.on1 <-
  glmer(
    cbind(correct, n - correct) ~ 1 + (1 | participant_uid),
    data = filter(verification, participant_uid %in% completed, n == 72),
    family = binomial
  )

summary(f.on1)

on1 <-
  tibble(
    n = n_distinct(f.on1@frame$participant_uid),
    intercept = fixef(f.on1)[[1]],
    se = sqrt(vcov(f.on1)[1, 1]),
    z = intercept / se,
    p = pnorm(z, lower.tail = FALSE),
    accuracy = plogis(intercept),
    met = p < alpha
  )

on1

# ON2: capture effect in the load group
w_capt <- load_weights(f.conf$fit, "capture")
df_capt <- lmerTest::contest(f.conf$fit, w_capt, joint = FALSE)$df

capt_load <- hypotheses(f.conf$fit, hypothesis = unname(w_capt), df = df_capt)

on2 <-
  tibble(
    estimate = capt_load$estimate,
    se = capt_load$std.error,
    df = df_capt,
    t = estimate / se,
    p = pt(t, df, lower.tail = FALSE),
    met = p < alpha
  )

on2

# Exploratory analyses ----
# Search accuracy: time-outs are not errors, because the control group had no limit
d_acc <-
  bind_rows(
    raw_control %>%
      filter(participant_uid %in% control_clean$participant_uid, rt <= 3000) %>%
      mutate(group_c = -.5),
    raw_load %>%
      filter(participant_uid %in% load_clean$participant_uid, !is.na(rt)) %>%
      mutate(group_c = .5)
  ) %>%
  filter(!(block == 1 & trial_in_block <= 20)) %>%
  add_model_vars() %>%
  group_by(participant_uid, group_c, condition, suppression, capture) %>%
  summarise(n = n(), correct = sum(correct), .groups = "drop")

f.acc <- fit_glmer_planned(d_acc, "cbind(correct, n - correct) ~ group_c * (suppression + capture)", re_steps$no_time)

re_steps$no_time[f.acc$step] # Selected random-effects structure
summary(f.acc$fit)

accuracy <- as_tibble(summary(f.acc$fit)$coefficients, rownames = "term")
accuracy

# Time course of suppression: Group x Suppression x Time, smaller increase in the load group
time_steps <- c(
  "((suppression + capture) * log_time_end | participant_uid)",
  "(suppression + capture + log_time_end | participant_uid)",
  "(suppression + capture | participant_uid)",
  "(log_time_end | participant_uid)",
  "(1 | participant_uid)"
)

f.time <- fit_lmer_planned(d_RT, "log_rt ~ group_c * (suppression + capture) * log_time_end", time_steps)

time_steps[f.time$step] # Selected random-effects structure
summary(f.time$fit)

time_course <-
  as_tibble(summary(f.time$fit)$coefficients["group_c:suppression:log_time_end", , drop = FALSE]) %>%
  transmute(estimate = Estimate, se = `Std. Error`, df, t = `t value`, p = pt(t, df))

time_course

# Explicit knowledge: Group x Distance, weaker effect of distance in the load group
aw_load <-
  sessions %>%
  filter(phase == "awareness", participant_uid %in% load_clean$participant_uid) %>%
  group_by(participant_uid) %>%
  slice_tail(n = 1) %>% # Last attempt
  ungroup()

aw_dist <- c(circ_dist(aw_control$chosen, aw_control$HPDL), circ_dist(aw_load$aware_r2, aw_load$hpdl))
aw_group <- rep(c(-.5, .5), c(nrow(aw_control), nrow(aw_load)))

m_aw <- fit_glmmtmb(choice_sets(aw_dist, aw_group), group = TRUE)

awareness <-
  tibble(
    n_control = nrow(aw_control),
    n_load = nrow(aw_load),
    estimate = m_aw$b_int,
    se = m_aw$se_int,
    z = estimate / se,
    p = pnorm(z, lower.tail = FALSE)
  )

awareness

# Data of the results figure ----
add_group <- function(d) {
  mutate(d, group = ifelse(group_c < 0, "Control", "Load"))
}

# RTs by condition: each participant, and the mean with its 95% CI
fig_rt_ind <-
  d_RT %>%
  add_group() %>%
  group_by(group, participant_uid, condition) %>%
  summarise(rt = mean(rt), .groups = "drop")

fig_rt <-
  fig_rt_ind %>%
  group_by(group, condition) %>%
  summarise(ci = qt(.975, n() - 1) * sd(rt) / sqrt(n()), rt = mean(rt), .groups = "drop")

fig_rt

# RTs by condition and block
fig_blocks <-
  d_RT %>%
  add_group() %>%
  group_by(group, participant_uid, block, condition) %>%
  summarise(rt = mean(rt), .groups = "drop") %>%
  as.data.frame() %>%
  Rmisc::summarySEwithin(
    measurevar = "rt",
    betweenvars = "group",
    withinvars = c("block", "condition"),
    idvar = "participant_uid"
  ) %>%
  mutate(block = as.numeric(as.character(block)))

fig_blocks

# Model predictions by condition and block
cm <- condition_contrasts()

new_time <- function(group_c, condition, block) {
  tibble(
    group_c = group_c,
    condition = condition,
    block = block,
    suppression = cm[condition, "suppression"],
    capture = cm[condition, "capture"],
    log_time_end = log(block) - log(6),
    participant_uid = NA
  )
}

fig_grid <- expand.grid(
  group_c = c(-.5, .5),
  condition = c("HPDL", "LPDL", "ND"),
  block = seq(1, 6, .1),
  stringsAsFactors = FALSE
)

fig_preds <-
  predictions(
    f.time$fit,
    newdata = new_time(fig_grid$group_c, fig_grid$condition, fig_grid$block),
    re.form = NA,
    transform = \(x) exp(x + (sigma(f.time$fit)^2) / 2)
  ) %>%
  as_tibble() %>%
  add_group() %>%
  dplyr::select(group, condition, block, estimate, conf.low, conf.high)

# Conditional suppression effect by block in each group
X_time <- function(group_c, condition, block) {
  model.matrix(~ group_c * (suppression + capture) * log_time_end, new_time(group_c, condition, block))
}

fig_effects <-
  distinct(fig_grid, group_c, block) %>%
  pmap(function(group_c, block) {
    ms_effect(f.time$fit, X_time(group_c, "LPDL", block), X_time(group_c, "HPDL", block)) %>%
      mutate(group_c = group_c, block = block)
  }) %>%
  bind_rows() %>%
  add_group()

# Observed suppression effect by block
fig_supp <-
  d_RT %>%
  add_group() %>%
  filter(condition %in% c("HPDL", "LPDL")) %>%
  group_by(group, participant_uid, block, condition) %>%
  summarise(rt = mean(rt), .groups = "drop") %>%
  pivot_wider(names_from = condition, values_from = rt) %>%
  mutate(suppression = LPDL - HPDL) %>%
  group_by(group, block) %>%
  summarise(
    estimate = mean(suppression, na.rm = TRUE),
    se = sd(suppression, na.rm = TRUE) / sqrt(sum(!is.na(suppression))),
    .groups = "drop"
  )

fig_supp

# Probability of choosing a location at each distance from the HPDL
fig_aware <-
  tibble(group_c = aw_group, distance = aw_dist) %>%
  count(group_c, distance) %>%
  complete(group_c, distance = 0:4, fill = list(n = 0)) %>%
  group_by(group_c) %>%
  mutate(
    prop = n / sum(n),
    p_location = prop / k_dist[distance + 1],
    se = sqrt(prop * (1 - prop) / sum(n)) / k_dist[distance + 1]
  ) %>%
  ungroup() %>%
  add_group()

fig_aware

# Predictions of the awareness model
fig_aware_pred <-
  bind_rows(aware_predictions(m_aw, -.5), aware_predictions(m_aw, .5)) %>%
  add_group()

fig_aware_pred

save_analysis_objects(
  "analysis",
  simulated = simulated,
  exclusions = exclusions,
  random_structure = re_steps$no_time[f.conf$step],
  h1 = h1,
  h2 = h2,
  on1 = on1,
  on2 = on2,
  time_course = time_course,
  awareness = awareness,
  accuracy = accuracy,
  fig_rt_ind = fig_rt_ind,
  fig_rt = fig_rt,
  fig_blocks = fig_blocks,
  fig_preds = fig_preds,
  fig_effects = fig_effects,
  fig_supp = fig_supp,
  fig_aware = fig_aware,
  fig_aware_pred = fig_aware_pred
)
