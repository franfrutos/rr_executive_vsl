"""
Stimuli and trial lists (helper.js in the jsPsych tasks): the geometry of
the original program, the trial and period generators, the window and the
search display.
"""

from psychopy import logging, monitors, visual
from psychopy.tools import monitorunittools

from .init import *

# =============================================================================
# Stimuli of the original program (pixels; Psychtoolbox y grows downwards,
# PsychoPy y grows upwards, so the y coordinates below are flipped)
# =============================================================================

# Locations 1-8, clockwise from 9 o'clock (numbering of the original and of
# the awareness test): left, upper left, top, upper right, right, lower right,
# bottom, lower left
POSITIONS_PX = [(-220, 0), (-150, 150), (0, 220), (150, 150),
                (220, 0), (150, -150), (0, -220), (-150, -150)]
CIRCLE_DIAMETER_PX = 120   # FrameOval in a 120-px rect, pen 7 px (drawn inwards)
CIRCLE_PEN_PX = 7
DIAMOND_SIZE_PX = 150      # FramePoly, 150 x 150 px, pen 10 px (centred on the edges)
DIAMOND_PEN_PX = 10
LINE_LENGTH_PX = 100       # DrawLines, black, 7 px wide
LINE_WIDTH_PX = 7
INDICATOR_DIAMETER_PX = 200  # blue circle around the target in the examples, pen 8 px
INDICATOR_PEN_PX = 8

WHITE = (1, 1, 1)
BLACK = (0, 0, 0)
RED = (1, 0, 0)
GREEN = (0, 1, 0)
BLUE = (0, 0, 1)
FONT = "Times New Roman"

# Designs of the original (ChooseDesign), drawn at random on each trial:
# (target shape, colour of the target and non-singleton items, singleton colour)
DESIGNS = {1: ("diamond", GREEN, RED),
           2: ("diamond", RED, GREEN),
           3: ("circle", GREEN, RED),
           4: ("circle", RED, GREEN)}
COLOUR_NAMES = {RED: "red", GREEN: "green"}

# Colours of the interface (option boxes, hints, key caps)
LIGHT_BLUE = (.85, .9, 1)
GREY = (.35, .35, .35)
KEY_GREY = (.92, .92, .92)

# =============================================================================
# Trial lists (makeBlock.m, CreaNoDistractor.m, CreaHighProb.m, CreaLowProb.m,
# CreaPractica.m)
# =============================================================================


def make_block(hpdl, rng):
    """One block of 120 trials in random order. Locations are 1-8.

    As in the original: HPDL trials put the target at a random location other
    than the HPDL; LPDL trials draw the distractor location at random (with
    replacement) from the seven non-HPDL locations and the target from the
    seven locations other than the distractor's (HPDL included); ND trials draw
    the target from all eight locations."""
    trials = []
    for _ in range(N_PER_CONDITION["ND"]):
        trials.append({"condition": "ND", "distractor_pos": 0, "target_pos": rng.randint(1, 8)})
    for _ in range(N_PER_CONDITION["HPDL"]):
        target = rng.choice([p for p in range(1, 9) if p != hpdl])
        trials.append({"condition": "HPDL", "distractor_pos": hpdl, "target_pos": target})
    for _ in range(N_PER_CONDITION["LPDL"]):
        distractor = rng.choice([p for p in range(1, 9) if p != hpdl])
        target = rng.choice([p for p in range(1, 9) if p != distractor])
        trials.append({"condition": "LPDL", "distractor_pos": distractor, "target_pos": target})
    rng.shuffle(trials)
    return trials


def make_practice(n, rng):
    """Target-only displays (CreaPractica.m): the target at a random location."""
    return [{"condition": "practice", "distractor_pos": 0, "target_pos": rng.randint(1, 8)} for _ in range(n)]


def add_features(trial, rng):
    """Design (shapes and colours) and line orientations, drawn at random for
    each trial and each item, as in the original."""
    design = rng.randint(1, 4)
    target_shape, colour, singleton_colour = DESIGNS[design]
    orientations = [rng.choice(["horizontal", "vertical"]) for _ in range(8)]
    trial.update({
        "design": design,
        "target_shape": target_shape,
        "items_colour": COLOUR_NAMES[colour],
        "singleton_colour": COLOUR_NAMES[singleton_colour] if trial["distractor_pos"] else "",
        "target_orientation": orientations[trial["target_pos"] - 1],
        "orientations": orientations,
        "colours": (colour, singleton_colour),
    })
    return trial


def make_periods(rng):
    """Periods of one block (load group), in random order: length, whether the
    number shown at the end is correct (half of the periods of each length),
    and the orientation to count (drawn at random for each period)."""
    periods = []
    for n in sorted(set(PERIOD_LENGTHS)):
        k = PERIOD_LENGTHS.count(n)
        shown_correct = [1] * (k // 2) + [0] * (k - k // 2)
        rng.shuffle(shown_correct)
        periods += [{"length": n, "shown_is_correct": c} for c in shown_correct]
    rng.shuffle(periods)
    for p in periods:
        p["orientation"] = rng.choice(["horizontal", "vertical"])
    return periods


def wrong_count(true_count, n, rng):
    """An incorrect number for the verification of a period of n trials:
    Binomial(n, .5), redrawn if it equals the true count."""
    while True:
        k = sum(rng.random() < .5 for _ in range(n))
        if k != true_count:
            return k


# =============================================================================
# Window, units and stimuli
# =============================================================================

def setup_window():
    mon = monitors.Monitor(MONITOR_NAME, width=MONITOR_WIDTH_CM, distance=MONITOR_DISTANCE_CM)
    mon.setSizePix(MONITOR_SIZE_PX)
    win = visual.Window(size=MONITOR_SIZE_PX, fullscr=FULLSCREEN, monitor=mon, units=SIZE_UNITS,
                        color=WHITE, colorSpace="rgb1", allowGUI=False)
    if SIZE_UNITS == "deg":
        if None in (ORIGINAL_WIDTH_CM, ORIGINAL_DISTANCE_CM, ORIGINAL_SIZE_PX):
            raise ValueError("SIZE_UNITS = 'deg' needs the geometry of the original lab (ORIGINAL_*).")
        orig = monitors.Monitor("vc2023_original", width=ORIGINAL_WIDTH_CM, distance=ORIGINAL_DISTANCE_CM)
        orig.setSizePix(ORIGINAL_SIZE_PX)
        to_units = lambda px: monitorunittools.pix2deg(px, orig)
        to_pix = lambda px: monitorunittools.deg2pix(to_units(px), mon)  # line widths are always in pixels
        screen = (monitorunittools.pix2deg(win.size[0], mon), monitorunittools.pix2deg(win.size[1], mon))
    elif SIZE_UNITS == "pix":
        to_units = to_pix = lambda px: px
        screen = tuple(win.size)
    else:
        raise ValueError("SIZE_UNITS must be 'pix' or 'deg'.")
    win.mouseVisible = False
    rate = win.getActualFrameRate(nIdentical=10, nMaxFrames=120, nWarmUpFrames=10, threshold=1)
    if not rate:
        logging.warning("Frame rate could not be measured; 60 Hz assumed.")
    return win, to_units, to_pix, float(screen[0]), float(screen[1]), float(rate) if rate else 60.0


def ring(win, pos, outer_radius, width, colour, u):
    """An outline circle as a filled disc with a background disc inside, so its
    width is exact in any units (Psychtoolbox FrameOval draws the pen inwards)."""
    return (visual.Circle(win, radius=u(outer_radius), edges=128, pos=pos, fillColor=colour, lineColor=None, colorSpace="rgb1"),
            visual.Circle(win, radius=u(outer_radius - width), edges=128, pos=pos, fillColor=WHITE, lineColor=None, colorSpace="rgb1"))


class Display:
    """The eight items of a search display (outlines drawn as filled shapes, see
    ring(); the diamond pen is centred on the edges of the 150-px polygon). In
    the instruction examples, a blue outline circles the target; it is drawn
    right after the target, as in the original, and can touch a neighbour."""

    def __init__(self, win, u, to_pix):
        h = DIAMOND_SIZE_PX / 2
        d = DIAMOND_PEN_PX / 2 * 2 ** .5  # half pen measured along the diagonal
        diamond = lambda half: [(0, -u(half)), (-u(half), 0), (0, u(half)), (u(half), 0)]
        self.circle, self.diamond, self.hline, self.vline, self.indicator = [], [], [], [], []
        for x, y in POSITIONS_PX:
            pos = (u(x), u(y))
            self.circle.append(ring(win, pos, CIRCLE_DIAMETER_PX / 2, CIRCLE_PEN_PX, WHITE, u))
            self.diamond.append((
                visual.ShapeStim(win, vertices=diamond(h + d), pos=pos, fillColor=WHITE, lineColor=None, colorSpace="rgb1"),
                visual.ShapeStim(win, vertices=diamond(h - d), pos=pos, fillColor=WHITE, lineColor=None, colorSpace="rgb1")))
            self.hline.append(visual.Rect(win, width=u(LINE_LENGTH_PX), height=u(LINE_WIDTH_PX), pos=pos,
                                          fillColor=BLACK, lineColor=None, colorSpace="rgb1"))
            self.vline.append(visual.Rect(win, width=u(LINE_WIDTH_PX), height=u(LINE_LENGTH_PX), pos=pos,
                                          fillColor=BLACK, lineColor=None, colorSpace="rgb1"))
            self.indicator.append(visual.Circle(win, radius=u(INDICATOR_DIAMETER_PX / 2 - INDICATOR_PEN_PX / 2), edges=128,
                                                pos=pos, fillColor=None, lineColor=BLUE, lineWidth=to_pix(INDICATOR_PEN_PX),
                                                colorSpace="rgb1"))
        self.items = []

    def set_trial(self, trial):
        colour, singleton_colour = trial["colours"]
        other_shape = "circle" if trial["target_shape"] == "diamond" else "diamond"
        self.items = []
        for i in range(8):
            shape = trial["target_shape"] if i + 1 == trial["target_pos"] else other_shape
            col = singleton_colour if i + 1 == trial["distractor_pos"] else colour
            self.items.append((i, shape, col, trial["orientations"][i]))

    def draw(self, indicator_at=None):
        for i, shape, col, orientation in self.items:
            outer, inner = self.circle[i] if shape == "circle" else self.diamond[i]
            outer.fillColor = col
            outer.draw()
            inner.draw()
            (self.hline[i] if orientation == "horizontal" else self.vline[i]).draw()
            if indicator_at == i + 1:
                self.indicator[i].draw()




class Drawable:
    """Wraps a drawing function so it can be passed with other stimuli."""

    def __init__(self, fn):
        self.fn = fn

    def draw(self):
        self.fn()
