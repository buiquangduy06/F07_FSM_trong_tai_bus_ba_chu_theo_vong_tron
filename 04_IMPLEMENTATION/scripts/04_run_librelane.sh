#!/usr/bin/env bash
# =====================================================================
#  F07 · Buoc 4 — Physical design RTL→GDSII (LibreLane / OpenLane 2)
#  MO RONG TU NGUYEN theo Charter muc 3 — khong phai dieu kien dat.
# =====================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
CFG=04_IMPLEMENTATION/scripts/config_librelane.json

echo "===== KIEM TRA MOI TRUONG ====="
MISS=0
for t in yosys openroad klayout magic netgen python3; do
  if command -v "$t" >/dev/null 2>&1; then printf "  %-10s OK\n" "$t"
  else printf "  %-10s THIEU\n" "$t"; MISS=1; fi
done
if python3 -c "import librelane" 2>/dev/null; then RUNNER="python3 -m librelane"; echo "  librelane  OK"
elif python3 -c "import openlane" 2>/dev/null; then RUNNER="python3 -m openlane"; echo "  openlane2  OK"
else echo "  librelane  THIEU"; MISS=1; fi
echo "  PDK_ROOT = ${PDK_ROOT:-<chua dat>}"
[ -d "${PDK_ROOT:-/nonexistent}/sky130A" ] || { echo "  [CANH BAO] chua thay PDK sky130A"; MISS=1; }

if [ "$MISS" -ne 0 ]; then
cat <<'EOT'

=====================================================================
 CHUA DU MOI TRUONG — DUNG LAI, KHONG TAO KET QUA GIA
=====================================================================
Cai dat goi y (WSL Ubuntu):
  pip install librelane volare
  volare enable --pdk sky130 <commit>
  export PDK_ROOT=$HOME/.volare
Hoac dung OSS CAD Suite:  source <oss-cad-suite>/environment

Ghi nho (Charter muc 3): day la MO RONG TU NGUYEN, thieu buoc nay KHONG lam bai truot.
EOT
exit 2
fi

$RUNNER "$CFG" 2>&1 | tee 06_GDSII/librelane_run.log
RUNDIR=$(ls -dt runs/*/ 2>/dev/null | head -1 || true)
[ -z "$RUNDIR" ] && { echo "[LOI] khong thay thu muc runs/"; exit 1; }
cp_if(){ [ -e "$1" ] && cp -r "$1" "$2" && echo "  -> $2"; }
cp_if "$RUNDIR/final/gds"          06_GDSII/gds/
cp_if "$RUNDIR/reports/signoff"    06_GDSII/sta/
cp_if "$RUNDIR/reports/drc"        06_GDSII/drc/
cp_if "$RUNDIR/reports/lvs"        06_GDSII/lvs/
cp_if "$RUNDIR/reports/floorplan"  06_GDSII/floorplan/
cp_if "$RUNDIR/reports/placement"  06_GDSII/placement/
cp_if "$RUNDIR/reports/routing"    06_GDSII/routing/
cp_if "$RUNDIR/reports/power"      06_GDSII/power/

cat <<'EOT'

 "Co file GDS" CHI chung minh: mot co so du lieu GDS da duoc sinh ra.
 No KHONG tu no chung minh chuc nang dung, timing dat, DRC/LVS sach hay che tao duoc.
 Xem 07_TRACEABILITY/limitations.md.
EOT
