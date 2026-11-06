## -----------------------------------------------------------------------------
## Author: Francisco Garre-Frutos
## -----------------------------------------------------------------------------

# Installing (if needed) and loading the packages ----
if (!require(pacman)) {
  install.packages("pacman")
  library(pacman)
}

p_load(here, dplyr, tidyr)

setwd(here::here())

# Control group: Vicente-Conesa et al. (2023), Experiments 1-3 ----
# Columns used from the trial-level data of https://osf.io/xtsa2/ (semicolon
# separated, decimal comma). T.orientation: 1 = horizontal (left arrow), 2 =
# vertical (up arrow). Keys other than the two arrows are errors, although the
# original files score them as correct
raw_control <- bind_rows(lapply(1:3, function(e) {
  read.csv2(sprintf("Input/vicente_conesa_2023/data-exp-%d-rt.csv", e), stringsAsFactors = FALSE)
})) %>%
  transmute(
    experiment = as.integer(sub("Experiment ", "", experiment)),
    subj,
    participant_uid = sprintf("E%d_%d", experiment, subj),
    block = as.integer(block),
    trial_in_block = as.integer(trial) - 120L * (block - 1L),
    condition = factor(condition, levels = c("HPDL", "LPDL", "ND")),
    correct = as.integer((T.orientation == 1 & response == "LeftArrow") | (T.orientation == 2 & response == "UpArrow")),
    rt = RT
  )

# Exclusions, as for the load group (preprocess_search() in functions.R)
control_clean <- preprocess_search(raw_control) %>%
  dplyr::select(participant_uid, experiment, subj, block, condition, rt, log_rt,
                log_time_end, suppression, capture)

# Awareness test of Experiment 1 (the same test as in the load group): location
# chosen as the HPDL (aw.test.2), for the participants included above
aw_control <- read.csv2("Input/vicente_conesa_2023/data-exp-1-aw.csv") %>%
  transmute(experiment = 1L, subj, HPDL, chosen = aw.test.2) %>%
  inner_join(distinct(control_clean, experiment, subj), by = c("experiment", "subj"))
