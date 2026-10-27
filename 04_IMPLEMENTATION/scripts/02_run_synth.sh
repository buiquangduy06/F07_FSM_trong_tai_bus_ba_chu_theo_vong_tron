#!/usr/bin/env bash
# =====================================================================
#  F07 · Buoc 2 — Tong hop logic (Yosys) len sky130_fd_sc_hd
#  Chay:  bash 04_IMPLEMENTATION/scripts/02_run_synth.sh [duong_dan_liberty]
# =====================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
OUT=06_GDSII/synthesis; mkdir -p "$OUT"

command -v yosys >/dev/null || { echo "[LOI] thieu 'yosys' (sudo apt install yosys)"; exit 2; }

LIB="${1:-${LIBERTY:-}}"
[ -z "$LIB" ] && [ -n "${PDK_ROOT:-}" ] && \
  LIB="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
[ -z "$LIB" ] || [ ! -f "$LIB" ] && {
  echo "[LOI] khong tim thay Liberty sky130_fd_sc_hd__tt_025C_1v80.lib"
  echo "      export PDK_ROOT=<thu muc pdk>  hoac  bash $0 /duong/dan/file.lib"; exit 3; }

yosys -V | head -1 | tee "$OUT/tool_versions.txt"
echo "Liberty: $LIB" | tee -a "$OUT/tool_versions.txt"

cat > "$OUT/synth.ys" <<EOF
read_verilog -sv 04_IMPLEMENTATION/rtl/f07_bad_fixed_priority.sv
read_verilog -sv 04_IMPLEMENTATION/rtl/f07_rr_arbiter.sv
read_verilog -sv 04_IMPLEMENTATION/rtl/f07_rr_arbiter_wrapper.sv
hierarchy -check -top f07_rr_arbiter
proc
opt
fsm
opt
memory
opt
techmap
opt
dfflibmap -liberty $LIB
abc -liberty $LIB
setundef -zero
splitnets
opt_clean -purge
tee -o $OUT/synth_stat.txt stat -liberty $LIB
write_verilog -noattr $OUT/netlist.v
EOF

yosys -Q -s "$OUT/synth.ys" > "$OUT/yosys.log" 2>&1
cat "$OUT/synth_stat.txt"

# --- kiem tra phu hop phan loai mach (Tuần tự) ---
if grep -qE "sky130_fd_sc_hd__(df|dl|sd)" "$OUT/synth_stat.txt"; then
  echo "[INFO] Netlist co cell tuan tu -> mach TUAN TU."
  echo "[OK] Dung voi phan loai Tuan tu cua Charter."
else
  echo "[INFO] Netlist khong co cell tuan tu -> mach TO HOP."
  echo "[CANH BAO] De nay duoc Charter phan loai TUAN TU nhung khong thay flip-flop!"; exit 1
fi
