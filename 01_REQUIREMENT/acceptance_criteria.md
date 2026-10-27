# F07 · Tiêu chí đạt (Acceptance Criteria)

> 🔧 **ĐỀ NÀY ĐÃ ĐƯỢC VÁ LỖI**
>
> Mô phỏng ban đầu không đạt. Lỗi đã được chẩn đoán, vá và **xác minh lại bằng
> công cụ thật**. Mọi số liệu trong hồ sơ là số liệu **sau khi vá**.
>
> * Mã nguồn gốc: [`08_ORIGINAL_SOURCE/`](08_ORIGINAL_SOURCE/) — giữ nguyên, quay lui được
> * Nhật ký vá: [`08_ORIGINAL_SOURCE/PATCHLOG.md`](08_ORIGINAL_SOURCE/PATCHLOG.md)
> * Chẩn đoán đầy đủ: [`05_VERIFICATION/known_issues.md`](05_VERIFICATION/known_issues.md)



Nguồn: **Charter F07 mục 6**, cộng các tiêu chí suy ra từ mục 8 và mục 9.

Trạng thái: ✅ ĐẠT (có bằng chứng do tool sinh) · ⚠️ CÓ VẤN ĐỀ · ⬜ CHƯA CHẠY · 🟡 MỞ.

---

## 1. Bốn tiêu chí gốc của Charter (mục 6)

- Bảng giao diện đầy đủ, nhất quán với đặc tả; tín hiệu nào cũng có chiều và độ rộng.
- Mỗi khẳng định đi kèm bằng chứng và điều kiện tạo ra bằng chứng đó.
- Trả lời câu phân tích riêng bằng dữ liệu của chính mình.
- Nêu giới hạn trung thực; không dùng phát biểu vượt mức như “đã sign-off”.

| # | Tiêu chí | Cách kiểm | Bằng chứng | Trạng thái |
|---|---|---|---|---|
| AC-1 | Bảng giao diện đầy đủ, nhất quán với đặc tả | Đối chiếu bảng với cổng module trong RTL | `02_SPECIFICATION/interface.md` §2 | ✅ |
| AC-2 | Mỗi khẳng định kèm bằng chứng và điều kiện tạo ra | Rà từng dòng RTM | `07_TRACEABILITY/RTM.csv` | ✅ (phần đã chạy) |
| AC-3 | Trả lời câu phân tích riêng bằng dữ liệu của chính mình | Charter mục 9 | `06_GDSII/sta/` · `06_GDSII/physical_report.md` | ✅ |
| AC-4 | Nêu giới hạn trung thực, không phát biểu vượt mức | Quét kết luận | `07_TRACEABILITY/limitations.md` | ✅ |

## 2. Tiêu chí chức năng

| # | Tiêu chí | Bằng chứng | Trạng thái |
|---|---|---|---|
| AC-5 | Mô hình chuẩn Python chạy PASS | `05_VERIFICATION/python_reference_run.log` | ✅ |
| AC-6 | Mô phỏng RTL chạy hết testbench, không assertion nào vi phạm | `05_VERIFICATION/simulation.log` | ✅ |
| AC-7 | Ca kiểm thử bắt buộc của Charter đều có trong testbench | `05_VERIFICATION/test_matrix.csv` | ✅ |
| AC-8 | Có artifact số (waveform / báo cáo) làm bằng chứng | `05_VERIFICATION/` · `06_GDSII/` | ✅ |

## 3. Tiêu chí cấu trúc phần cứng

| # | Tiêu chí | Ngưỡng | Đo được | Trạng thái |
|---|---|---|---|---|
| AC-9 | Số flip-flop phù hợp phân loại Charter **Tuần tự** | > 0 | 7 | ✅ |
| AC-10 | Quy mô cell hợp lý cho 1×1 tile | < 2 000 cell | 36 | ✅ |
| AC-11 | RTL tổng hợp được ra standard cell sky130 | không lỗi | PASS | ✅ |

## 4. Tiêu chí thời gian

| # | Tiêu chí | Đo được | Trạng thái |
|---|---|---|---|
| AC-12 | Có báo cáo STA do chính mình sinh | PASS | ✅ |
| AC-13 | Xác định được đường tới hạn (startpoint → endpoint) | done → _63_ | ✅ |
| AC-14 | Nêu rõ giả định timing khi báo số | xem `02_SPECIFICATION/timing.md` §3 | ✅ |

## 5. Tiêu chí vật lý (chưa chạy)

| # | Tiêu chí | Trạng thái |
|---|---|---|
| AC-15 | Floorplan / Placement / Routing | ⬜ cần PDK sky130A + LibreLane |
| AC-16 | DRC sạch | ⬜ |
| AC-17 | LVS khớp | ⬜ |
| AC-18 | Sinh được file GDSII | ⬜ |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
