// Stimuli and trial lists: the stimulus sizes, the trial and period generators,
// and the drawing functions

// ---- Stimuli ----
// Sizes in degrees of visual angle, from Wang & Theeuwes (2018, JEP:HPP; 2018,
// APP): eight items on an imaginary circle with a radius of 4°, a 1° x 1° fixation
// cross, circles with a radius of 1°, diamonds of 2° x 2°, and lines of 0.15° x 1°
// (APP; the JEP:HPP paper gives 0.3° x 1.5°). Sizes they do not report keep their
// proportion in the original program: outline widths relative to each shape (pen
// of 7 px in a 120-px circle and of 10 px in a 150-px diamond), and the other sizes
// relative to the circle (120 px = 2°).
// Locations 1-8, clockwise from 9 o'clock (numbering of the original and of the
// awareness test): left, upper left, top, upper right, right, lower right, bottom,
// lower left. The canvas y grows downwards
const radius_deg = 4;
const diagonal_deg = radius_deg / Math.SQRT2;
const positions_deg = [[-radius_deg, 0], [-diagonal_deg, -diagonal_deg], [0, -radius_deg], [diagonal_deg, -diagonal_deg],
                       [radius_deg, 0], [diagonal_deg, diagonal_deg], [0, radius_deg], [-diagonal_deg, diagonal_deg]];
const circle_diameter_deg = 2;        // outer diameter: the pen is drawn inwards, as in FrameOval
const circle_pen_deg = 2 * 7 / 120;   // 0.12°
const diamond_size_deg = 2;           // the pen is centred on the edges, as in FramePoly
const diamond_pen_deg = 2 * 10 / 150; // 0.13°
const line_length_deg = 1;            // black, as in the original
const line_width_deg = 0.15;
const fixation_size_deg = 1;
const fixation_pen_deg = circle_pen_deg;
const deg_per_original_px = 2 / 120;
const indicator_diameter_deg = 200 * deg_per_original_px; // blue circle around the target in the examples
const indicator_pen_deg = 8 * deg_per_original_px;
const feedback_size_deg = 50 * deg_per_original_px;       // error feedback, Times New Roman
const number_size_deg = 24 * deg_per_original_px;         // numbers of the awareness test
const display_size_deg = 12;          // canvas: the eight items, the indicator and a margin
const font = "'Times New Roman', Times, serif";

const colors = {white: "#FFFFFF", black: "#000000", red: "#FF0000", green: "#00FF00", blue: "#0000FF"};

// Designs of the original (ChooseDesign), drawn at random on each trial:
// target shape, colour of the target and non-singleton items, singleton colour
const designs = {
    1: ["diamond", "green", "red"],
    2: ["diamond", "red", "green"],
    3: ["circle", "green", "red"],
    4: ["circle", "red", "green"],
};

// Pixels of the participant's screen for a size in degrees (px2deg: pixels per
// degree, from the calibration)
const px = (deg) => deg * px2deg;

// ---- Drawing ----
// The eight items of a search display centred on (cx, cy), drawn on a canvas
// context. In the instruction examples, a blue outline circles the target; it is
// drawn right after the target, as in the original, and can touch a neighbour
const draw_items = (ctx, t, cx, cy, indicator = false) => {
    const other_shape = (t.target_shape == "diamond") ? "circle" : "diamond";
    for (let i = 0; i < 8; i++) {
        const [x, y] = [cx + px(positions_deg[i][0]), cy + px(positions_deg[i][1])];
        const shape = (i + 1 == t.target_pos) ? t.target_shape : other_shape;
        ctx.strokeStyle = colors[(i + 1 == t.distractor_pos) ? t.singleton_colour : t.items_colour];
        ctx.lineJoin = "miter";
        ctx.beginPath();
        if (shape == "circle") {
            ctx.lineWidth = px(circle_pen_deg);
            ctx.arc(x, y, px((circle_diameter_deg - circle_pen_deg) / 2), 0, 2 * Math.PI);
        } else {
            const h = px(diamond_size_deg / 2);
            ctx.lineWidth = px(diamond_pen_deg);
            ctx.moveTo(x, y - h);
            ctx.lineTo(x + h, y);
            ctx.lineTo(x, y + h);
            ctx.lineTo(x - h, y);
            ctx.closePath();
        }
        ctx.stroke();
        draw_bar(ctx, x, y, t.orientations[i]);
        if (indicator && i + 1 == t.target_pos) {
            ctx.strokeStyle = colors.blue;
            ctx.lineWidth = px(indicator_pen_deg);
            ctx.beginPath();
            ctx.arc(x, y, px((indicator_diameter_deg - indicator_pen_deg) / 2), 0, 2 * Math.PI);
            ctx.stroke();
        }
    }
}

// The line inside each item
const draw_bar = (ctx, x, y, orientation) => {
    const [w, h] = (orientation == "horizontal") ? [line_length_deg, line_width_deg] : [line_width_deg, line_length_deg];
    ctx.fillStyle = colors.black;
    ctx.fillRect(x - px(w) / 2, y - px(h) / 2, px(w), px(h));
}

// Stimuli of a search trial (psychophysics plugin): blank (ITI), fixation, and the
// display from the end of the fixation until the trial ends
const draw_display = (t) => {
    return [{
        obj_type: 'cross',
        line_length: px(fixation_size_deg),
        line_width: px(fixation_pen_deg),
        line_color: colors.black,
        origin_center: true,
        startX: 0,
        startY: 0,
        show_start_time: iti_ms,
        show_end_time: iti_ms + fixation_ms,
    },
    {
        obj_type: 'manual',
        origin_center: true,
        startX: 0,
        startY: 0,
        show_start_time: iti_ms + fixation_ms,
        drawFunc: (stimulus, canvas, context) => draw_items(context, t, stimulus.currentX, stimulus.currentY),
    }];
}

// A display as an image, for the instruction examples
const display_image = (t) => {
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = Math.round(px(display_size_deg));
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = colors.white;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    draw_items(ctx, t, canvas.width / 2, canvas.height / 2, true);
    return canvas.toDataURL();
}

// A line of the task as an html element (response keys and orientation to count),
// in a box of the same height for both orientations
const bar_html = (orientation) => {
    const [w, h] = (orientation == "horizontal") ? [line_length_deg, line_width_deg] : [line_width_deg, line_length_deg];
    return `<div style="height: ${px(line_length_deg)}px; display: flex; align-items: center; justify-content: center; margin: 30px auto;">
        <div style="width: ${px(w)}px; height: ${px(h)}px; background-color: ${colors.black};"></div></div>`;
}

// Locations of the awareness test: eight green circles with their numbers; the
// chosen one in blue
const draw_locations = (canvas, chosen) => {
    canvas.width = canvas.height = Math.round(px(display_size_deg));
    const ctx = canvas.getContext("2d");
    const [cx, cy] = [canvas.width / 2, canvas.height / 2];
    ctx.fillStyle = colors.white;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    for (let i = 0; i < 8; i++) {
        const [x, y] = [cx + px(positions_deg[i][0]), cy + px(positions_deg[i][1])];
        ctx.strokeStyle = (chosen == i + 1) ? colors.blue : colors.green;
        ctx.lineWidth = px(circle_pen_deg);
        ctx.beginPath();
        ctx.arc(x, y, px((circle_diameter_deg - circle_pen_deg) / 2), 0, 2 * Math.PI);
        ctx.stroke();
        ctx.fillStyle = colors.black;
        ctx.font = `${Math.round(px(number_size_deg))}px ${font}`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(i + 1, x, y);
    }
}

// ---- Trial lists (makeBlock.m, CreaNoDistractor.m, CreaHighProb.m, CreaLowProb.m, CreaPractica.m) ----
// One block of 120 trials in random order. Locations are 1-8. As in the original:
// HPDL trials put the target at a random location other than the HPDL; LPDL trials
// draw the distractor location at random (with replacement) from the seven non-HPDL
// locations and the target from the seven locations other than the distractor's
// (HPDL included); ND trials draw the target from all eight locations
const make_block = (hpdl) => {
    const trials = [];
    for (let i = 0; i < n_per_condition.ND; i++) {
        trials.push({condition: "ND", distractor_pos: 0, target_pos: random(1, 9)});
    }
    for (let i = 0; i < n_per_condition.HPDL; i++) {
        trials.push({condition: "HPDL", distractor_pos: hpdl, target_pos: random(1, 9, [hpdl])});
    }
    for (let i = 0; i < n_per_condition.LPDL; i++) {
        const distractor = random(1, 9, [hpdl]);
        trials.push({condition: "LPDL", distractor_pos: distractor, target_pos: random(1, 9, [distractor])});
    }
    return shuffle(trials);
}

// Target-only displays (CreaPractica.m): the target at a random location
const make_practice = (n) => {
    return Array.from({length: n}, () => ({condition: "practice", distractor_pos: 0, target_pos: random(1, 9)}));
}

// Design (shapes and colours) and line orientations, drawn at random for each
// trial and each item, as in the original
const add_features = (t) => {
    const design = random(1, 5);
    const [target_shape, items_colour, singleton_colour] = designs[design];
    const orientations = Array.from({length: 8}, () => ["horizontal", "vertical"][random(0, 2)]);
    return {
        ...t,
        design: design,
        target_shape: target_shape,
        items_colour: items_colour,
        singleton_colour: (t.distractor_pos) ? singleton_colour : "",
        target_orientation: orientations[t.target_pos - 1],
        orientations: orientations,
    };
}

// Periods of one block (load group), in random order: length, whether the number
// shown at the end is correct (half of the periods of each length), and the
// orientation to count (drawn at random for each period)
const make_periods = () => {
    let periods = [];
    for (let n of [...new Set(period_lengths)]) {
        const k = period_lengths.filter((l) => l == n).length;
        const shown_correct = shuffle([...Array(Math.floor(k / 2)).fill(1), ...Array(k - Math.floor(k / 2)).fill(0)]);
        periods = periods.concat(shown_correct.map((c) => ({length: n, shown_is_correct: c})));
    }
    return shuffle(periods).map((p) => ({...p, orientation: ["horizontal", "vertical"][random(0, 2)]}));
}

// An incorrect number for the verification of a period of n trials:
// Binomial(n, .5), redrawn if it equals the true count
const wrong_count = (true_count, n) => {
    while (true) {
        let k = 0;
        for (let i = 0; i < n; i++) k += (Math.random() < .5) ? 1 : 0;
        if (k != true_count) return k;
    }
}

// The trials of a period, with the information of the counting task, and the
// number shown at the end. Every target with that orientation counts, whatever
// the response (errors and time-outs included)
const make_period = (trials, period, index) => {
    const out = trials.map((t, j) => ({
        ...t,
        period: index,
        period_length: period.length,
        trial_in_period: j + 1,
        count_orientation: period.orientation,
        counted_target: (t.target_orientation == period.orientation) ? 1 : 0,
    }));
    const true_count = out.reduce((acc, t) => acc + t.counted_target, 0);
    const shown_count = (period.shown_is_correct) ? true_count : wrong_count(true_count, period.length);
    return {...period, index: index, trials: out, true_count: true_count, shown_count: shown_count};
}

// ---- Group ----
// Random assignment that keeps both groups balanced: in JATOS, the group with
// fewer sessions started in the batch (at random if tied); locally, at random
const assign_group = () => {
    if (!jatos_run) return ["control", "load"][random(0, 2)];
    const started = jatos.batchSession.get("started") || {control: 0, load: 0};
    const g = (started.control == started.load) ? ["control", "load"][random(0, 2)] :
        (started.control < started.load) ? "control" : "load";
    started[g] = started[g] + 1;
    jatos.batchSession.set("started", started)
        .then(() => console.log(`Group ${g} assigned.`))
        .catch(() => console.log("Batch session synchronization failed."));
    return g;
}

// ---- Utilities (VMAC_selective) ----
const shuffle = (array) => {
    let currentIndex = array.length, randomIndex;
    while (currentIndex != 0) {
        randomIndex = Math.floor(Math.random() * currentIndex);
        currentIndex--;
        [array[currentIndex], array[randomIndex]] = [array[randomIndex], array[currentIndex]];
    }
    return array;
}

// A random integer in [min, max), other than those in no
const random = (min, max, no) => {
    let rnum = Math.floor(Math.random() * (max - min)) + min;
    if (typeof no !== 'undefined') {
        while (no.indexOf(rnum) >= 0) {
            rnum = Math.floor(Math.random() * (max - min)) + min;
        }
    }
    return rnum;
}

// Generate a random ID for participants
const randomID = (num = 6, lett = 2) => {
    let ID = '';
    const letter = Array.from(Array(26)).map((e, i) => i + 65).map((x) => String.fromCharCode(x));
    for (let i = 0; i < num; i++) ID += random(0, 10).toString();
    for (let i = 0; i < lett; i++) ID += letter[random(0, letter.length)];
    return ID;
}

// Functions to use in text.js
const wrapper = (text, width = false, amount = 100, bottom = false) => {
    return `<div class = "inst" style = \"${(width) ? `min-width:${amount}%;` : ""}
    ${(bottom) ? "margin-bottom:60px;" : ""}\"> ${text}</div>`
}

// Hidden cursor during the search task
const task_screen = (on) => {
    document.body.style.cursor = (on) ? 'none' : 'auto';
}

// ---- Calibration (VMAC_selective): practice of the card and blind-spot tasks ----
let ball_animation_frame_id = null;
let state = false;

const animBall = () => {
    const ball = document.querySelector("#virtual-chinrest-circle");
    const dx = -.5; // same as ball_speed parameter
    const x = parseFloat(ball.style.left); // allow changes below one px
    ball.style.left = `${x + dx}px`;
    ball_animation_frame_id = requestAnimationFrame(animBall);
}

const setBall = () => {
    const ball = document.querySelector("#virtual-chinrest-circle");
    if (ball != null) {
        const square = document.querySelector("#virtual-chinrest-square");
        const rectX = document.querySelector(".inst").getBoundingClientRect().width - 30;
        const ballX = rectX * 0.85; // define where the ball is
        ball.style.left = `${ballX}px`;
        square.style.left = `${rectX}px`;
    }
}

const cal_c = (e) => {
    if (e.key == " " || e.code == "Space" || e.keyCode == 32) {
        if (!state) {
            state = true;
            animBall();
        } else {
            state = false;
            cancelAnimationFrame(ball_animation_frame_id);
            setBall();
        }
    }
}

const aspect_ratio = 85.6 / 53;
const ResizePhase = () => {
    const display_element = document.querySelector(".inst");
    // Event listeners for mouse-based resize
    let dragging = false;
    let origin_x, origin_y;
    let cx, cy, curr_width, curr_height, to_height, to_width;
    const scale_div = display_element.querySelector("#item");
    if (scale_div != null) {
        function mouseupevent() {
            dragging = false;
        }
        display_element.addEventListener("mouseup", mouseupevent);
        function mousedownevent(e) {
            e.preventDefault();
            dragging = true;
            origin_x = e.pageX;
            origin_y = e.pageY;
            cx = parseInt(scale_div.style.width);
            cy = parseInt(scale_div.style.height);
        }
        display_element
            .querySelector("#jspsych-resize-handle")
            .addEventListener("mousedown", mousedownevent);
        function resizeevent(e) {
            if (dragging) {
                curr_height = scale_div.style.height;
                curr_width = scale_div.style.width;
                let dx = e.pageX - origin_x;
                let dy = e.pageY - origin_y;
                if (Math.abs(dx) >= Math.abs(dy)) {
                    to_width = Math.round(Math.max(20, cx + dx * 2));
                    to_height = Math.round(Math.max(20, cx + dx * 2) / aspect_ratio);
                }
                else {
                    to_height = Math.round(Math.max(20, cy + dy * 2));
                    to_width = Math.round(aspect_ratio * Math.max(20, cy + dy * 2));
                }
                // This limits the maximun size
                if (to_height >= 300 || to_height <= 100) {
                    scale_div.style.height = curr_height + "px";
                    scale_div.style.width = curr_width + "px";
                } else {
                    scale_div.style.height = to_height + "px";
                    scale_div.style.width = to_width + "px";
                }
            }
        }
        display_element.addEventListener("mousemove", resizeevent);
    }
}

// ---- Data ----
// Rows saved: search trials, verifications, comprehension checks, awareness test
// and post-experiment questions (every row has a phase)
const filter_custom = (data) => {
    if (!data) return false;
    return data.phase !== undefined;
};
