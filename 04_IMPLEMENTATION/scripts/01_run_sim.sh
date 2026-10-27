#!/usr/bin/env bash
# =====================================================================
#  F07 · Buoc 1 — Mo phong chuc nang (Icarus Verilog)
#  Chay tu THU MUC GOC cua du an:
#      bash 04_IMPLEMENTATION/scripts/01_run_sim.sh
# =====================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
OUT=05_VERIFICATION
mkdir -p "$OUT/waveforms"

command -v iverilog >/dev/null || { echo "[LOI] thieu 'iverilog' (sudo apt install iverilog)"; exit 2; }

iverilog -V | head -1 | tee "$OUT/tool_versions.txt"

iverilog -g2012 -o "$OUT/sim.vvp" \
    04_IMPLEMENTATION/rtl/f07_bad_fixed_priority.sv \
    04_IMPLEMENTATION/rtl/f07_rr_arbiter.sv \
    04_IMPLEMENTATION/rtl/f07_rr_arbiter_wrapper.sv \
    05_VERIFICATION/testbench/f07_tb.sv \
    05_VERIFICATION/testbench/properties.sv

cd "$OUT" && vvp sim.vvp | tee simulation.log; cd "$ROOT"
mv -f "$OUT"/*.vcd "$OUT/waveforms/" 2>/dev/null || true

echo
echo "Bang chung: $OUT/simulation.log"
echo "Waveform  : $OUT/waveforms/"
