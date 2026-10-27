# F07 · Mã nguồn GỐC (chưa sửa)

Thư mục này giữ **bản gốc** của mã nguồn thầy cung cấp, đúng như lúc nhận từ gói
`F07_FINAL_MENTOR_PACKAGE_v1_0`, **trước** mọi bản vá.

| Thư mục | Nội dung |
|---|---|
| `rtl/` | RTL thiết kế, bản gốc |
| `golden_model/` | Mô hình chuẩn (SystemVerilog + Python), bản gốc |
| `testbench/` | Testbench, bản gốc |

## Dùng để làm gì

1. **Quay lui.** Chép đè ngược lại `04_IMPLEMENTATION/rtl/`, `05_VERIFICATION/golden_model/`,
   `05_VERIFICATION/testbench/` là về nguyên trạng ban đầu.
2. **Đối chiếu trước/sau.** So bản gốc với bản đã vá để thấy chính xác thay đổi gì:
   ```bash
   diff -u 08_ORIGINAL_SOURCE/rtl/<file>.sv 04_IMPLEMENTATION/rtl/<file>.sv
   ```
3. **Tài liệu dạy học.** Nhiều lỗi trong bản gốc là bẫy kinh điển rất đáng đưa vào bài giảng:
   *"đây là mã ban đầu, đây là lỗi, đây là cách phát hiện, đây là bản vá"*.

## Nhật ký vá

Danh sách đầy đủ từng thay đổi kèm lý do: [`PATCHLOG.md`](PATCHLOG.md)
(chỉ có ở các đề thực sự bị sửa).

Chẩn đoán chi tiết: `../05_VERIFICATION/known_issues.md`.

---

*Phiên bản: v1.0 (bản gốc) · Đóng băng ngày 2026-09-24*
