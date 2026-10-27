# F07 · Đường dữ liệu (Datapath)

---

## 1. F07 gần như **không có** datapath — và đó là một kết luận, không phải chỗ trống

Bus dữ liệu **không đi qua** F07 (xem `system_diagram.md` §1). F07 chỉ phát tín hiệu cho
phép. Vì vậy trong F07 không có đường nào mang *dữ liệu người dùng*: mọi đường đều là
**điều khiển** hoặc **trạng thái**.

```
    req[2:0] ──▶ ┌──────────────────────────────┐ ──▶ grant[2:0]   (cho phép)
                 │  chọn xoay + FSM + con trỏ   │ ──▶ busy         (trạng thái)
    done ──────▶ │                              │
                 └──────────────────────────────┘
                          ▲  KHÔNG có đường nào rộng hơn 3 bit
                          │  KHÔNG có phép cộng/trừ/so sánh số học
                          │  KHÔNG có thanh ghi dữ liệu
```

Bằng chứng số học: đường rộng nhất trong toàn thiết kế là **3 bit** (`req`, `grant`,
`selected_grant`). Toàn bộ 36 cell là logic điều khiển và 7 FF trạng thái.

**Vì sao điều này quan trọng:** nó giải thích vì sao F07 nhỏ (327,8144 µm²) và vì sao tỷ lệ
công suất **tuần tự 88,3 % / tổ hợp 11,7 %** — với một mạch không có datapath, gần như toàn
bộ điện năng đi vào clock và flip-flop.

## 2. Bảng các đường tín hiệu

Phân loại theo **bản chất**, vì đây mới là điều đáng dạy ở F07:

| Đường | Độ rộng | Từ | Đến | Bản chất |
|---|---:|---|---|---|
| `req[2:0]` | 3 | cổng vào | khối chọn xoay (3 nhánh `case`) | **Yêu cầu** — chỉ được đọc ở trạng thái `IDLE` |
| `done` | 1 | cổng vào | logic chuyển trạng thái `ACTIVE` + mux `ptr` | **Bắt tay** — nằm trên **đường tới hạn** |
| `ptr[1:0]` | 2 | FF | tín hiệu **chọn** của khối chọn xoay | ★ **Trạng thái công bằng** — trái tim của đề |
| `selected_grant[2:0]` | 3 | khối chọn xoay (tổ hợp) | mux next-state của `grant` | **Kết quả chọn**, chưa cam kết |
| `selected_id[1:0]` | 2 | — | — | ⬛ **MÃ CHẾT** — không cell nào |
| `grant[2:0]` | 3 | FF | cổng ra **và** hồi tiếp vào `case (grant)` | **Cho phép** + **trạng thái** (dùng hai vai) |
| `busy` | 1 | FF | cổng ra | **Trạng thái**, dư thừa thông tin so với `grant` |
| `state` | 1 | FF | tín hiệu chọn của mux next-state | **Điều khiển** |

### 2.1 `grant` đóng **hai vai** — chi tiết dễ bỏ sót

```systemverilog
ACTIVE: begin
    if (done) begin
        case (grant)                      // ← ĐỌC grant như một TRẠNG THÁI
            3'b001: ptr <= 2'd1;
            3'b010: ptr <= 2'd2;
            3'b100: ptr <= 2'd0;
            default: ptr <= ptr;
        endcase
        grant <= 3'b000;                  // ← GHI grant như một ĐẦU RA
```

`grant` vừa là **đầu ra** vừa là **thanh ghi trạng thái nội bộ** lưu "ai đang được phục vụ".
Nhờ vậy module không cần một thanh ghi `served_id` riêng — tiết kiệm 2 FF.

**Hệ quả kiến trúc:** đây chính là lý do `ptr` tiến theo *khối được phục vụ thật* chứ không
theo `ptr+1` (xem `fsm.md` §3). Thông tin "ai được phục vụ" đã có sẵn trong `grant`, nên
dùng luôn là hợp lý. Một thiết kế tính `ptr ← ptr+1` sẽ **rẻ hơn** (không cần bộ giải mã
one-hot→nhị phân) nhưng **sai** về công bằng.

## 3. Đồ thị phụ thuộc

Trong một chu kỳ clock:

```
  mức 0   req[2:0] ────────┐        ptr[1:0] ──┐        done ──┐        grant[2:0] ──┐
          (từ cổng vào)    │        (từ FF)    │       (vào)   │        (từ FF)      │
                           ▼                   ▼               │                     │
  mức 1   ┌────────────────────────────────────────┐           │                     │
          │  KHỐI CHỌN XOAY                        │           │                     │
          │  3 bộ mã hoá ưu tiên + mux theo ptr    │           │                     │
          │  (abc gộp thành nor3b/o211ai/a32oi…)   │           │                     │
          └───────────────┬────────────────────────┘           │                     │
                          │ selected_grant[2:0]                │                     │
                          │                                    ▼                     │
  mức 2                   │                     ┌──────────────────────┐             │
                          │                     │ _53_ o311a_1         │             │
                          │                     │ (state==ACTIVE&&done)│             │
                          │                     └──────────┬───────────┘             │
                          │                                │  0.19 ns                │
                          ▼                                ▼                         ▼
  mức 3   ┌──────────────────────────┐        ┌────────────────────────────────────────┐
          │ mux next-state cho grant │        │ _54_/_56_ mux2i_1                      │
          │ và busy                  │        │ chọn ptr mới theo case(grant)          │
          └────────────┬─────────────┘        └──────────────────┬─────────────────────┘
                       │                                         │  0.18 ns
  mức 4                ▼                                         ▼
          ┌──────── chèn reset đồng bộ ────────────────────────────────────┐
          └────────────┬────────────────────────────────┬──────────────────┘
                       ▼                                ▼  0.05 ns (_55_ isobufsrc)
  đích   [FF grant, busy, state]                 [FF ptr[0], ptr[1]]  ★ ĐƯỜNG TỚI HẠN
```

### Độ sâu logic của từng đích

| Đích (chân D) | Đường đi | Delay đo được |
|---|---|---:|
| **`ptr[0]`** (`_63_`) | `done → _53_ → _54_ → _55_ →` | **1,42 ns** ← tới hạn, slack 8,46 |
| **`ptr[1]`** (`_64_`) | `done → _53_ → _56_ → _57_ →` | **1,42 ns** ← đồng hạng, slack 8,46 |
| `grant[*]`, `busy`, `state` | qua khối chọn xoay | slack lớn hơn — không được STA liệt kê trong `summary.txt` |

> **Kết luận đọc từ số:** hai đường chậm nhất của toàn thiết kế **đều là đường cập nhật con
> trỏ công bằng**, và cả hai đều bắt đầu từ `done`. Datapath (nếu gọi khối chọn xoay là
> datapath) **không** nằm trên đường tới hạn.

## 4. Dự đoán từ RTL vs. kết quả STA thật

| | Nội dung |
|---|---|
| **Dự đoán từ RTL** | Đường dài nhất là **khối chọn xoay**: `case (ptr)` 3 nhánh, mỗi nhánh có chuỗi `if / else if / else if` trên `req` ⟹ nhìn như 3+3 = 6 tầng logic. |
| **STA đo được** | Đường dài nhất là `done → ptr`. Khối chọn xoay **không** xuất hiện trong `sta/summary.txt`. |
| **Lệch?** | ✅ Có |

**Giải thích sự lệch — ba nguyên nhân, đều đọc được từ netlist:**

1. **`abc` gộp chuỗi ưu tiên thành cổng phức hợp.** Trong thư viện `sky130_fd_sc_hd` có các
   cell như `nor3b_1` (3 đầu vào, 1 đảo), `o211ai_1`, `a32oi_1`, `o2bb2ai_1` — mỗi cell
   thực hiện một biểu thức nhiều tầng **trong một tầng transistor**. Ba tầng `else if` trên
   3 bit gộp gọn được. **Số tầng trong RTL không phải số tầng trong silicon.**
2. **Đường `done → ptr` ngắn về số cell (3) nhưng đắt về delay mỗi cell**: `o311a_1` tốn
   **0,19 ns**, `mux2i_1` tốn **0,18 ns**. Cổng phức hợp nhiều đầu vào có điện dung vào lớn
   hơn cổng hai đầu vào, nên "ít cell" không đồng nghĩa "nhanh".
3. **`done` là cổng vào, nên nó mang theo `set_input_delay = 1,0 ns` giả định**, còn khối
   chọn xoay bắt đầu từ flip-flop `ptr`, tức arrival của nó chỉ bằng `t_ckq` của `dfxtp_1` —
   một đại lượng **nhỏ hơn 1,0 ns rất nhiều**. Chênh lệch điểm xuất phát này đủ để đảo ngược
   thứ hạng. ⟹ Một phần "sự lệch" là do **cách ràng buộc**, không phải do mạch.
   ⬜ Con số `t_ckq` chính xác của `_63_` **chưa có** — `timing_report_max.txt` của F07 chỉ
   báo các đường `input → FF`, không báo đường `FF → FF` nào.

> 📌 Điểm 3 rất đáng dạy: nếu `set_input_delay` được đặt bằng 0, đường tới hạn của F07 **có
> thể đổi** sang khối chọn xoay. Con số SDC là một **giả định** và nó **quyết định câu trả
> lời**. Muốn biết đường tới hạn "thật", phải có số input delay thật từ hệ thống bao quanh —
> hiện chưa có (`02_SPECIFICATION/timing.md` §3, giả định G-2).

## 5. Giá của công bằng — phân tích chưa đủ số liệu

Charter mục 9 hỏi round-robin tốn thêm **bao nhiêu cell** so với ưu tiên cố định.

| | `f07_rr_arbiter` | `f07_bad_fixed_priority` |
|---|---:|---|
| Cell | **36** (đo được) | ⬜ **chưa đo** |
| Flip-flop | **7** (đo được) | **0** — đọc từ RTL: module chỉ có một `always_comb`, không có `always_ff` nào |
| Diện tích | **327,8144 µm²** (đo được) | ⬜ chưa đo |
| Loại mạch | Tuần tự | **Tổ hợp thuần** |
| Có `done`/`busy` không | Có | ❌ không — không có khái niệm giao dịch |
| Có công bằng không | ✅ | ❌ |

**Vì sao chưa đo được:** `06_GDSII/synthesis/synth.ys` dòng 4 đặt
`hierarchy -check -top f07_rr_arbiter`, nên `f07_bad_fixed_priority` bị loại khỏi thiết kế
và không xuất hiện trong `synth_stat.txt`.

**Cách lấy số:** chạy thêm một lần tổng hợp với
`hierarchy -check -top f07_bad_fixed_priority`, rồi so `Number of cells` và `Chip area`.

**Lưu ý quan trọng khi so sánh — phép so này KHÔNG công bằng nếu làm ẩu:** hai module không
cùng chức năng. `f07_bad_fixed_priority` không có `done`, không có `busy`, không giữ quyền
qua nhiều chu kỳ. Phần lớn chênh lệch cell sẽ đến từ **cơ chế giao dịch** (FSM + `grant`
đăng ký + `busy`), **không phải** từ round-robin. Muốn tách riêng giá của công bằng, phải so
với một biến thể thứ ba: *cùng FSM `IDLE/ACTIVE`, cùng `grant` đăng ký, nhưng bỏ `ptr` và
dùng ưu tiên cố định*. Chênh lệch khi đó ≈ **2 FF (`ptr`) + logic xoay 3 nhánh**.

Dự đoán cấu trúc (**chưa đo**): giá của công bằng ≈ 2 FF + hai bộ mã hoá ưu tiên phụ + mux
3 chiều. Xem `tradeoff.md` §4 để biết chính xác cần chạy gì.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
