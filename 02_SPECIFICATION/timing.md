# F07 · Đặc tả thời gian (Timing)

---

## 1. Bản chất thời gian của khối này

F07 là mạch **Tuần tự**.

Khối có **7 flip-flop**, hoạt động đồng bộ theo cạnh clock.

| Khái niệm | Áp dụng? |
|---|:-:|
| Chu kỳ clock | ✅ |
| Setup / hold | ✅ |
| Đường reg→reg, in→reg, reg→out | ✅ |
| CTS (cây clock) | ✅ ở bước physical design |
| WNS / TNS | ✅ |

## 2. Phương pháp ràng buộc đã dùng

Chế độ: **clock thật của thiết kế**.

File SDC: `04_IMPLEMENTATION/constraints/design.sdc`

```tcl
# Mach TUAN TU: dinh nghia clock that tu cong clock cua thiet ke.
# Chu ky 10 ns va IO delay 1 ns la GIA DINH phan tich khoi diem,
# KHONG phai yeu cau he thong. Phai neu kem moi con so bao cao.
create_clock -name clk -period 10.0 [get_ports clk]
set_input_delay  1.0 -clock clk [all_inputs]
set_output_delay 1.0 -clock clk [all_outputs]
```

## 3. Bốn giả định phải nêu kèm mọi con số

| # | Giả định | Giá trị dùng trong gói này |
|---|---|---|
| G-1 | Chu kỳ clock | `10,0 ns` — **giả định khởi điểm**, chưa phải yêu cầu hệ thống |
| G-2 | Input/output delay | 1,0 ns — giả định khởi điểm cho biên IO |
| G-3 | Thư viện + PVT | `sky130_fd_sc_hd__tt_025C_1v80.lib` (typical · 25 °C · 1,80 V) |
| G-4 | Ký sinh dây (RC) | **Chưa có** — số liệu mới ở mức sau tổng hợp, chưa qua P&R |

> ❗ Không được diễn giải "period 10 ns" thành "F07 chạy được ở 100 MHz".
> Tần số tối đa thật phải lấy từ STA sau routing, ở nhiều góc PVT.

## 4. Số liệu thời gian đo được

| Đại lượng | Giá trị |
|---|---:|
| Startpoint | `done` |
| Endpoint | `_63_` |
| **Data arrival time** | **1,42 ns** |
| Slack | 8,46 ns |
| WNS | `wns max 0.00` |
| TNS | `tns max 0.00` |
| Số cell trên đường tới hạn | 4 |

Công cụ: **OpenSTA 3.1.0** · Bằng chứng: `06_GDSII/sta/timing_report_max.txt`

## 5. Nghĩa vụ của tầng ngoài

```
t_clk  ≥  t_ckq  +  t_logic_max  +  t_setup  +  t_skew   (do chinh STA bao cao)
```

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Truy vết: REQ-F07-020, AC-12…AC-14.*
