// The session: consent, calibration,
// instructions, practice, blocks of the search task (with the counting task in
// the load group), the awareness test and the data. The timeline at the end gives
// the order of the session
const run_experiment = () => {
    const timeline = [];

    // Setting parameters (URL): group (load or control; by default assigned at
    // random, see assign_group()), blocks, prac, cal (false skips consent and
    // calibration, for checks) and ID
    const urlvar = (jatos_run && jatos.urlQueryParameters != undefined) ? jatos.urlQueryParameters :
        (jsPsych.data.urlVariables() != undefined) ? jsPsych.data.urlVariables() :
        {}; // If no urlvar
    group = (["load", "control"].includes(urlvar.group)) ? urlvar.group : assign_group();
    const blocks = (urlvar.blocks != undefined && !isNaN(Number(urlvar.blocks))) ? Number(urlvar.blocks) : n_blocks;
    const prac = urlvar.prac != "false";
    const cal = urlvar.cal != "false";
    const window_ms = response_window_ms[group];
    ID = (urlvar.ID != undefined) ? urlvar.ID : randomID();

    // Location of the high-probability distractor: randomly chosen for each
    // participant, fixed for the session
    const hpdl = random(1, 9);

    console.log(`Experiment Parameters
       Group: ${group}. Blocks: ${blocks}. Practice: ${prac}. Calibration: ${cal}. HPDL: ${hpdl}. ID: ${ID}.`);

    jsPsych.data.addProperties({
        participant: ID,
        group: group,
        hpdl: hpdl,
        fixation_ms: fixation_ms,
        response_window_ms: (window_ms != null) ? window_ms : "",
    });
    if (!cal) jsPsych.data.addProperties({px2deg: px2deg, viewing_distance: ""}); // no calibration

    // Trial lists ----
    const label = (trials, phase, block, first = 1) => {
        return trials.map((t, i) => ({...t, phase: phase, block: block, trial_in_block: first + i}));
    }
    const examples = make_practice(n_examples).map(add_features);
    const practice_trials = label(make_practice(n_practice).map(add_features), "practice", 0);
    const practice_period = make_period(
        label(make_practice(practice_period_length).map(add_features), "practice", 0, n_practice + 1),
        {length: practice_period_length, shown_is_correct: random(0, 2), orientation: ["horizontal", "vertical"][random(0, 2)]},
        1);
    const block_list = [];
    for (let b = 1; b <= blocks; b++) {
        const trials = label(make_block(hpdl).map(add_features), "experimental", b);
        if (group == "load") { // consecutive trials of the block form the periods
            let start = 0;
            const periods = make_periods().map((p, k) => {
                const period = make_period(trials.slice(start, start + p.length), p, k + 1);
                start += p.length;
                return period;
            });
            block_list.push({block: b, periods: periods});
        } else {
            block_list.push({block: b, trials: trials});
        }
    }

    let trial_overall = 0, fail = true, quiz_attempts = {search: 0, count: 0};

    // Search trials ----
    // Blank (ITI) -> fixation -> search display until response (or until the end
    // of the response window)
    const search = {
        type: jsPsychPsychophysics,
        stimuli: () => draw_display(jsPsych.timelineVariable("t")),
        choices: Object.values(key_for),
        background_color: colors.white,
        canvas_width: () => Math.round(px(display_size_deg)),
        canvas_height: () => Math.round(px(display_size_deg)),
        response_start_time: iti_ms + fixation_ms,
        trial_duration: (window_ms != null) ? iti_ms + fixation_ms + window_ms : null,
        data: () => {
            const t = jsPsych.timelineVariable("t");
            return {
                phase: t.phase,
                block: t.block,
                trial_in_block: t.trial_in_block,
                condition: t.condition,
                condition_code: condition_codes[t.condition],
                target_pos: t.target_pos,
                distractor_pos: t.distractor_pos,
                design: t.design,
                target_shape: t.target_shape,
                items_colour: t.items_colour,
                singleton_colour: t.singleton_colour,
                target_orientation: t.target_orientation,
                orientations: t.orientations.map((o) => (o == "horizontal") ? "H" : "V").join(""),
                period: (t.period != undefined) ? t.period : "",
                period_length: (t.period != undefined) ? t.period_length : "",
                trial_in_period: (t.period != undefined) ? t.trial_in_period : "",
                count_orientation: (t.period != undefined) ? t.count_orientation : "",
                counted_target: (t.period != undefined) ? t.counted_target : "",
            }
        },
        on_finish: (data) => {
            const t = jsPsych.timelineVariable("t");
            data.timed_out = (data.response === null) ? 1 : 0;
            data.response_key = (data.response === null) ? "" : data.response;
            data.correct = (!data.timed_out && jsPsych.pluginAPI.compareKeys(data.response, key_for[t.target_orientation])) ? 1 : 0;
            data.rt_ms = (data.rt === null) ? "" : Math.round(data.rt * 10) / 10;
            data.trial = ++trial_overall;
            data.n_blur = n_blur;
            data.n_fullscreen_exit = n_fullscreen_exit;
        },
    };

    // Error feedback (a time-out gets the same feedback as an error)
    const feedback = {
        type: jsPsychHtmlKeyboardResponse,
        stimulus: () => {
            const size = Math.round(px(feedback_size_deg));
            return `<p class="feedback" style="font-size: ${size}px;">${FEEDBACK[jsPsych.timelineVariable("t").phase]}</p>`;
        },
        choices: "NO_KEYS",
        trial_duration: feedback_ms,
    };

    const if_feedback = {
        timeline: [feedback],
        conditional_function: () => {
            return jsPsych.data.get().last(1).values()[0].correct == 0;
        }
    }

    const search_trials = (trials) => {
        return {
            timeline: [search, if_feedback],
            timeline_variables: trials.map((t) => ({t: t})),
        }
    }

    // Counting task (load group) ----
    // One period: the orientation to count, the search trials, and the
    // verification of the count: a number (the true count in half of the periods,
    // an incorrect one in the other half) and the answer, S (it matches the count)
    // or N. In the practice, feedback on the answer
    const run_period = (period) => {
        const word = ORIENTATION_WORD[period.orientation];
        const phase = period.trials[0].phase;
        const start = {
            type: jsPsychHtmlKeyboardResponse,
            stimulus: () => `<h2>${NEW_PERIOD}</h2>
                <p style="font-size: 1.6rem;">${COUNT_THIS(word)}</p>
                ${bar_html(period.orientation)}
                <p class="hint">${START_PERIOD}</p>`,
            choices: [" "],
        };
        const verify = {
            type: jsPsychHtmlKeyboardResponse,
            stimulus: `<p style="font-size: 1.6rem;">${VERIFY_LABEL(word)}</p>
                <p class="verify-number">${period.shown_count}</p>
                <p style="font-size: 1.6rem;">${VERIFY_QUESTION}</p>
                <p class="hint">${VERIFY_HINT}</p>`,
            choices: Object.keys(verify_keys),
            data: {
                phase: (phase == "practice") ? "practice_verification" : "verification",
                block: period.trials[0].block,
                period: period.index,
                period_length: period.length,
                count_orientation: period.orientation,
                true_count: period.true_count,
                shown_count: period.shown_count,
                shown_is_correct: (period.shown_count == period.true_count) ? 1 : 0,
            },
            on_finish: (data) => {
                data.verify_key = data.response.toLowerCase();
                data.verify_correct = (verify_keys[data.verify_key] == data.shown_is_correct) ? 1 : 0;
                data.verify_rt_ms = Math.round(data.rt * 10) / 10;
                data.n_blur = n_blur;
                data.n_fullscreen_exit = n_fullscreen_exit;
            },
        };
        const verify_feedback = {
            type: jsPsychHtmlKeyboardResponse,
            stimulus: () => {
                const correct = jsPsych.data.get().last(1).values()[0].verify_correct;
                const msg = (correct) ? VERIFY_CORRECT : VERIFY_INCORRECT(period.true_count, period.orientation);
                return `<p style="font-size: 1.6rem;">${msg}</p>`;
            },
            choices: "NO_KEYS",
            trial_duration: practice_feedback_ms,
        };
        return {
            timeline: (phase == "practice") ?
                [start, search_trials(period.trials), verify, verify_feedback] :
                [start, search_trials(period.trials), verify],
        }
    }

    // Blocks, with a break after each block (the data are sent to JATOS) ----
    const rest = (b) => {
        return {
            type: jsPsychHtmlKeyboardResponse,
            stimulus: wrapper(((b < blocks) ? BREAK(b, blocks) : LAST_BLOCK) + CONTINUE),
            choices: [' '],
            on_finish: () => {
                if (jatos_run) {
                    const results = jsPsych.data.get().filterCustom(filter_custom).json();
                    jatos.submitResultData(results);
                }
            }
        }
    }

    const experiment_blocks = block_list.map((b) => {
        return {
            timeline: [...((group == "load") ? b.periods.map(run_period) : [search_trials(b.trials)]), rest(b.block)],
        }
    });

    // Instructions, with a comprehension check (as in VMAC_selective): if any
    // answer is wrong, a message and the instructions again ----
    const nav = {
        allow_keys: false,
        show_clickable_nav: true,
        button_label_previous: "Retroceder",
        button_label_next: "Seguir",
    };

    const instructions_search = {
        type: jsPsychInstructions,
        pages: () => [
            wrapper(TITLE_INSTRUCTIONS + INSTRUCTIONS_1),
            ...examples.map((t, i) => wrapper(EXAMPLE_OF(i + 1, n_examples) + `<img src="${display_image(t)}" style="max-height: 70vh;">`)),
            keys_page(),
            wrapper(TITLE_INSTRUCTIONS + instructions_2(window_ms) + QUIZ_INTRO),
        ],
        ...nav,
        on_start: () => task_screen(false),
    };

    const instructions_count = {
        type: jsPsychInstructions,
        pages: COUNT_INSTRUCTIONS.map((p) => wrapper(TITLE_INSTRUCTIONS + p)),
        ...nav,
        on_start: () => task_screen(false),
    };

    // The first option of each question is the correct one
    const quiz = (questions, name) => {
        return {
            type: jsPsychSurveyMultiChoice,
            questions: () => {
                return shuffle(questions.map((q) => ({
                    prompt: q.prompt,
                    name: q.name,
                    options: shuffle([...q.options]),
                    required: true,
                    horizontal: false
                })));
            },
            button_label: "Continuar",
            on_finish: (data) => {
                fail = questions.some((q) => data.response[q.name] != q.options[0]);
                data.phase = `quiz_${name}`;
                data.quiz_attempt = ++quiz_attempts[name];
                data.quiz_answer = JSON.stringify(data.response);
                data.quiz_correct = (fail) ? 0 : 1;
                data.response = "";
            }
        }
    }

    const repeat = {
        type: jsPsychHtmlButtonResponse,
        stimulus: () => {
            return wrapper((!fail) ? QUIZ_PASSED : QUIZ_FAILED);
        },
        choices: () => {
            return (!fail) ? ["Continuar"] : ["Volver a leer las instrucciones"];
        },
    }

    const procedure_inst_search = {
        timeline: [instructions_search, quiz(SEARCH_QUIZ, "search"), repeat],
        loop_function: () => {
            return fail;
        },
    }

    const procedure_inst_count = {
        timeline: [instructions_count, quiz(COUNT_QUIZ, "count"), repeat],
        loop_function: () => {
            return fail;
        },
    }

    // Reminders before each practice and before the experiment ----
    const reminder = (title, body, footer) => {
        return {
            type: jsPsychHtmlKeyboardResponse,
            stimulus: wrapper(`<h2>${title}</h2>${body}<p class="hint">${footer}</p>`),
            choices: [' '],
            on_finish: () => task_screen(true),
            post_trial_gap: 500,
        }
    }

    // Practice of the search (as in the original: target-only displays); in the
    // load group, then the instructions of the counting task, a comprehension
    // check and one practice period ----
    const if_practice = {
        timeline: [reminder(REMINDER_PRACTICE, REMEMBER + REMINDER_KEYS, START_PRACTICE), search_trials(practice_trials)],
        conditional_function: () => {
            return prac;
        }
    }

    const if_practice_count = {
        timeline: [reminder(REMINDER_PERIOD, REMEMBER + REMINDER_KEYS + REMINDER_COUNT, START_PRACTICE), run_period(practice_period)],
        conditional_function: () => {
            return prac;
        }
    }

    const if_count = {
        timeline: [procedure_inst_count, if_practice_count],
        conditional_function: () => {
            return group == "load";
        }
    }

    const pre_exp = reminder(REMINDER_EXPERIMENT,
        PRACTICE_END + REMINDER_KEYS + ((group == "load") ? REMINDER_COUNT : "") + STRUCTURE(blocks),
        START_EXPERIMENT);

    // Awareness test (AwarenessTest.m, Experiment 1), with the keyboard as in the
    // original: Q1 on the 1-6 scale; Q2 the location (eight numbered circles); then
    // the chosen location in blue, with the option to repeat the whole test. Every
    // attempt is saved ----
    let aware_attempt = 0, aware_r1, aware_r2, aware_repeat = false;

    // Keyboard choice: a number key selects (and highlights) an option, another
    // number or Backspace changes it, and Enter confirms it
    const select_trial = (stimulus, n, draw, on_finish) => {
        return {
            type: jsPsychHtmlKeyboardResponse,
            stimulus: stimulus,
            choices: "NO_KEYS",
            on_load: () => {
                let selected = null;
                draw(selected);
                const listener = (e) => {
                    if (e.key == "Enter" && selected != null) {
                        document.removeEventListener("keydown", listener);
                        jsPsych.finishTrial({response: selected});
                    } else if (e.key == "Backspace") {
                        selected = null;
                        draw(selected);
                    } else if (/^[1-9]$/.test(e.key) && Number(e.key) <= n) {
                        selected = Number(e.key);
                        draw(selected);
                    }
                };
                document.addEventListener("keydown", listener);
            },
            on_finish: on_finish,
        }
    }

    const options_html = (labels, id) => {
        return `<div class="options" id="${id}">${labels.map((l, i) =>
            `<div class="option" data-n="${i + 1}"><div class="number">${i + 1}</div><div>${l}</div></div>`).join("")}</div>`;
    }

    const highlight = (id, selected) => {
        document.querySelectorAll(`#${id} .option`).forEach((o) => o.classList.toggle("selected", Number(o.dataset.n) == selected));
    }

    const locations = `<canvas id="locations" style="max-height: 60vh;"></canvas>`;

    const aware_q1 = select_trial(wrapper(AWARENESS_Q1 + options_html(AWARENESS_SCALE, "scale") + SELECT_HINT), 6,
        (selected) => highlight("scale", selected),
        (data) => { aware_r1 = data.response; });

    const aware_intro = {
        type: jsPsychHtmlKeyboardResponse,
        stimulus: wrapper(AWARENESS_INTRO + CONTINUE),
        choices: [' '],
    };

    const aware_q2 = select_trial(wrapper(AWARENESS_Q2 + locations + AWARENESS_Q2_PROMPT + SELECT_HINT), 8,
        (selected) => draw_locations(document.getElementById("locations"), selected),
        (data) => { aware_r2 = data.response; });

    const aware_confirm = select_trial(wrapper(AWARENESS_CONFIRM + locations + options_html(AWARENESS_CONFIRM_OPTIONS, "confirm") + SELECT_HINT), 2,
        (selected) => {
            draw_locations(document.getElementById("locations"), aware_r2);
            highlight("confirm", selected);
        },
        (data) => {
            aware_repeat = data.response == 2;
            data.phase = "awareness";
            data.aware_attempt = ++aware_attempt;
            data.aware_r1 = aware_r1;
            data.aware_r2 = aware_r2;
            data.aware_repeat = (aware_repeat) ? 1 : 0;
        });

    const awareness = {
        timeline: [aware_q1, aware_intro, aware_q2, aware_confirm],
        loop_function: () => {
            return aware_repeat;
        }
    }

    // Consent and calibration (VMAC_selective) ----
    const preload = {
        type: jsPsychPreload,
        images: ['src/img/dni.jpg'],
        max_load_time: 60000,
        show_detailed_errors: true
    }

    const if_resize = {
        timeline: [resize, if_repeat_cal],
        loop_function: () => {
            return fail_cal;
        },
    }

    const if_cal = {
        timeline: [consent_proc, welcome, instructions_cal, full_on, if_resize],
        conditional_function: () => {
            return cal;
        }
    }

    const if_full_off = {
        timeline: [full_off],
        conditional_function: () => {
            return cal;
        }
    }

    // End: the participant code, to claim the credit ----
    const goodbye = {
        type: jsPsychHtmlButtonResponse,
        stimulus: wrapper(GOODBYE + PARTICIPANT_CODE(ID)),
        choices: [EXIT],
    }

    const download = {
        type: jsPsychHtmlButtonResponse,
        stimulus: `<p>¿Quieres descargar los datos?</p>`,
        choices: ["Sí", "No"],
        on_finish: (data) => {
            if (data.response == 0) {
                jsPsych.data.get().filterCustom(filter_custom).localSave("csv", `ast_${ID}.csv`);
            }
        }
    }

    const if_download = {
        timeline: [download],
        conditional_function: () => {
            return !jatos_run;
        }
    }

    timeline.push(check, preload, if_cal, procedure_inst_search, if_practice, if_count, pre_exp,
        ...experiment_blocks, awareness, if_full_off, questions, goodbye, if_download);

    jsPsych.run(timeline);
}
// Go!
if (jatos_run) {
    jatos.onLoad(() => run_experiment());
} else {
    run_experiment();
}
