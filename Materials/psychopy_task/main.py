#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Additional singleton task with a concurrent counting task (registered report
"Counting on Suppression"), translated to PsychoPy from the program of
Vicente-Conesa et al. (2023; https://osf.io/c23pk). Run it with run_task.bat,
from PsychoPy (Coder: Run) or with the PsychoPy Python. Settings are in
task/init.py; see README.md.
"""

import os
import sys

from psychopy import core

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # task/ next to this file, from any working folder
from task.experiment import AUTO, Experiment, session_dialog

if __name__ == "__main__":
    if AUTO:  # code check (AST_AUTO=1): no form, automatic responses
        participant, demographics = "auto", {"age": 20, "gender": "n", "handedness": "d"}
    else:
        participant, demographics = session_dialog()
    Experiment(participant, demographics).run()
    core.quit()
