# F07 · Assertion

Gói nguồn có file assertion riêng.

Các file `properties.sv` trong `../testbench/` chứa assertion đồng thời (SVA). Lưu ý: **Icarus Verilog 12.0 không hỗ trợ đầy đủ `assert property` và không hỗ trợ `bind`** — muốn chạy chúng cần Verilator (`--assert`), Questa, VCS hoặc Xcelium.

## Bất biến nên bổ sung khi mở rộng kiểm chứng

| Bất biến | Nội dung |
|---|---|
| INV-1 | Kết quả của DUT luôn bằng kết quả của mô hình chuẩn trên mọi vector hợp lệ |
| INV-2 | Không có tín hiệu ra nào ở trạng thái `X`/`Z` sau khi reset xong |
| INV-3 | Sau reset, khối luôn về trạng thái khởi tạo xác định |

*Phiên bản: v1.0 · Ngày: 2026-09-24*
