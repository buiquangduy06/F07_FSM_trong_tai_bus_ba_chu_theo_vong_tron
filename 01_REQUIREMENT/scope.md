# F07 · Phạm vi (Scope)

Trích và cấu trúc hoá từ **Project Charter — F07, mục 3**.

---

## 1. TRONG PHẠM VI

Tám thành phần bắt buộc của hồ sơ: bối cảnh ứng dụng · sơ đồ khối hệ thống · phân loại analog/digital/mixed · bảng giao diện của chính khối này · một artifact số có chú thích · sơ đồ vòng đời · RTM-lite (yêu cầu → khối → bằng chứng → giới hạn) · kết luận và giới hạn.

### Tám thành phần bắt buộc nằm ở đâu trong cây thư mục này

| # | Thành phần | Vị trí |
|---|---|---|
| 1 | Bối cảnh ứng dụng | `01_REQUIREMENT/application.md` §1 |
| 2 | Sơ đồ khối hệ thống | `03_ARCHITECTURE/system_diagram.md` |
| 3 | Phân loại analog / digital / mixed | `01_REQUIREMENT/application.md` §3 |
| 4 | Bảng giao diện của chính khối này | `02_SPECIFICATION/interface.md` §2 |
| 5 | Một artifact số có chú thích | `05_VERIFICATION/waveforms/` · `06_GDSII/synthesis/` |
| 6 | Sơ đồ vòng đời | `03_ARCHITECTURE/system_diagram.md` §cuối |
| 7 | RTM-lite | `07_TRACEABILITY/RTM.csv` |
| 8 | Kết luận và giới hạn | `07_TRACEABILITY/limitations.md` |

## 2. MỞ RỘNG — tự nguyện, **không** phải điều kiện đạt

Tự nguyện, không phải điều kiện đạt: chạy chuỗi công cụ LibreLane với PDK sky130A trên bộ cài đặt đã xác minh, rồi đọc báo cáo do chính lần chạy đó sinh ra.

Trạng thái trong gói này: script đã chuẩn bị sẵn tại
`04_IMPLEMENTATION/scripts/04_run_librelane.sh`. Kết quả thật **chưa chạy** —
xem `06_GDSII/physical_report.md`.

## 3. NGOÀI PHẠM VI

Ưu tiên động (đó là J10), nhiều bus, chia tách giao dịch. Với mọi đề: thiết kế analog mức transistor, tự làm physical design, ASIC sign-off, tape-out, chế tạo và kiểm tra sau chế tạo.

> ❗ Hệ quả về cách viết kết luận: **không** được dùng phát biểu vượt mức như "đã sign-off",
> "đã tape-out", "đã chế tạo", "đã kiểm tra trên silicon".
> Xem `07_TRACEABILITY/limitations.md`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Nguồn: Charter F07 mục 3.*
