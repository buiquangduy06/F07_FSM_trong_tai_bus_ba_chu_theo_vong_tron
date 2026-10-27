import klayout.db as db
import glob
import os

layout = db.Layout()

pdk_root = os.environ.get("PDK_ROOT", "/home/duy/.volare")
tech_lef = glob.glob(f"{pdk_root}/sky130A/libs.ref/sky130_fd_sc_hd/techlef/*.tlef")
lef_files = glob.glob(f"{pdk_root}/sky130A/libs.ref/sky130_fd_sc_hd/lef/*.lef")

all_lefs = tech_lef + lef_files

options = db.LoadLayoutOptions()
options.lefdef_config.lef_files = all_lefs

def_file = "04_IMPLEMENTATION/f07_rr_arbiter_routed.def"
gds_file = "04_IMPLEMENTATION/f07_rr_arbiter.gds"

try:
    layout.read(def_file, options)
    layout.write(gds_file)
    print(f"=== XUAT GDSII CHINH THUC THANH CONG: {gds_file} ===")
except Exception as e:
    print(f"Loi xuat GDSII: {e}")
