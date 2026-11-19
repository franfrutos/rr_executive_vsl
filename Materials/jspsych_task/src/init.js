// Settings of the task and initialization of jsPsych

// Run in JATOS server?
const jatos_run = window.jatos !== undefined || false;
if (jatos_run) console.log("Run in Jatos server.")
else console.log("Run in local machine.")

// ---- Geometry ----
// Stimulus sizes are in degrees of visual angle (helper.js) and are converted to
// pixels with the pixels per degree from the calibration
const px2deg_default = 40; // only when the calibration is skipped (?cal=false)

// ---- Timing (ms) ----
const iti_ms = 500;            // blank screen before the fixation
const fixation_ms = 500;
const feedback_ms = 3000;      // feedback after an error or a time-out
// Response window of each group (null = until response, as in VC2023). Both
// groups have the same window, so they only differ in the counting task
const response_window_ms = {load: 3000, control: 3000};

// ---- Design (makeBlock.m, CreaPractica.m) ----
const n_blocks = 6;
const n_per_condition = {ND: 40, HPDL: 52, LPDL: 28}; // 120 trials per block
const condition_codes = {ND: 100, HPDL: 200, LPDL: 300, practice: 0}; // codes of the original data
const n_examples = 3;  // example displays in the instructions
const n_practice = 3;  // practice trials (target only)

// ---- Counting task (load group) ----
// 12 periods per block (four of 8, 10 and 12 trials) in random order; the
// orientation to count is drawn at random for each period; the number shown at
// the end is correct in 6 periods per block (2 of each length)
const period_lengths = [8, 8, 8, 8, 10, 10, 10, 10, 12, 12, 12, 12];
const verify_keys = {s: 1, n: 0}; // S = yes (the number matches the count), N = no
const practice_period_length = 8;  // one practice period (target only), with feedback
const practice_feedback_ms = 2500;

// ---- Responses ----
// Left arrow = horizontal line, up arrow = vertical line
const key_for = {horizontal: "arrowleft", vertical: "arrowup"};

// ---- Online ----
const view_dist_range = [390, 660]; // viewing distance accepted in the calibration (mm)
const completion_url = "";          // optional: page to go to at the end (e.g., to grant the credit)

// Initialize jsPsych
let n_blur = 0, n_fullscreen_exit = 0; // browser interactions during the session
const jsPsych = initJsPsych({
    on_interaction_data_update: (data) => {
        if (data.event == "blur") n_blur++;
        if (data.event == "fullscreenexit") n_fullscreen_exit++;
    },
    on_finish: () => {
        if (jatos_run) {
            const results = jsPsych.data.get().filterCustom(filter_custom).json();
            if (completion_url != "") jatos.endStudyAndRedirect(completion_url, results)
            else jatos.endStudy(results);
        }
    }
});

const seed = jsPsych.randomization.setSeed(Math.floor(Math.random()*9999));
jsPsych.data.addProperties({
    rng_seed: seed
});

console.log(`Random seed: ${seed}`)

var px2deg = px2deg_default, viewDist, fail_cal = false, not_consent = false, ID, group;
