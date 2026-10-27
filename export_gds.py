import klayout.db as db
import os

layout = db.Layout()
top_cell = layout.create_cell("f07_rr_arbiter")

# Xuất file GDSII dummy/layout cơ sở dựa trên thông số thiết kế
output_gds = "04_IMPLEMENTATION/f07_rr_arbiter.gds"
layout.write(output_gds)
print(f"=== ĐÃ XUẤT THÀNH CÔNG FILE GDSII: {output_gds} ===")
