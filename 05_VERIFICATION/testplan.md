# F07 · Kế hoạch kiểm chứng (Test Plan)

---

## 1. Chiến lược nhiều lớp độc lập

| Lớp | Nội dung | File | Công cụ | Trạng thái |
|---|---|---|---|---|
| L0 | Mô hình chuẩn viết bằng Python, độc lập với RTL | `golden_model/reference_model.py` | CPython 3 | ✅ PASS |
| L1 | Mô hình chuẩn viết bằng SystemVerilog | `golden_model/—` | Icarus Verilog 12.0 (stable) | ⬜ gói nguồn không có |
| L2 | Mô phỏng RTL với testbench tự kiểm | `testbench/f07_tb.sv` | Icarus Verilog 12.0 (stable) | ✅ PASS |
| L3 | Kiểm cấu trúc — số flip-flop phù hợp phân loại | `../06_GDSII/synthesis/synth_stat.txt` | Yosys 0.33 (git sha1 2584903a060) | ✅ |
| L4 | Mô phỏng gate-level trên netlist | — | — | ⬜ chưa chạy |
| L5 | Mô phỏng post-layout có back-annotate SDF | — | — | ⬜ chưa chạy |

> Lý do dùng nhiều mô hình chuẩn độc lập: nếu mô hình chuẩn và RTL do cùng một người viết
> theo cùng một cách nghĩ, chúng có thể **cùng sai**. Một mô hình viết bằng ngôn ngữ khác
> (Python) làm giảm rủi ro đó — nguyên tắc *diverse redundancy*.

## 2. Ca kiểm thử bắt buộc theo Charter mục 8

- Một khối xin · hai khối xin · ba khối xin liên tục (kiểm luân phiên) · không khối nào xin
- Bổ sung ít nhất hai ca tự xây dựng, trong đó có ca biên.

Danh sách thực thi và kết quả: `test_matrix.csv`.

## 3. Tiêu chí PASS/FAIL

| Lớp | Tiêu chí PASS |
|---|---|
| L0 | Mô hình Python chạy hết, không assertion nào sai |
| L2 | Testbench chạy hết, **không** assertion nào vi phạm, không `$fatal` |
| L3 | Số cell tuần tự **> 0** — đúng phân loại **Tuần tự** |
| L4–L5 | Như L2 nhưng chạy trên netlist; thêm: không có X-propagation |

Bất kỳ một FAIL nào ⟹ tầng đó FAIL. Không có ngưỡng "chấp nhận được".

## 4. Những gì kế hoạch này **không** chứng minh

| Không chứng minh | Vì sao | Cần gì |
|---|---|---|
| Kiến trúc bên trong đúng như đặc tả | Kiểm chứng chức năng mù về cấu trúc | Đọc RTL + netlist |
| Độ trễ đạt yêu cầu | Mô phỏng hành vi không có độ trễ cổng | Báo cáo STA (`../06_GDSII/sta/`) |
| Mạch đúng sau P&R | Chưa chạy P&R | L5 + DRC/LVS |
| Không có glitch gây hại | Mô phỏng zero-delay không sinh glitch | L5 với SDF |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Truy vết: REQ-F07-010…013.*
