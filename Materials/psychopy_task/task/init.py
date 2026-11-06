"""
Settings of the task: group, monitor, timing, design, keys and the auto mode
used for code checks (init.js in the jsPsych tasks).
"""

import os

# ---- Group ------------------------------------------------------------------
GROUP = "load"  # "load": load group of the RR; "control": the task of VC2023

# ---- Monitor ----------------------------------------------------------------
# Monitor of the lab where the task will be run (to fill in for each lab)
MONITOR_NAME = "lab_monitor"
MONITOR_WIDTH_CM = 53.0          # visible width of the screen
MONITOR_DISTANCE_CM = 60.0       # viewing distance
MONITOR_SIZE_PX = (1920, 1080)   # resolution
FULLSCREEN = True

# Geometry of the original lab (VC2023 cubicles), needed to convert the original
# pixel sizes to degrees (not reported in the paper)
ORIGINAL_WIDTH_CM = None
ORIGINAL_DISTANCE_CM = None
ORIGINAL_SIZE_PX = None
SIZE_UNITS = "pix"  # "deg" once the original geometry is known

# ---- Timing (s) -------------------------------------------------------------
# Fixation: 500 ms, as in the paper and in the RR text. The original code had
# 1 s (WaitSecs(1) after a blocking Flip)
ITI_S = 0.5               # blank screen before the fixation
FIXATION_S = 0.5
FEEDBACK_S = 3.0          # feedback after an error or a time-out
RESPONSE_WINDOW_S = 3.0 if GROUP == "load" else None  # None = until response (VC2023)

# ---- Design (makeBlock.m, CreaPractica.m, sdt_main_cabinas1_exp1.m) ----------
N_BLOCKS = 6
N_PER_CONDITION = {"ND": 40, "HPDL": 52, "LPDL": 28}  # 120 trials per block
CONDITION_CODES = {"ND": 100, "HPDL": 200, "LPDL": 300, "practice": 0}  # codes of the original data
N_EXAMPLES = 3   # example displays in the instructions
N_PRACTICE = 3   # practice trials (target only)

# ---- Counting task (load group) ---------------------------------------------
# RR, Procedure and Design: 12 periods per block (four
# of 8, 10 and 12 trials) in random order; the orientation to count is drawn at
# random for each period; the number shown at the end is correct in 6 periods
# per block (2 of each length) and incorrect in the other 6. Incorrect numbers
# are drawn from the distribution of the true count, Binomial(period length,
# .5), redrawn if they equal the true count
PERIOD_LENGTHS = [8] * 4 + [10] * 4 + [12] * 4
VERIFY_KEYS = {"s": 1, "n": 0}  # S = yes (the number matches the count), N = no
PRACTICE_PERIOD_LENGTH = 8      # one practice period (target only), with feedback on the verification
PRACTICE_FEEDBACK_S = 2.5

# ---- Responses --------------------------------------------------------------
# Left arrow = horizontal line, up arrow = vertical line. Only these two keys
# are accepted (the original scored any other allowed key as correct).
KEY_FOR = {"horizontal": "left", "vertical": "up"}
QUIT_KEY = "escape"

# ---- Auto mode (code checks: AST_AUTO=1, optional AST_SEED and AST_GROUP) ----
AUTO = os.environ.get("AST_AUTO") == "1"
AUTO_TRIALS_PER_BLOCK = 16  # control group; load group: the first AUTO_PERIODS_PER_BLOCK periods
AUTO_PERIODS_PER_BLOCK = 2
if AUTO:  # short run in a window with automatic responses
    GROUP = os.environ.get("AST_GROUP", GROUP)
    RESPONSE_WINDOW_S = 3.0 if GROUP == "load" else None
    FULLSCREEN = False
    MONITOR_SIZE_PX = (1280, 800)
    N_BLOCKS = 2
    N_PRACTICE = 2
    N_EXAMPLES = 1
    FEEDBACK_S = PRACTICE_FEEDBACK_S = .1

assert GROUP in ("load", "control")
assert sum(PERIOD_LENGTHS) == sum(N_PER_CONDITION.values())

# ---- Paths ------------------------------------------------------------------
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # folder of main.py
DATA_DIR = os.path.join(HERE, "data")
