# F07 · Tầng 04 — Hiện thực (Implementation)

---

## 1. Nội dung thư mục

```
04_IMPLEMENTATION/
├── rtl/               f07_bad_fixed_priority.sv, f07_rr_arbiter.sv, f07_rr_arbiter_wrapper.sv
├── constraints/       design.sdc
├── scripts/           01_run_sim.sh · 02_run_synth.sh · 03_run_sta.tcl
│                      04_run_librelane.sh · config.json · config_librelane.json
└── README.md
```

**Top module:** `f07_rr_arbiter`
**Bằng chứng chọn top:** testbench khoi tao lam 'dut' trong f07_tb.sv
**Các module khác trong src/:** `f07_bad_fixed_priority`, `f07_rr_arbiter_wrapper`

## 2. Thứ tự chạy

```bash
python3 05_VERIFICATION/golden_model/reference_model.py     # ✅ PASS
bash 04_IMPLEMENTATION/scripts/01_run_sim.sh                # ✅ PASS
bash 04_IMPLEMENTATION/scripts/02_run_synth.sh              # ✅ PASS
sta -no_splash -exit 04_IMPLEMENTATION/scripts/03_run_sta.tcl   # ✅ PASS
bash 04_IMPLEMENTATION/scripts/04_run_librelane.sh          # ⬜ cần PDK sky130A
```

Mỗi script tự kiểm tra công cụ và **dừng có thông báo** nếu thiếu, thay vì tạo kết quả giả.

## 3. Sửa nguồn tối thiểu đã áp dụng

Nguồn gốc lấy từ `F07_FINAL_MENTOR_PACKAGE_v1_0`. Để biên dịch được bằng Icarus Verilog 12.0, các sửa đổi
sau đã được áp dụng **trên bản sao** trong thư mục này. Nguyên tắc: chỉ sửa lỗi làm trình
biên dịch từ chối, **không** đổi hành vi thiết kế.
_Không phải sửa gì — nguồn biên dịch được nguyên trạng._

## 4. Môi trường đã dùng để sinh bằng chứng

| Công cụ | Phiên bản |
|---|---|
| Mô phỏng | Icarus Verilog 12.0 (stable) |
| Tổng hợp | Yosys 0.33 (git sha1 2584903a060) |
| STA + công suất | OpenSTA 3.1.0 |
| Liberty | `sky130_fd_sc_hd__tt_025C_1v80.lib` (typical · 25 °C · 1,80 V) |
| LibreLane + sky130A | ⬜ chưa chạy |

## 5. Cài đặt công cụ trên WSL Ubuntu

```bash
sudo apt update && sudo apt install -y iverilog yosys gtkwave
# OpenSTA: can cmake swig tcl-dev flex bison libeigen3-dev libgtest-dev + CUDD 3.0.0
pip install librelane volare && volare enable --pdk sky130 <commit>
export PDK_ROOT=$HOME/.volare
```

Gọn hơn: dùng **OSS CAD Suite** (`source <oss-cad-suite>/environment`) — có sẵn iverilog,
yosys, OpenSTA, OpenROAD, KLayout, Magic, Netgen.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
