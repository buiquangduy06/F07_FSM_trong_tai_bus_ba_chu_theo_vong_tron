# F07 · Phần điều khiển (Control)

F07 **gần như toàn bộ là phần điều khiển** — ngược hẳn với A01 (toàn bộ là datapath). Vì
vậy mục này là mục dài nhất trong tầng kiến trúc của F07.

---

## 1. Ba tầng điều khiển lồng nhau

```
 ┌─ TẦNG 3 · CHÍNH SÁCH CÔNG BẰNG ────────────────────────────────────┐
 │   ptr[1:0]  —  quyết định THỨ TỰ QUÉT                              │
 │   cập nhật: sau mỗi giao dịch, ptr ← (khối vừa phục vụ + 1) mod 3   │
 │   ┌─ TẦNG 2 · CHỌN TRONG MỘT LƯỢT ─────────────────────────────┐   │
 │   │   khối chọn xoay (always_comb)                             │   │
 │   │   quyết định: trong lượt này, AI thắng                     │   │
 │   │   ┌─ TẦNG 1 · GIAO DỊCH ───────────────────────────────┐   │   │
 │   │   │   FSM state (IDLE / ACTIVE)                        │   │   │
 │   │   │   quyết định: có đang cấp quyền hay không          │   │   │
 │   │   └────────────────────────────────────────────────────┘   │   │
 │   └────────────────────────────────────────────────────────────┘   │
 └────────────────────────────────────────────────────────────────────┘
```

Ba tầng có **chu kỳ thay đổi khác nhau**, và đó là điểm kiến trúc đáng nắm:

| Tầng | Đổi khi nào | Ô nhớ |
|---|---|---:|
| 1 · giao dịch | mỗi lần cấp/nhả quyền | 1 FF (`state`) |
| 2 · chọn | **tổ hợp** — đổi liên tục theo `req` | 0 |
| 3 · công bằng | **chỉ khi một giao dịch hoàn tất** | 2 FF (`ptr`) |

Tầng 3 đổi **chậm nhất** nhưng lại là tầng quyết định tính chất quan trọng nhất (không bỏ
đói). Đây là cấu trúc điển hình của các bộ trọng tài: chính sách nằm ở tầng chậm, cơ chế
nằm ở tầng nhanh.

## 2. Bảng tín hiệu điều khiển và tác dụng

| Tín hiệu | Chiều | Sinh ra ở đâu | Tác dụng | Dòng RTL |
|---|---|---|---|---:|
| `req[2:0]` | vào | tầng ngoài | **Chỉ được đọc khi `state = IDLE`.** Ở `ACTIVE` bị bỏ qua hoàn toàn. | 30–46 (qua `always_comb`), dùng ở 58 |
| `done` | vào | khối chủ đang được cấp quyền | Kết thúc giao dịch: nhả `grant`, hạ `busy`, **tiến `ptr`** | 65 |
| `grant[2:0]` | ra | FF | Cho phép một khối lái bus. Đồng thời là **trạng thái nội bộ** "ai đang được phục vụ" | 58, 67, 73 |
| `busy` | ra | FF | Báo bus đang bận. Dư thừa (suy được từ `grant`) nhưng Charter mục 4 yêu cầu | 59, 74 |
| `ptr[1:0]` | **nội bộ** | FF | Chọn thứ tự quét. ❌ **Charter mục 4 yêu cầu xuất ra `uo_out[4:3]` — RTL không xuất** | 30, 68–71 |
| `state` | nội bộ | FF | Chọn giữa "đang chọn" và "đang phục vụ" | 56 |
| `selected_grant` | nội bộ | tổ hợp | Kết quả chọn, **chưa cam kết** — chỉ thành `grant` khi FSM ở `IDLE` | 28–46 |

### 2.1 Vì sao tách `selected_grant` (tổ hợp) khỏi `grant` (đăng ký)

Đây là quyết định kiến trúc trung tâm của F07:

```systemverilog
// tổ hợp — "nếu bây giờ phải chọn thì chọn ai"
always_comb begin
    selected_grant = 3'b000;
    case (ptr) … endcase
end

// tuần tự — "cam kết lựa chọn đó"
IDLE: begin
    grant <= selected_grant;          // ← chỉ ở IDLE mới cam kết
    busy  <= (selected_grant != 3'b000);
```

| Nếu KHÔNG tách (gán thẳng `grant = selected_grant`) | Hậu quả |
|---|---|
| `grant` thành tổ hợp | **Glitch** khi `req` đổi ⟹ hai khối có thể cùng lái bus trong vài trăm ps |
| `grant` đổi khi `req` đổi giữa giao dịch | **Cướp quyền** — khối đang lái bus bị cắt giữa chừng ⟹ hỏng dữ liệu |
| Không cần `busy` | Nhưng Charter mục 4 vẫn yêu cầu |

Việc tách này là cơ chế bảo đảm **INV-3** (quyền không bị cướp) và là lý do F07 tốn 3 FF cho
`grant` — vượt dự đoán 3–5 FF của Charter mục 10. Xem `fsm.md` §7.1.

## 3. Cơ chế "không đọc `req` khi bận" — đọc kỹ chỗ vắng mặt

```systemverilog
ACTIVE: begin
    if (done) begin
        …
    end
    // KHÔNG CÓ else — và không có dòng nào nhắc tới req
end
```

Hai điều đáng chú ý ở đoạn này:

1. **`req` hoàn toàn vắng mặt trong nhánh `ACTIVE`.** Đây không phải thiếu sót mà là đặc tả:
   quyền không bị cướp. Bằng chứng đã chạy: `f07_tb.sv` dòng 57–59 đặt `req=3'b000` trong
   lúc `ACTIVE` và khẳng định `grant` **vẫn** bằng `3'b001` — PASS tại t=106.
2. **Không có `else`.** Trong `always_ff`, không gán ⟹ giữ nguyên ⟹ sinh **mux hồi tiếp**,
   **không** sinh latch (latch chỉ suy ra trong khối tổ hợp). Đây là chỗ sinh viên hay lo
   nhầm.

## 4. Cơ chế tiến con trỏ — bộ giải mã one-hot → thứ tự kế tiếp

```systemverilog
case (grant)
    3'b001: ptr <= 2'd1;     // M0 vừa được phục vụ → lượt sau bắt đầu từ M1
    3'b010: ptr <= 2'd2;
    3'b100: ptr <= 2'd0;     // ← WRAP: đây là chỗ "vòng tròn" khép kín
    default: ptr <= ptr;     // grant=000 (không thể xảy ra ở ACTIVE) → giữ
endcase
```

| Đặc điểm | Ghi chú |
|---|---|
| Đây là **bảng tra 3 mục**, không phải phép cộng | Rẻ hơn `ptr <= ptr + 1` **có kiểm wrap**, vì one-hot→nhị phân trên 3 bit rất rẻ |
| `3'b100 → 2'd0` là **toàn bộ** phần wrap | Không có phép modulo, không có bộ so sánh |
| `default: ptr <= ptr` | Phòng vệ cho `grant = 000` — không thể xảy ra ở `ACTIVE` nhưng vẫn viết |
| Nằm trên **đường tới hạn** | `_54_ mux2i_1`, 0,18 ns — xem `block_diagram.md` §3 |

**Sai lầm thường gặp mà đoạn này tránh được:** viết `ptr <= ptr + 1'b1`. Khi đó nếu `ptr=0`
mà M0 không xin, M2 được phục vụ, `ptr` chỉ nhảy tới 1 — M2 vẫn ở gần đầu hàng đợi và có
thể được phục vụ lại sớm. Round-robin **hình thức** chứ không **thật**. Mô hình Python có
đúng logic đúng: `self.ptr = (i + 1) % 3` với `i` là khối được phục vụ (dòng 28–30).

## 5. Quan hệ điều khiển ↔ "datapath"

F07 gần như không có datapath (xem `datapath.md` §1). Giao diện giữa hai phần rất mỏng:

```
  ĐIỀU KHIỂN                                 "DATAPATH"
  ──────────                                 ───────────
  ptr[1:0] ─────── chọn thứ tự quét ────────▶ khối chọn xoay (tổ hợp)
  state ────────── cho phép cam kết ────────▶ mux next-state của grant
                                              │
  grant[2:0] ◀──── kết quả ───────────────────┘
      │
      └─────────── quay lại điều khiển: case(grant) tiến ptr
```

Vòng khép kín này là **điểm đặc sắc kiến trúc của F07**: đầu ra (`grant`) quay ngược lại
làm đầu vào cho chính sách (`ptr`). Không có vòng này thì không có ký ức về lượt phục vụ.

## 6. Chiến lược reset

| Hạng mục | Giá trị | Bằng chứng |
|---|---|---|
| Kiểu reset | **Đồng bộ**, tích cực mức thấp | `always_ff @(posedge clk)` không có `or negedge rst_n` (dòng 49) |
| Phủ thanh ghi nào | `state`, `ptr`, `grant`, `busy` — **tất cả 7 FF** | dòng 50–54 |
| Trạng thái sau reset | `IDLE`, `ptr=0`, `grant=000`, `busy=0` | dòng 51–54 |
| Chi phí phần cứng | Cổng chèn trên đường `D` của mỗi FF. Cell `lpflow_isobufsrc_1 ×4` là ứng viên rõ nhất | netlist |
| Chi phí timing | `_55_` (isobufsrc) trên đường tới hạn: **0,05 ns** | `timing_report_max.txt` |
| Đã kiểm chưa | **CHƯA** — assertion phục hồi sau reset ở TB dòng 74–80 **chưa chạy tới** | `known_issues.md` §6 |

> `ptr <= 2'd0` khi reset là quan trọng hơn vẻ ngoài: nó bảo đảm **INV-5** (`ptr ≠ 3`) ngay
> từ chu kỳ đầu. Nếu reset không phủ `ptr`, `ptr` có thể khởi động ở `3` và FSM sẽ hành xử
> theo nhánh `default` — vẫn chạy đúng (xem `fsm.md` §6.2) nhưng lệch một lượt công bằng.
> Đây là lý do assertion ở TB dòng 74–80 cần được chạy.

## 7. Điều khiển **vắng mặt**: không có timeout

Phải ghi rõ chỗ này vì nó là lỗ hổng lớn nhất của kiến trúc:

| Cơ chế bảo vệ | Có trong F07? |
|---|:-:|
| Timeout khi khối chủ không phát `done` | ❌ |
| Huỷ quyền cưỡng bức | ❌ |
| Bộ đếm watchdog | ❌ |
| Báo lỗi ra tầng ngoài | ❌ |

Hậu quả: nếu một khối chủ hỏng, `state` kẹt ở `ACTIVE` vĩnh viễn, `busy` dính 1, và hai
khối kia **bị bỏ đói tuyệt đối** — đúng cái tính chất mà Charter mục 9 yêu cầu chứng minh
là không xảy ra.

**Phải phát biểu cho chính xác:** F07 bảo đảm không bỏ đói **với điều kiện** mọi khối chủ
tuân thủ hợp đồng phát `done`. Đó là một bảo đảm **có điều kiện**, và điều kiện đó hiện
**chưa được ghi ở bất kỳ đâu** trong tầng đặc tả tự sinh. Ghi nhận ở đây và ở
`functional_spec.md` §5; **không tự sửa RTL**.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
