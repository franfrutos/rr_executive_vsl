"""
The session (experiment.js in the jsPsych tasks): instructions, practice,
blocks of the search task (with the counting task in the load group), the
awareness test and the data file. Experiment.run() gives the order of the
session.
"""

import csv
import os
import random
from datetime import datetime

from psychopy import core, gui, visual
from psychopy.hardware import keyboard

from .init import *
from .helper import *
from .text import *

# Data: one CSV per session, one row per trial, verification, comprehension
# question and attempt of the awareness test (see README.md)
COLUMNS = ["participant", "group", "date", "seed", "hpdl", "age", "handedness", "gender",
           "fixation_s", "response_window_s", "size_units", "frame_rate",
           "phase", "block", "trial_in_block", "trial", "condition", "condition_code",
           "target_pos", "distractor_pos", "design", "target_shape", "items_colour", "singleton_colour",
           "target_orientation", "orientations", "response_key", "correct", "timed_out", "rt_ms",
           "period", "period_length", "trial_in_period", "count_orientation", "counted_target",
           "true_count", "shown_count", "shown_is_correct", "verify_key", "verify_correct", "verify_rt_ms",
           "quiz_attempt", "quiz_question", "quiz_answer", "quiz_correct",
           "aware_attempt", "aware_r1", "aware_r2", "aware_repeat"]


class Experiment:

    def __init__(self, participant, demographics):
        fixed = os.environ.get("AST_SEED") if AUTO else None  # same displays in two code checks
        self.seed = int(fixed) if fixed else random.SystemRandom().randrange(2 ** 31)
        self.rng = random.Random(self.seed)
        self.hpdl = self.rng.randint(1, 8)  # randomly chosen for each participant, fixed for the session
        self.win, self.u, self.to_pix, self.screen_w, self.screen_h, self.frame_rate = setup_window()
        self.kb = keyboard.Keyboard()
        self.display = Display(self.win, self.u, self.to_pix)
        self.fixation = visual.TextStim(self.win, "+", height=self.u(50), font=FONT, color=BLACK, colorSpace="rgb1")
        self.feedback = {phase: visual.TextStim(self.win, msg, height=self.u(50), font=FONT, color=BLACK, colorSpace="rgb1")
                         for phase, msg in FEEDBACK.items()}
        self.trial_overall = 0
        self.quiz_attempts = {}
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.info = {"participant": participant, "group": GROUP, "date": stamp, "seed": self.seed, "hpdl": self.hpdl,
                     "fixation_s": FIXATION_S, "response_window_s": RESPONSE_WINDOW_S if RESPONSE_WINDOW_S else "",
                     "size_units": SIZE_UNITS, "frame_rate": round(self.frame_rate, 2), **demographics}
        os.makedirs(DATA_DIR, exist_ok=True)
        self.path = os.path.join(DATA_DIR, f"ast_{participant}_{stamp}.csv")
        self.file = open(self.path, "w", newline="", encoding="utf-8")
        self.writer = csv.DictWriter(self.file, fieldnames=COLUMNS)
        self.writer.writeheader()

    # ---- helpers -----------------------------------------------------------

    def save_row(self, row):
        self.writer.writerow({**self.info, **row})
        self.file.flush()

    def n_frames(self, seconds):
        return max(1, int(round(seconds * self.frame_rate)))

    def screenshot(self, name):
        if AUTO:
            folder = os.path.join(DATA_DIR, "screenshots")
            os.makedirs(folder, exist_ok=True)
            self.win.getMovieFrame(buffer="front")
            self.win.saveMovieFrames(os.path.join(folder, f"{name}.png"))

    def quit(self):
        self.file.close()
        self.win.close()
        core.quit()

    def text(self, txt, size_px=24, y=None, align="center", width_px=1100, color=BLACK, pos_px=None, bold=False):
        """A text block. By default it is centred on the screen; y places its
        top at that proportion of the screen height (from the top), and pos_px
        centres it on a point of the original layout. Lines are wrapped at
        width_px (or 90% of the screen)."""
        stim = visual.TextStim(self.win, txt, height=self.u(size_px), font=FONT, color=color, colorSpace="rgb1",
                               wrapWidth=min(self.u(width_px), self.screen_w * .9), alignText=align,
                               anchorVert="center" if y is None else "top", bold=bold)
        if pos_px is not None:
            stim.pos = (self.u(pos_px[0]), self.u(pos_px[1]))
        else:
            stim.pos = (0, 0 if y is None else (.5 - y) * self.screen_h)
        return stim

    def page(self, body, title=None, footer=CONTINUE):
        """A text screen: optional title, body in a centred column, footer."""
        stims = [self.text(title, size_px=44, y=.1)] if title else []
        stims.append(self.text(body, align="left"))
        if footer:
            stims.append(self.text(footer, size_px=20, y=.9, color=GREY))
        return stims

    def wait_space(self, stims, name=None, keys=("space",)):
        """Show the stimuli until one of the keys (by default the space bar) is
        pressed, and return its name."""
        for s in stims:
            s.draw()
        self.win.flip()
        if name:
            self.screenshot(name)
        if AUTO:
            core.wait(.05)
            return keys[0]
        self.kb.clearEvents()
        while True:
            for k in self.kb.getKeys(keyList=list(keys) + [QUIT_KEY], waitRelease=False):
                if k.name == QUIT_KEY:
                    self.quit()
                return k.name
            core.wait(.005)

    def paged(self, pages, last_footer=CONTINUE, names=None):
        """Instruction pages (lists of stimuli, without footer): the space bar
        goes to the next page and Backspace to the previous one."""
        i = 0
        while i < len(pages):
            footer = last_footer if i == len(pages) - 1 else CONTINUE
            if i > 0:
                footer = footer[:-1] + BACK
            nav = self.text(footer, size_px=20, y=.93, color=GREY)
            key = self.wait_space(pages[i] + [nav], name=names[i] if names else None,
                                  keys=("space",) if i == 0 else ("space", "backspace"))
            i += 1 if key == "space" else -1

    def quiz(self, questions, name):
        """Comprehension check: each question on its own screen, answered with
        a number key and Enter. Returns True if every answer is correct. In
        auto mode, the first attempt at the counting check fails on purpose."""
        self.quiz_attempts[name] = self.quiz_attempts.get(name, 0) + 1
        attempt = self.quiz_attempts[name]
        all_correct = True
        for q, (prompt, options, correct) in enumerate(self.rng.sample(questions, len(questions))):
            order = self.rng.sample(range(len(options)), len(options))
            right = order.index(correct) + 1
            stims = [self.text(QUESTION_OF.format(q + 1, len(questions)), size_px=20, y=.08, color=GREY),
                     self.text(prompt, size_px=28, y=.2, width_px=1000)]
            boxes = [self.list_option((0, 60 - k * 90), (1000, 70), k + 1, options[o]) for k, o in enumerate(order)]
            hint = self.text(SELECT_HINT, size_px=20, y=.93, color=GREY)
            auto_answer = (right % len(options)) + 1 if name == "count" and attempt == 1 and q == 0 else right

            def draw(sel):
                for s in stims:
                    s.draw()
                self.draw_options(boxes, sel)
                hint.draw()
            answer = self.select_with_keys(draw, range(1, len(options) + 1), auto_value=auto_answer,
                                           name=f"quiz_{name}" if q == 0 and attempt == 1 else None)
            all_correct &= answer == right
            self.save_row({"phase": f"quiz_{name}", "quiz_attempt": attempt, "quiz_question": prompt,
                           "quiz_answer": options[order[answer - 1]], "quiz_correct": int(answer == right)})
        return all_correct

    def instructions_with_check(self, make_pages, questions, name, last_footer):
        """Instruction pages followed by a comprehension check; if any answer is
        wrong, a message and the pages again."""
        while True:
            pages = make_pages()
            self.paged(pages, last_footer=last_footer)
            if self.quiz(questions, name):
                return
            self.wait_space(self.page(QUIZ_FAILED, footer=BACK_TO_INSTRUCTIONS),
                            name=f"quiz_failed_{name}")

    def reminder(self, title, body, footer, name="reminder"):
        """'Estás a punto de empezar...' screen with the response keys."""
        self.wait_space([self.text(title, size_px=36, y=.15), self.text(body, align="left"),
                         self.text(footer, size_px=20, y=.93, color=GREY)], name=name)

    def select_with_keys(self, draw, valid, auto_value, name=None):
        """Keyboard choice: a number key selects (and highlights) an option,
        another number or Backspace changes it, and Enter confirms it."""
        selected = None
        self.kb.clearEvents()
        while True:
            draw(auto_value if AUTO else selected)
            self.win.flip()
            if AUTO:
                if name:
                    self.screenshot(name)
                return auto_value
            for k in self.kb.getKeys(waitRelease=False):
                key = k.name.replace("num_", "")
                if key == QUIT_KEY:
                    self.quit()
                elif key in ("return", "enter") and selected is not None:
                    return selected
                elif key == "backspace":
                    selected = None
                elif key.isdigit() and int(key) in valid:
                    selected = int(key)
            core.wait(.005)

    def option_box(self, centre_px, size_px, number, label):
        """A numbered option (box, number and label) for select_with_keys."""
        u = self.u
        x, y = centre_px
        box = visual.Rect(self.win, width=u(size_px[0]), height=u(size_px[1]), pos=(u(x), u(y)),
                          lineWidth=self.to_pix(2), colorSpace="rgb1")
        num = self.text(str(number), size_px=30, pos_px=(x, y + size_px[1] * .2), bold=True)
        lab = self.text(label, size_px=18, pos_px=(x, y - size_px[1] * .22), width_px=size_px[0] - 16)
        return box, num, lab

    def list_option(self, centre_px, size_px, number, label):
        """A numbered option in a list (box and 'n.  label', left-aligned)."""
        u = self.u
        x, y = centre_px
        box = visual.Rect(self.win, width=u(size_px[0]), height=u(size_px[1]), pos=(u(x), u(y)),
                          lineWidth=self.to_pix(2), colorSpace="rgb1")
        lab = visual.TextStim(self.win, f"{number}.   {label}", height=u(22), font=FONT, color=BLACK, colorSpace="rgb1",
                              pos=(u(x - size_px[0] / 2 + 24), u(y)), anchorHoriz="left", alignText="left",
                              wrapWidth=u(size_px[0] - 48))
        return box, lab

    def draw_options(self, options, selected):
        for i, (box, *texts) in enumerate(options):
            on = selected == i + 1
            box.fillColor = LIGHT_BLUE if on else WHITE
            box.lineColor = BLUE if on else GREY
            for s in (box, *texts):
                s.draw()

    # ---- search trials -----------------------------------------------------

    def search_trial(self, trial, phase, block, trial_in_block, period_info=None):
        """Blank (ITI) -> fixation -> search display until response (or until
        the response window ends) -> error feedback after an error."""
        for _ in range(self.n_frames(ITI_S)):
            self.win.flip()
        for _ in range(self.n_frames(FIXATION_S)):
            self.fixation.draw()
            self.win.flip()
        self.display.set_trial(trial)
        self.kb.clearEvents()  # FlushEvents in the original
        self.win.callOnFlip(self.kb.clock.reset)
        self.display.draw()
        self.win.flip()
        if AUTO and trial_in_block == 1:
            self.screenshot(f"search_{phase}_block{block}_{trial['condition']}")
        max_frames = self.n_frames(RESPONSE_WINDOW_S) if RESPONSE_WINDOW_S else None
        frame, response = 1, None
        auto_timeout = AUTO and max_frames and self.rng.random() < .1  # code check of the time-outs
        while response is None and (max_frames is None or frame < max_frames):
            if AUTO and not auto_timeout:  # 90% correct
                key = KEY_FOR[trial["target_orientation"]] if self.rng.random() < .9 else "left"
                response = (key, None)
                break
            for k in self.kb.getKeys(keyList=list(KEY_FOR.values()) + [QUIT_KEY], waitRelease=False):
                if k.name == QUIT_KEY:
                    self.quit()
                response = (k.name, k.rt)
                break
            if response is None:
                self.display.draw()
                self.win.flip()
                frame += 1
        timed_out = response is None
        key, rt = response if response else ("", None)
        correct = int(not timed_out and key == KEY_FOR[trial["target_orientation"]])
        if not correct:  # a time-out gets the same feedback as an error
            for _ in range(self.n_frames(FEEDBACK_S)):
                self.feedback[phase].draw()
                self.win.flip()
        self.trial_overall += 1
        self.save_row({
            "phase": phase, "block": block, "trial_in_block": trial_in_block, "trial": self.trial_overall,
            "condition": trial["condition"], "condition_code": CONDITION_CODES[trial["condition"]],
            "target_pos": trial["target_pos"], "distractor_pos": trial["distractor_pos"],
            "design": trial["design"], "target_shape": trial["target_shape"], "items_colour": trial["items_colour"],
            "singleton_colour": trial["singleton_colour"], "target_orientation": trial["target_orientation"],
            "orientations": "".join("H" if o == "horizontal" else "V" for o in trial["orientations"]),
            "response_key": key, "correct": correct, "timed_out": int(timed_out),
            "rt_ms": round(rt * 1000, 1) if rt is not None else "", **(period_info or {})})

    # ---- counting task (load group) ------------------------------------------

    def run_period(self, trials, period, phase, block, index, first_trial):
        """One period: the orientation to count, the search trials, and the
        verification of the count. Every target with that orientation counts,
        whatever the response (errors and time-outs included)."""
        assert len(trials) == period["length"]
        word = ORIENTATION_WORD[period["orientation"]]
        w, h = (LINE_WIDTH_PX, LINE_LENGTH_PX) if period["orientation"] == "vertical" else (LINE_LENGTH_PX, LINE_WIDTH_PX)
        line = visual.Rect(self.win, width=self.u(w), height=self.u(h), pos=(0, self.u(-40)), fillColor=BLACK,
                           lineColor=None, colorSpace="rgb1")
        self.wait_space([self.text(NEW_PERIOD, size_px=44, y=.1),
                         self.text(COUNT_THIS.format(word), size_px=30, pos_px=(0, 90)),
                         line, self.text(START_PERIOD, size_px=20, y=.9, color=GREY)],
                        name="period_start" if index == 1 and block <= 1 else None)
        true_count = 0
        for j, trial in enumerate(trials):
            counted = int(trial["target_orientation"] == period["orientation"])
            true_count += counted
            self.search_trial(trial, phase, block, first_trial + j, period_info={
                "period": index, "period_length": period["length"], "trial_in_period": j + 1,
                "count_orientation": period["orientation"], "counted_target": counted})
        self.verify(period, true_count, phase, block, index)

    def verify(self, period, true_count, phase, block, index):
        """A number (the true count in half of the periods, an incorrect one in
        the other half) and the answer: S, it matches the count; N, it does not.
        In the practice, feedback on the answer."""
        shown = true_count if period["shown_is_correct"] else wrong_count(true_count, period["length"], self.rng)
        word = ORIENTATION_WORD[period["orientation"]]
        stims = [self.text(VERIFY_LABEL.format(word), size_px=30, pos_px=(0, 120)),
                 self.text(str(shown), size_px=80, pos_px=(0, 20), bold=True),
                 self.text(VERIFY_QUESTION, size_px=30, pos_px=(0, -90)),
                 self.text(VERIFY_HINT, size_px=20, y=.9, color=GREY)]
        for s in stims:
            s.draw()
        self.kb.clearEvents()
        self.win.callOnFlip(self.kb.clock.reset)
        self.win.flip()
        if AUTO:
            if index == 1 and block <= 1:
                self.screenshot(f"verification_{phase}")
            right = "s" if shown == true_count else "n"
            key, rt = (right if self.rng.random() < .85 else ("n" if right == "s" else "s")), None
        else:
            key = None
            while key is None:
                for k in self.kb.getKeys(keyList=list(VERIFY_KEYS) + [QUIT_KEY], waitRelease=False):
                    if k.name == QUIT_KEY:
                        self.quit()
                    key, rt = k.name, k.rt
                    break
                core.wait(.002)
        verify_correct = int(VERIFY_KEYS[key] == int(shown == true_count))
        if phase == "practice":
            orientation = period["orientation"]
            msg = VERIFY_CORRECT if verify_correct else VERIFY_INCORRECT.format(true_count, orientation)
            fb = self.text(msg, size_px=30)
            for _ in range(self.n_frames(PRACTICE_FEEDBACK_S)):
                fb.draw()
                self.win.flip()
            if AUTO:
                self.screenshot("verification_practice_feedback")
        self.save_row({
            "phase": "practice_verification" if phase == "practice" else "verification", "block": block,
            "period": index, "period_length": period["length"], "count_orientation": period["orientation"],
            "true_count": true_count, "shown_count": shown, "shown_is_correct": int(shown == true_count),
            "verify_key": key, "verify_correct": verify_correct,
            "verify_rt_ms": round(rt * 1000, 1) if rt is not None else ""})

    # ---- parts of the session ----------------------------------------------

    def keys_page(self):
        """The response keys: the slide of the original (Diapositiva5.JPG),
        redrawn with its text, the lines of the task and the two arrow keys,
        plus the finger placement."""
        u = self.u
        stims = [self.text(KEYS_TOP, size_px=26, y=.08, align="left")]
        # up arrow (key cap 64 px); the left arrow is the same shape rotated
        arrow = [(-4, -15), (4, -15), (4, 3), (13, 3), (0, 19), (-13, 3), (-4, 3)]
        for x, label, orientation, ori in ((-230, KEYS_IF["vertical"], "vertical", 0),
                                           (230, KEYS_IF["horizontal"], "horizontal", -90)):
            stims.append(self.text(label, size_px=26, pos_px=(x, 140)))
            w, h = (LINE_WIDTH_PX, LINE_LENGTH_PX) if orientation == "vertical" else (LINE_LENGTH_PX, LINE_WIDTH_PX)
            stims.append(visual.Rect(self.win, width=u(w), height=u(h), pos=(u(x), u(50)), fillColor=BLACK,
                                     lineColor=None, colorSpace="rgb1"))
            stims.append(self.text(KEYS_PRESS, size_px=26, pos_px=(x - 40, -50)))
            stims.append(visual.Rect(self.win, width=u(64), height=u(64), pos=(u(x + 95), u(-50)), fillColor=KEY_GREY,
                                     lineColor=GREY, lineWidth=self.to_pix(2), colorSpace="rgb1"))
            stims.append(visual.ShapeStim(self.win, vertices=[(u(a), u(b)) for a, b in arrow], pos=(u(x + 95), u(-50)),
                                          ori=ori, fillColor=BLACK, lineColor=None, colorSpace="rgb1"))
        stims.append(self.text(KEYS_WHERE, size_px=26, pos_px=(0, -135)))
        stims.append(self.text(FINGERS, size_px=24, pos_px=(0, -215), width_px=1000, bold=True))
        return stims

    def instructions(self):
        """Instruction pages of the search task (original texts; examples with
        the target circled in blue; response keys), then a comprehension check."""
        examples = [add_features(t, self.rng) for t in make_practice(N_EXAMPLES, self.rng)]

        def example_page(i, trial):
            def draw():
                self.display.set_trial(trial)
                self.display.draw(indicator_at=trial["target_pos"])
            return [self.text(EXAMPLE_OF.format(i + 1, N_EXAMPLES), size_px=20, y=.03, color=GREY), Drawable(draw)]

        def make_pages():
            text = INSTRUCTIONS_2
            if RESPONSE_WINDOW_S:
                first, rest = text.split("\n\n", 1)
                text = f"{first}\n\n{RESPONSE_WINDOW_TEXT}\n\n{rest}"
            return ([self.page(INSTRUCTIONS_1, title=TITLE_INSTRUCTIONS, footer=None)]
                    + [example_page(i, t) for i, t in enumerate(examples)]
                    + [self.keys_page(), self.page(text + "\n\n" + QUIZ_INTRO, title=TITLE_INSTRUCTIONS, footer=None)])

        self.screenshot_pages(make_pages(), ["instructions_1", "example"] + [None] * (N_EXAMPLES - 1) + ["keys", "instructions_2"])
        self.instructions_with_check(make_pages, SEARCH_QUIZ, "search", last_footer=CONTINUE)

    def practice(self):
        """Practice of the search (as in the original: target-only displays);
        in the load group, then the instructions of the counting task, a
        comprehension check and one practice period. Reminders of the keys
        before each practice and before the experiment."""
        self.reminder(REMINDER_PRACTICE, REMEMBER + REMINDER_KEYS, START_PRACTICE, name="reminder_practice")
        for i, trial in enumerate(make_practice(N_PRACTICE, self.rng)):
            self.search_trial(add_features(trial, self.rng), "practice", 0, i + 1)
        if GROUP == "load":
            def make_pages():
                return [self.page(text, title=TITLE_INSTRUCTIONS, footer=None) for text in COUNT_INSTRUCTIONS]
            self.screenshot_pages(make_pages(), ["count_instructions_1", "count_instructions_2"])
            self.instructions_with_check(make_pages, COUNT_QUIZ, "count", last_footer=CONTINUE)
            self.reminder(REMINDER_PERIOD, REMEMBER + REMINDER_KEYS + "\n\n" + REMINDER_COUNT, START_PRACTICE,
                          name="reminder_count")
            period = {"length": PRACTICE_PERIOD_LENGTH, "shown_is_correct": self.rng.randint(0, 1),
                      "orientation": self.rng.choice(["horizontal", "vertical"])}
            trials = [add_features(t, self.rng) for t in make_practice(PRACTICE_PERIOD_LENGTH, self.rng)]
            self.run_period(trials, period, "practice", 0, 1, first_trial=N_PRACTICE + 1)
        self.reminder(REMINDER_EXPERIMENT,
                      PRACTICE_END + REMINDER_KEYS + ("\n\n" + REMINDER_COUNT if GROUP == "load" else "")
                      + STRUCTURE.format(N_BLOCKS), START_EXPERIMENT, name="reminder_experiment")

    def screenshot_pages(self, pages, names):
        """Code check: a screenshot of every instruction page."""
        if AUTO:
            for stims, name in zip(pages, names):
                if name:
                    for s in stims:
                        s.draw()
                    self.win.flip()
                    self.screenshot(name)

    def blocks(self):
        for block in range(1, N_BLOCKS + 1):
            trials = make_block(self.hpdl, self.rng)
            if GROUP == "load":  # consecutive trials of the block form the periods
                periods = make_periods(self.rng)
                if AUTO:
                    periods = periods[:AUTO_PERIODS_PER_BLOCK]
                start = 0
                for k, period in enumerate(periods):
                    chunk = [add_features(t, self.rng) for t in trials[start:start + period["length"]]]
                    self.run_period(chunk, period, "experimental", block, k + 1, first_trial=start + 1)
                    start += period["length"]
            else:
                if AUTO:
                    trials = trials[:AUTO_TRIALS_PER_BLOCK]
                for i, trial in enumerate(trials):
                    self.search_trial(add_features(trial, self.rng), "experimental", block, i + 1)
            if block == N_BLOCKS:
                self.wait_space(self.page(LAST_BLOCK), name="last_block")
            else:
                self.wait_space(self.page(BREAK.format(block, N_BLOCKS), title=BREAK_TITLE),
                                name="break" if block == 1 else None)

    def awareness_test(self):
        """AwarenessTest.m (Experiment 1), with the keyboard as in the original:
        Q1 on the 1-6 scale; Q2 the location (eight numbered circles); then the
        chosen location in blue, with the option to repeat the whole test. The
        number key highlights the option, and Enter confirms it. Every attempt
        is saved."""
        u = self.u
        circles = [ring(self.win, (u(x), u(y)), CIRCLE_DIAMETER_PX / 2, CIRCLE_PEN_PX, GREEN, u) for x, y in POSITIONS_PX]
        numbers = [self.text(str(i + 1), size_px=24, pos_px=(x, y)) for i, (x, y) in enumerate(POSITIONS_PX)]

        def draw_locations(blue_at):
            for i, (outer, inner) in enumerate(circles):
                outer.fillColor = BLUE if blue_at == i + 1 else GREEN
                outer.draw()
                inner.draw()
                numbers[i].draw()

        scale = [self.option_box(((i - 2.5) * 176, -80), (160, 110), i + 1, lab) for i, lab in enumerate(AWARENESS_SCALE)]
        q1 = self.text(AWARENESS_Q1, y=.1, align="left")
        q2 = self.text(AWARENESS_Q2, size_px=22, y=.04, align="left")
        q2_prompt = self.text(AWARENESS_Q2_PROMPT, size_px=22, y=.86)
        hint = self.text(SELECT_HINT, size_px=20, y=.93, color=GREY)
        confirm_title = self.text(AWARENESS_CONFIRM, size_px=24, y=.04)
        confirm = [self.option_box((x, 0), (230, 110), n, lab)
                   for x, n, lab in zip((-470, 470), (1, 2), AWARENESS_CONFIRM_OPTIONS)]

        attempt = 0
        while True:
            attempt += 1

            def draw_q1(sel):
                q1.draw()
                self.draw_options(scale, sel)
                hint.draw()
            r1 = self.select_with_keys(draw_q1, range(1, 7), auto_value=3, name="awareness_q1")

            self.wait_space(self.page(AWARENESS_INTRO), name="awareness_intro")

            def draw_q2(sel):
                q2.draw()
                draw_locations(sel)
                q2_prompt.draw()
                hint.draw()
            r2 = self.select_with_keys(draw_q2, range(1, 9), auto_value=self.hpdl, name="awareness_q2")

            def draw_confirm(sel):
                confirm_title.draw()
                draw_locations(r2)
                self.draw_options(confirm, sel)
                hint.draw()
            go_on = self.select_with_keys(draw_confirm, (1, 2), auto_value=1, name="awareness_confirm")
            self.save_row({"phase": "awareness", "aware_attempt": attempt, "aware_r1": r1, "aware_r2": r2,
                           "aware_repeat": int(go_on == 2)})
            if go_on == 1:
                break

        self.wait_space(self.page(GOODBYE, footer=EXIT), name="goodbye")

    def run(self):
        self.instructions()
        self.practice()
        self.blocks()
        self.awareness_test()
        self.file.close()
        self.win.close()


def session_dialog():
    """Participant number and demographics in one form before the task
    (std_instrucciones.m asked them on screen, one at a time; the last four
    digits of the DNI are not asked). Data keep the codes of the original:
    gender m/h/n, handedness d/i."""
    typed = {"participant": "", "age": ""}
    while True:
        values = {**typed, "gender": [""] + list(GENDERS), "handedness": [""] + list(HANDS)}
        dlg = gui.DlgFromDict(values, title=DIALOG_TITLE, labels=DIALOG_LABELS, sortKeys=False,
                              order=["participant", "age", "gender", "handedness"])
        if not dlg.OK:
            core.quit()
        participant = "".join(c for c in str(values["participant"]).strip() if c.isalnum() or c in "-_")
        age = str(values["age"]).strip()
        if participant and age.isdigit() and 16 <= int(age) <= 100 and values["gender"] in GENDERS and values["handedness"] in HANDS:
            return participant, {"age": int(age), "gender": GENDERS[values["gender"]], "handedness": HANDS[values["handedness"]]}
        typed = {"participant": participant, "age": age}  # incomplete or invalid: ask again
