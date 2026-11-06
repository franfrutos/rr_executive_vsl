## -----------------------------------------------------------------------------
## Author: Francisco Garre-Frutos
## -----------------------------------------------------------------------------

# Loading packages----
source("scripts/functions.R")

if (!require(pacman)) {
  install.packages("pacman")
  library(pacman)
}

p_load(dplyr,# Data wrangling
       tidyr,
       osfr, # Download of the open data
       rstan, # Needed by the cached fits (loaded before brms)
       brms, # Bayesian meta-regression
       cmdstanr # Stan backend of brms
)

ensure_project_dirs()

# Vicente-Conesa et al. (2024) ----
# Open data from https://osf.io/b8g2v/, downloaded only if they are not already
# here. Accuracy >= 75% reproduces the published Ns
vc24_dir <- "Input/vicente_conesa_2024"
vc24_file <- file.path(vc24_dir, "data.csv")
dir.create(vc24_dir, showWarnings = FALSE)

if (!file.exists(vc24_file)) {
  osf_retrieve_node("b8g2v") %>%
    osf_ls_files() %>%
    filter(name == "data.csv") %>%
    osf_download(path = vc24_dir, conflicts = "skip")
}

vc24_scores <-
  read.csv2(vc24_file, stringsAsFactors = FALSE) %>%
  filter(mean.accuracy >= .75, as.logical(valid.RT), condition %in% c("HPDL", "LPDL")) %>%
  group_by(experiment, load, subj, condition) %>%
  summarise(rt = mean(vs.RT), .groups = "drop") %>%
  pivot_wider(names_from = condition, values_from = rt) %>%
  mutate(suppression = LPDL - HPDL)

vc24_welch <-
  vc24_scores %>%
  group_by(experiment) %>%
  summarise(t_welch = t.test(suppression[load == "High"], suppression[load == "Low"])$statistic, .groups = "drop")

vc24 <-
  vc24_scores %>%
  group_by(experiment, load) %>%
  summarise(n = n(), m = mean(suppression), sd = sd(suppression), .groups = "drop") %>%
  left_join(vc24_welch, by = "experiment") %>%
  mutate(exp = as.integer(sub("Experiment ", "", experiment)))

vc24

# Experiments of the meta-analysis ----
# Gao and Theeuwes (2020): suppression effects read from their Figures 2 and 4,
# and t values of Experiment 1. Vicente-Conesa et al. (2024): recomputed above
study_codes <- c(gao2019 = "GT20", vicenteconesa2024 = "VCV24")

meta <-
  bind_rows(
    read.csv("Input/meta_analysis/gao2020_effects.csv") %>%
      mutate(key = "gao2019", design = "W", n_noload = 24, n_load = 24),
    vc24 %>%
      pivot_wider(id_cols = c(exp, t_welch), names_from = load, values_from = c(n, m, sd)) %>%
      transmute(key = "vicenteconesa2024", design = "B", exp, n_noload = n_Low, n_load = n_High,
                m_noload = m_Low, m_load = m_High, sd_noload = sd_Low, sd_load = sd_High, t_welch)
  )

# Gao and Theeuwes (2020), Experiment 2 ----
# SDs from the error bars of their Figure 4, and the correlation between the
# HPDL and LPDL RTs from Experiment 1 (same task, design and N)
gao_se <- read.csv("Input/meta_analysis/gao2020_figure_se.csv")

gt1 <- meta[meta$key == "gao2019" & meta$exp == "1", ]

r_gao_exp1 <- c(
  low = r_from_sd(cell_sd(gao_se, 1, "low"), gt1$m_noload / gt1$t_noload * sqrt(gt1$n_noload)),
  high = r_from_sd(cell_sd(gao_se, 1, "high"), gt1$m_load / gt1$t_load * sqrt(gt1$n_load))
)

r_gao <- tanh(mean(atanh(r_gao_exp1))) # Averaged with Fisher's z

i <- meta$key == "gao2019" & meta$exp == "2"
meta[i, c("sd_noload", "sd_load")] <-
  list(sd_from_r(cell_sd(gao_se, 2, "none"), r_gao), sd_from_r(cell_sd(gao_se, 2, "load"), r_gao))

gao_sd <- tibble(r_pooled = r_gao, sd_supp_noload = meta$sd_noload[i], sd_supp_load = meta$sd_load[i])
gao_sd

# Correlation between both loads in within-participant designs: test-retest
# correlation of the suppression effect (Ivanov et al., 2024, Table 2, all participants)
r_within <- .26

# Effect sizes ----
es <-
  meta %>%
  mutate(
    se0 = coalesce(sd_noload / sqrt(n_noload), abs(m_noload) / t_noload),
    se1 = coalesce(sd_load / sqrt(n_load), abs(m_load) / t_load),
    sd0 = se0 * sqrt(n_noload),
    sd1 = se1 * sqrt(n_load),
    r = r_within,
    code = paste0(study_codes[key], ".", exp),
    sd_pool = ifelse(
      design == "B",
      sqrt(((n_noload - 1) * sd0^2 + (n_load - 1) * sd1^2) / (n_noload + n_load - 2)),
      sqrt((sd0^2 + sd1^2) / 2)
    )
  )

# Observed modulation of each experiment (forest plot, Borenstein et al., 2009, eq. 4.28)
es <-
  es %>%
  mutate(
    d_raw = ifelse(design == "B", t_welch * sqrt(1 / n_noload + 1 / n_load), (m_load - m_noload) / sd_pool),
    j = 1 - 3 / (4 * ifelse(design == "W", n_load - 1, n_noload + n_load - 2) - 1),
    d_mod = j * d_raw,
    v_mod = j^2 * ifelse(
      design == "W",
      (1 / n_load + d_raw^2 / (2 * n_load)) * 2 * (1 - r),
      1 / n_noload + 1 / n_load + d_raw^2 / (2 * (n_noload + n_load))
    )
  )

# Suppression effect under each load (g_z and its sampling variance)
by_load <-
  bind_rows(
    es %>%
      transmute(key, code, design, r, load = "lower load", n = n_noload, ms = m_noload, sd = sd0, sd_pool,
                df = ifelse(design == "W", n_load - 1, n_noload + n_load - 2)),
    es %>%
      transmute(key, code, design, r, load = "higher load", n = n_load, ms = m_load, sd = sd1, sd_pool,
                df = ifelse(design == "W", n_load - 1, n_noload + n_load - 2))
  ) %>%
  mutate(
    j = 1 - 3 / (4 * df - 1),
    g = j * ms / sd_pool,
    v_g = j^2 * ((sd / sd_pool)^2 / n + (ms / sd_pool)^2 / (2 * df)),
    load_c = ifelse(load == "higher load", .5, -.5)
  ) %>%
  arrange(code, load_c) %>%
  mutate(es_id = factor(row_number()))

by_load

# Bayesian meta-regression ----
# Fits cached in output/models
priors <- c(
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(0, 1), class = "b"),
  prior(normal(0, 0.5), class = "sd"),
  prior(constant(1), class = "sigma")
)

fit <- fit_brms(by_load, "output/models/meta_brms", priors)
summary(fit)

res <- summarise_fit(fit, "primary")

# Sensitivity analysis: without Gao and Theeuwes (2020, Experiment 2)
fit_sens <- fit_brms(filter(by_load, code != "GT20.2"), "output/models/meta_brms_without_gt20_2", priors)

res_sens <- summarise_fit(fit_sens, "sensitivity")

meta_sum <- bind_rows(res$summary, res_sens$summary)
meta_crit <- bind_rows(res$criteria, res_sens$criteria)
meta_sum
meta_crit

# Forest plot (Figure 1A) ----
fp_rows <-
  es %>%
  mutate(year = as.integer(sub(".*?(\\d{2})$", "\\1", study_codes[key]))) %>%
  arrange(year, code) %>%
  transmute(code, row = 1.8 + rev(seq_len(n())))

offsets <- c(lower = .17, higher = -.17, mod = 0)

forest_d <-
  bind_rows(
    by_load %>%
      transmute(code, marker = ifelse(load == "lower load", "lower", "higher"), est = g, se = sqrt(v_g)),
    es %>%
      transmute(code, marker = "mod", est = d_mod, se = sqrt(v_mod))
  ) %>%
  left_join(fp_rows, by = "code") %>%
  mutate(
    panel = ifelse(marker == "mod", "mod", "load"),
    y = row + offsets[marker],
    lo = est - 1.96 * se,
    hi = est + 1.96 * se
  )

save_analysis_objects(
  "meta_analysis",
  k_effects = nrow(by_load),
  meta_sum = meta_sum,
  meta_crit = meta_crit,
  r_within = r_within,
  gao_sd = gao_sd,
  forest_d = forest_d,
  draws = dplyr::select(res$draws, lower, higher, mod)
)
