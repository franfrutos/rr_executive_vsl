# Counting on Suppression: online task

Online version of the experimental task of the registered report **"Counting on Suppression: Does Learning to Ignore Distractors Depend on Executive Resources? A Registered Report"**. It is the visual search task (*additional singleton* paradigm) of Vicente-Conesa et al. (2023), with a concurrent counting task in the load group, written in [jsPsych](https://www.jspsych.org/7.2/) 7.2.3 with the [jspsych-psychophysics](https://jspsychophysics.hes.kyushu-u.ac.jp/) plugin. It follows the original program of Vicente-Conesa et al. (2023), with the online procedure of VMAC_selective (Garre-Frutos et al., 2026): browser check, consent, full screen and calibration with the virtual chin-rest.

## Quick start

- **Locally:** serve the folder (for example, `python -m http.server` in this folder) and open `http://localhost:8000/index.html?group=load`. At the end, the task offers to download the data as a CSV.
- **Online:** upload the folder as a JATOS study component. Each participant is assigned at random to one group, keeping both groups balanced. The data are sent to JATOS after each block and at the end.

### URL parameters

| Parameter | Values | Default |
|---|---|---|
| `group` | `load`: search and counting tasks; `control`: search task only. Both groups have a 3-s response window | assigned at random: in JATOS, the group with fewer sessions started in the batch (keeps both groups balanced) |
| `blocks` | number of blocks | 6 |
| `prac` | `false` skips the practice | `true` |
| `cal` | `false` skips consent, full screen and calibration (for checks; sizes then use `px2deg_default`) | `true` |
| `ID` | participant code | random (6 digits and 2 letters), shown at the end to claim the credit |

For example, `index.html?group=control&blocks=1&cal=false` runs a short check of the control group.

## Settings

Everything that can be adjusted is in `src/init.js`:

| Setting | What it does |
|---|---|
| `px2deg_default` | pixels per degree when the calibration is skipped (`cal=false`) |
| `iti_ms`, `fixation_ms`, `feedback_ms`, `response_window_ms` | timing (ms); the response window of each group (`null`: until response) |
| `n_blocks`, `n_per_condition`, `period_lengths`, `n_practice` | design |
| `key_for`, `verify_keys` | response keys |
| `view_dist_range` | viewing distances accepted in the calibration (mm) |
| `completion_url` | optional page to go to at the end (e.g., to grant the credit) |

Stimulus sizes are set in degrees of visual angle at the top of `src/helper.js`.

All texts shown to participants (in Spanish) are in `src/text.js`. The information sheet and consent are placeholders (**to do**).

## Data

One row per search trial, count verification, comprehension check, awareness-test attempt and post-experiment questionnaire, with the type of row in `phase`. The main columns are:

| `phase` | Main columns |
|---|---|
| `practice`, `experimental` | `block`, `trial_in_block`, `trial`, `condition` (ND/HPDL/LPDL), `condition_code`, `target_pos`, `distractor_pos` (0 = none), `design`, `target_orientation`, `orientations`, `response_key`, `correct`, `timed_out`, `rt_ms`, and the period of the counting task (`period`, `period_length`, `trial_in_period`, `count_orientation`, `counted_target`) |
| `practice_verification`, `verification` | `true_count`, `shown_count`, `shown_is_correct`, `verify_key`, `verify_correct`, `verify_rt_ms` |
| `quiz_search`, `quiz_count` | `quiz_attempt`, `quiz_answer`, `quiz_correct` |
| `awareness` | `aware_attempt`, `aware_r1` (1–6 rating), `aware_r2` (chosen location, 1–8), `aware_repeat` |
| `consent`, `questions` | `consent`; `distraction_rating` (1–5), `opinion_text` |

Every row also carries the session information: participant code, group, random seed, high-probability location (`hpdl`), demographics, calibration (`px2deg`, `viewing_distance`), browser, operating system, window size and refresh rate, and the number of times the participant left the window (`n_blur`) or the full screen (`n_fullscreen_exit`) up to that row.

Locations are numbered 1–8 clockwise from 9 o'clock. Conditions and designs keep the codes of the original program.

## Folder structure

```
index.html          loads jsPsych, the plugins and the task
src/init.js         settings and initialization of jsPsych
src/helper.js       stimuli, trial lists and drawing functions
src/text.js         texts shown to participants and text-only screens (consent, calibration, instructions)
src/experiment.js   the session: instructions, practice, blocks, counting task, awareness test, data
src/stylesheet.css  styles
src/img/dni.jpg     card for the calibration
jspsych/            jsPsych 7.2.3, plugins and jspsych-psychophysics 3.3.0
```

## Reference

- Vicente-Conesa, F., Giménez-Fernández, T., Luque, D., & Vadillo, M. A. (2023). Learning to suppress a distractor may not be unconscious. *Attention, Perception, & Psychophysics*. https://doi.org/10.3758/s13414-022-02608-x
