import klayout.db as db
import glob
import os

layout = db.Layout()
pdk_root = os.environ.get("PDK_ROOT", "/home/duy/.volare")

# Nap file GDS layout hien tai
layout.read("04_IMPLEMENTATION/f07_rr_arbiter.gds")

# Nap cac file GDS standard cells tu PDK Sky130
gds_libs = glob.glob(f"{pdk_root}/sky130A/libs.ref/sky130_fd_sc_hd/gds/*.gds")
for gds in gds_libs:
    try:
        layout.read(gds)
    except Exception:
        pass

# Ghi lai file GDSII day du
layout.write("04_IMPLEMENTATION/f07_rr_arbiter_full.gds")
print("=== DA MERGE GDSII THANH CONG ===")
