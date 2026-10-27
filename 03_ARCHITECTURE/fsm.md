# F07 · Máy trạng thái hữu hạn (FSM)

> **F07 có FSM thật, nhưng "trạng thái" của nó gồm HAI phần độc lập** — và đó là điểm kiến
> trúc quan trọng nhất của đề này:
>
> ```
>    state (1 bit)  — bus đang rảnh hay bận      → FSM điều khiển giao dịch
>    ptr   (2 bit)  — ai được quét trước          → TRẠNG THÁI CÔNG BẰNG
> ```
>
> Nhiều sinh viên chỉ vẽ FSM `IDLE/ACTIVE` rồi dừng — và như thế **bỏ mất toàn bộ phần
> round-robin**. Vòng tròn không nằm trong `state`; nó nằm trong `ptr`.

---

## 1. Bằng chứng có FSM

| Bằng chứng | Trích / nguồn |
|---|---|
| Kiểu liệt kê trạng thái tường minh | `typedef enum logic {IDLE, ACTIVE} state_t;` (RTL dòng 10) |
| Thanh ghi trạng thái | `state_t state;` (dòng 11) |
| Rẽ nhánh theo trạng thái | `case (state)` trong `always_ff` (dòng 56) |
| **Netlist xác nhận** | `sky130_fd_sc_hd__dfxtp_1 _58_ (.CLK(clk), .D(_00_), .Q(state));` — `06_GDSII/synthesis/netlist.v` dòng 214–218 |
| Trạng thái công bằng tồn tại thật | `_63_ .Q(\ptr[0] )` và `_64_ .Q(\ptr[1] )` — netlist dòng 239–248 |

Tổng **7 flip-flop** đo được (`synth_stat.txt`), phân bổ theo netlist:

| FF | Tín hiệu | Vai trò |
|---|---|---|
| `_58_` | `state` | FSM giao dịch |
| `_59_ _60_ _61_` | `grant[0..2]` | **đầu ra đăng ký** |
| `_62_` | `busy` | **đầu ra đăng ký** |
| `_63_ _64_` | `ptr[0..1]` | **trạng thái công bằng** |

> 👉 Charter mục 10 dự đoán *"2 (con trỏ ưu tiên) + 1–2 (bận) ≈ 3–5 ô nhớ"*. Đo được **7**.
> Chênh **+2..4 FF**, và nguyên nhân đọc được ngay từ netlist: Charter ngầm giả định
> `grant` là **tổ hợp** (suy thẳng từ `req` và `ptr`), còn RTL chọn **đăng ký** `grant`
> (3 FF) và `busy` (1 FF). Đây không phải lỗi — là một đánh đổi có chủ ý (xem §7).

## 2. Sơ đồ trạng thái ASCII — FSM giao dịch (`state`)

```
                    ┌──────── selected_grant == 000 / grant←000, busy←0 ────────┐
                    │              (không ai xin — ở lại IDLE)                   │
                    │                                                            │
       reset        ▼                                                            │
         │   ╔══════════════════╗                                                │
         └──▶║      IDLE        ║────────────────────────────────────────────────┘
             ║     state = 0    ║
             ║  grant = 000     ║      selected_grant != 000
             ║  busy  = 0       ║      / grant ← selected_grant
             ╚══════════════════╝        busy  ← 1
                    ▲                            │
                    │                            ▼
                    │                 ╔══════════════════════╗
                    │                 ║       ACTIVE         ║◀────┐
                    │                 ║      state = 1       ║     │
                    │                 ║  grant = one-hot     ║     │ done == 0
                    │                 ║  busy  = 1           ║     │ / GIỮ NGUYÊN
                    │                 ╚══════════════════════╝     │ (không đọc req)
                    │                            │                 │
                    │                            └─────────────────┘
                    │                            │
                    │       done == 1            │
                    └────────────────────────────┘
                      / grant ← 000, busy ← 0,
                        ptr ← next(grant)   ◀── ★ CHỖ DUY NHẤT ptr THAY ĐỔI
```

**Đọc sơ đồ:** FSM này chỉ có 2 trạng thái và cực kỳ đơn giản. Toàn bộ độ thông minh của
round-robin nằm ở **nhãn cạnh** `ptr ← next(grant)` và ở khối tổ hợp `case (ptr)` — không
nằm ở số trạng thái.

## 3. Sơ đồ trạng thái ASCII — con trỏ công bằng (`ptr`)

```
                  ┌──────────────────────────────────────────────────┐
                  │                                                  │
      reset       ▼                                                  │
        │   ╔═══════════╗  phục vụ M0   ╔═══════════╗  phục vụ M1   ╔═══════════╗
        └──▶║  ptr = 0  ║──────────────▶║  ptr = 1  ║──────────────▶║  ptr = 2  ║
            ║ quét:0,1,2║  (grant=001)  ║ quét:1,2,0║  (grant=010)  ║ quét:2,0,1║
            ╚═══════════╝               ╚═══════════╝               ╚═════╤═════╝
                  ▲                                                       │
                  │                    phục vụ M2  (grant=100)            │
                  └───────────────────────────────────────────────────────┘

            ╔═══════════╗
            ║  ptr = 3  ║   ⚠️ BẤT HỢP LỆ — không tới được (xem §6)
            ║ quét:2,0,1║      nhưng CÓ ĐƯỢC XỬ LÝ qua nhánh `default`
            ╚═══════════╝
```

**Ghi chú mấu chốt:** `ptr` **không** tiến theo `ptr+1`. Nó nhảy tới `(i+1) mod 3` với `i`
là khối **thật sự được phục vụ**:

```systemverilog
case (grant)
    3'b001: ptr <= 2'd1;
    3'b010: ptr <= 2'd2;
    3'b100: ptr <= 2'd0;
    default: ptr <= ptr;
endcase
```

Nếu `ptr = 0` mà M0 không xin, M2 được phục vụ, thì `ptr` nhảy thẳng tới **0** — **không**
tới 1. Đây là điểm khác biệt giữa round-robin **đúng** và round-robin **hình thức**, và là
chỗ quyết định tính không bỏ đói. Mô hình Python có đúng logic này:
`self.ptr = (i + 1) % 3` với `i` lấy từ `{1:0, 2:1, 4:2}[self.grant]` (dòng 28–30).

## 4. Bảng chuyển trạng thái đầy đủ

### 4.1 Bảng chọn (tổ hợp) — `selected_grant` theo `(ptr, req)`

Đọc từ `always_comb` dòng 26–47. `—` = không quan tâm.

| `ptr` | Thứ tự quét | `req[0]` | `req[1]` | `req[2]` | `selected_grant` | `selected_id` | Dòng |
|:---:|---|:---:|:---:|:---:|:---:|:---:|---:|
| 0 | 0,1,2 | 1 | — | — | `001` | 0 | 32 |
| 0 | 0,1,2 | 0 | 1 | — | `010` | 1 | 33 |
| 0 | 0,1,2 | 0 | 0 | 1 | `100` | 2 | 34 |
| 0 | 0,1,2 | 0 | 0 | 0 | `000` | 0 | 27–28 (mặc định) |
| 1 | 1,2,0 | — | 1 | — | `010` | 1 | 37 |
| 1 | 1,2,0 | — | 0 | 1 | `100` | 2 | 38 |
| 1 | 1,2,0 | 1 | 0 | 0 | `001` | 0 | 39 |
| 1 | 1,2,0 | 0 | 0 | 0 | `000` | 0 | mặc định |
| 2 *(và 3)* | 2,0,1 | — | — | 1 | `100` | 2 | 42 |
| 2 *(và 3)* | 2,0,1 | 1 | — | 0 | `001` | 0 | 43 |
| 2 *(và 3)* | 2,0,1 | 0 | 1 | 0 | `010` | 1 | 44 |
| 2 *(và 3)* | 2,0,1 | 0 | 0 | 0 | `000` | 0 | mặc định |

**Kiểm tính đầy đủ:** 4 (giá trị `ptr`) × 8 (tổ hợp `req`) = 32 tổ hợp, bảng trên phủ hết
qua các hàng có `—`. Không có tổ hợp nào rơi ra ngoài (nhờ gán mặc định ở dòng 27–28) ⟹
**không suy ra latch**.

> `selected_id` được tính nhưng **không bao giờ được dùng** ở đâu khác trong module — hàm
> `onehot3` (dòng 17–24) cũng vậy. Cả hai là **mã chết**; Yosys xoá sạch (`opt_clean -purge`
> trong `synth.ys` dòng 15). Bằng chứng: netlist không có FF nào tên `selected_id`. Đây là
> tàn dư của một cách viết khác (dùng `onehot3(selected_id)` thay vì gán thẳng
> `selected_grant`) — vô hại, nhưng nên dọn.

### 4.2 Bảng chuyển trạng thái tuần tự

| # | `state` | `done` | `selected_grant` | `state'` | `grant'` | `busy'` | `ptr'` | Dòng |
|---:|---|:---:|:---:|---|:---:|:---:|---|---:|
| T1 | `IDLE` | — | `000` | `IDLE` | `000` | 0 | giữ | 58–59 |
| T2 | `IDLE` | — | `≠000` | **`ACTIVE`** | `selected_grant` | **1** | giữ | 58–61 |
| T3 | `ACTIVE` | **0** | — | `ACTIVE` | **giữ** | giữ (1) | giữ | 64–65 (không nhánh nào chạy) |
| T4 | `ACTIVE` | **1** | — | **`IDLE`** | `000` | 0 | **`next(grant)`** | 65–75 |
| R | bất kỳ | — | — | `IDLE` | `000` | 0 | `0` | 50–54 |
| D | *(không tới được)* | — | — | `IDLE` | `000` | 0 | `0` | 79–84 |

**Điểm đáng chú ý ở T3:** khi `ACTIVE` và `done=0`, **không có câu lệnh gán nào chạy**
(nhánh `if (done)` không thoả, không có `else`). Trong `always_ff` điều này có nghĩa là
"giữ nguyên" — sinh **mạch giữ** (mux hồi tiếp), không sinh latch. Đây cũng chính là cơ chế
bảo đảm INV-3 (quyền không bị cướp): trạng thái `ACTIVE` **hoàn toàn không đọc `req`**.

## 5. Mã hoá trạng thái

```systemverilog
typedef enum logic {IDLE, ACTIVE} state_t;   // 1 BIT, không phải [1:0]
logic [1:0] ptr;
```

| | `state` | `ptr` |
|---|---|---|
| Bề rộng | **1 bit** | 2 bit |
| Số giá trị dùng | 2 / 2 — **hết không gian mã** | **3 / 4** — còn 1 mã thừa |
| Kiểu mã hoá | Nhị phân (tầm thường với 2 trạng thái) | Nhị phân |
| Giá trị sau reset | `IDLE` = 0 | `0` |
| Có trạng thái bất hợp lệ? | ❌ **Không thể có** | ✅ **Có: `ptr = 3`** |
| FF trong netlist | `_58_` | `_63_`, `_64_` |

### 5.1 Vì sao `logic` chứ không `logic [1:0]` lại là một quyết định đáng khen

Viết `typedef enum logic {IDLE, ACTIVE}` (1 bit) thay vì `enum logic [1:0]` (2 bit) làm cho
không gian mã **khít** với số trạng thái. Hệ quả:

- Tiết kiệm 1 FF.
- **Xoá bỏ hoàn toàn khả năng có trạng thái bất hợp lệ** trong `state` — không cần logic
  phục hồi, không cần lo SEU đẩy FSM vào mã lạ.
- Nhánh `default` ở dòng 79–84 trở thành **mã chết** (§6).

Đối chiếu: `ptr` dùng 3 trên 4 mã, nên `ptr` **có** trạng thái bất hợp lệ thật và **cần**
xử lý thật. Hai tín hiệu, hai tình huống khác nhau, trong cùng một module — rất tiện để dạy.

## 6. Xử lý trạng thái bất hợp lệ

### 6.1 `state` — không có trạng thái bất hợp lệ

```systemverilog
default: begin
    state <= IDLE;  ptr <= 2'd0;  grant <= 3'b000;  busy <= 1'b0;
end
```

| Câu hỏi | Trả lời |
|---|---|
| Nhánh này bao giờ chạy? | **Không bao giờ.** `state` là 1 bit, `IDLE`/`ACTIVE` phủ cả 2 giá trị. Trong mô phỏng, chỉ chạy nếu `state = X` (trước cạnh clock đầu tiên khi chưa reset). |
| Có tốn cell không? | **Không.** `opt` xoá. Bằng chứng: netlist chỉ có 1 FF cho `state`, và logic quanh nó không có nhánh phục hồi nào. |
| Vậy viết làm gì? | Chặn suy ra latch nếu sau này thêm trạng thái; cho mô phỏng hành vi xác định khi `X`; thoả quy ước lint. |

### 6.2 `ptr = 3` — trạng thái bất hợp lệ **thật**, được xử lý ở khối tổ hợp

Đây mới là chỗ có nội dung.

```systemverilog
case (ptr)
    2'd0: …
    2'd1: …
    default: begin          // ★ bắt CẢ ptr=2 LẪN ptr=3
        if      (req[2]) … else if (req[0]) … else if (req[1]) …
    end
endcase
```

| Câu hỏi | Trả lời có bằng chứng |
|---|---|
| `ptr = 3` có tới được không? | **Không**, trong hoạt động bình thường. Reset đặt `ptr=0`; mọi lệnh gán `ptr` chỉ sinh `0`, `1`, `2`, hoặc giữ nguyên (dòng 52, 68–71, 81). Bằng quy nạp: `ptr ∈ {0,1,2}` mãi mãi. Đó là **INV-5**. |
| Nếu vẫn xảy ra (SEU, ép `force` khi debug) thì sao? | FSM **vẫn chạy đúng chức năng**: `default` cho `ptr=3` dùng thứ tự quét `2,0,1` (giống `ptr=2`). Quyền vẫn được cấp, INV-1 vẫn giữ. |
| Có tự phục hồi không? | **Có, sau đúng một giao dịch.** Ngay khi một giao dịch hoàn tất, `case (grant)` ghi `ptr` bằng `1`, `2` hoặc `0` — một giá trị hợp lệ. |
| Có mất công bằng trong lúc đó không? | Có, tạm thời: `ptr=3` hành xử như `ptr=2`, nên M2 được ưu tiên hai lượt liền. **Không bỏ đói** (chặn trên vẫn hữu hạn), chỉ lệch một lượt. |
| Đây là thiết kế cố ý hay may mắn? | Dùng `default` thay vì `2'd2:` là một lựa chọn **tốt**: nó gộp luôn mã thừa vào một nhánh hợp lệ. Cách làm chuẩn để FSM **tự phục hồi** (self-correcting). |

> 👉 So sánh hai cách viết:
>
> | Cách viết | `ptr=3` xảy ra thì sao |
> |---|---|
> | `default:` (RTL hiện tại) | Quét theo `2,0,1` — **an toàn, tự phục hồi sau 1 giao dịch** |
> | `2'd2:` + `default: selected_grant = 3'b000;` | **Không cấp quyền cho ai** khi `ptr=3` ⟹ nếu không khối nào hoàn tất giao dịch thì `ptr` không bao giờ được ghi lại ⟹ **kẹt vĩnh viễn** |
>
> Cùng một mã bất hợp lệ, hai cách viết, một cái tự phục hồi và một cái deadlock. Đây là
> câu hỏi bảo vệ rất tốt.

## 7. Moore hay Mealy — kèm bằng chứng

**`f07_rr_arbiter` là máy MOORE**, và ở đây có **bằng chứng mức netlist**, mạnh hơn hẳn
bằng chứng mức RTL.

### Bằng chứng 1 — mức RTL

`grant` và `busy` chỉ xuất hiện ở vế trái của `<=` bên trong `always_ff` (dòng 53–54, 58–59,
73–74, 82–83). Không có `assign`, không có `always_comb` nào gán chúng.

### Bằng chứng 2 — mức netlist (bằng chứng mạnh)

`06_GDSII/synthesis/netlist.v` dòng 219–238:

```verilog
sky130_fd_sc_hd__dfxtp_1 _59_ (.CLK(clk), .D(_01_), .Q(grant[0]));
sky130_fd_sc_hd__dfxtp_1 _60_ (.CLK(clk), .D(_02_), .Q(grant[1]));
sky130_fd_sc_hd__dfxtp_1 _61_ (.CLK(clk), .D(_03_), .Q(grant[2]));
sky130_fd_sc_hd__dfxtp_1 _62_ (.CLK(clk), .D(_04_), .Q(busy));
```

Chân `Q` của flip-flop nối **thẳng** vào cổng ra — **không có cổng tổ hợp nào ở giữa**. Đây
là định nghĩa hình học của một máy Moore: không tồn tại đường tổ hợp nào từ `req` hay `done`
tới `grant`/`busy`.

### Bằng chứng 3 — STA xác nhận

`06_GDSII/sta/summary.txt` chỉ báo **một** đường tới hạn duy nhất:
`done (input) → _63_/D`. Không có đường `input → output` nào được liệt kê. Nếu là Mealy,
STA sẽ phải báo một đường `req → grant` (in→out).

### 7.1 Cái giá của Moore — đọc từ số liệu thật

| | Moore (RTL hiện tại) | Mealy (giả định) |
|---|---|---|
| FF | **7** (đo được) | ≈3 (`state` + `ptr`) |
| Độ trễ `req` → `grant` | **1 chu kỳ** | 0 chu kỳ |
| Glitch ở `grant` | **Không** | Có — nguy hiểm cho bus |
| Đường tổ hợp in→out | **Không** | Có — khó ràng buộc timing |
| Charter mục 10 dự đoán | 3–5 FF | ✅ khớp |

⟹ RTL đã đổi **+4 FF và +1 chu kỳ độ trễ** lấy **không glitch trên đường cấp quyền bus**.
Với một tín hiệu điều khiển bus — nơi một glitch có thể làm hai khối cùng lái bus trong vài
trăm pico giây — đây là đánh đổi **đúng**. Chênh lệch so với dự đoán của Charter mục 10 là
hệ quả của lựa chọn này, không phải lỗi.

## 8. Vì sao FSM này trả lời được câu hỏi Charter mục 2 số 1

> *"'Round-robin' hiện ra trong phần cứng dưới dạng gì — con trỏ quay hay ưu tiên xoay?"*

**Trả lời: cả hai, và chúng là hai bộ phận khác nhau.**

| Thành phần | Hiện ra là gì | Bằng chứng phần cứng |
|---|---|---|
| **Con trỏ quay** | **2 flip-flop** lưu `ptr` | netlist dòng 239–248: `_63_.Q(\ptr[0])`, `_64_.Q(\ptr[1])` |
| **Ưu tiên xoay** | **Logic tổ hợp** — ba chuỗi ưu tiên khác nhau được chọn bởi `ptr` | `case (ptr)` dòng 30–46; trong netlist là các cell `nor3b_1`, `o211ai_1`, `a21boi_0`… |

Nói cách khác: **con trỏ là trạng thái, ưu tiên xoay là hàm của trạng thái đó.** Hai thứ
không thay thế cho nhau. Không có con trỏ thì không có ký ức về lượt; không có ưu tiên xoay
thì con trỏ vô dụng.

Cách kiểm chứng sạch nhất là **đưa `ptr` ra cổng** đúng như Charter mục 4 yêu cầu
(`uo_out[4:3]`) — nhưng RTL **không** làm, nên hiện phải quan sát gián tiếp qua thứ tự phục
vụ. Xem cảnh báo đầu `functional_spec.md`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
