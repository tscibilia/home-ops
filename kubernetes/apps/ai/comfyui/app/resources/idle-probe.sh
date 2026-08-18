#!/bin/bash
# ai-dock runs every executable in preflight.d before starting ComfyUI, so the
# probe must background itself or startup blocks here forever.
python3 /opt/ai-dock/bin/preflight.d/idle-probe.py &
