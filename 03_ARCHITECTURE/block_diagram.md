# F07 · Sơ đồ khối bên trong (Block Diagram)

> Vẽ theo **đúng** `04_IMPLEMENTATION/rtl/f07_rr_arbiter.sv` và đối chiếu với
> `06_GDSII/synthesis/netlist.v` (36 cell, 7 FF).

---

## 1. Sơ đồ khối

```
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │                            f07_rr_arbiter  (36 cell)                          │
 │                                                                               │
 │  req[2:0] ──┬────────────────────────────────────────────┐                    │
 │             │                                            │                    │
 │             ▼                                            │                    │
 │  ┌──────────────────────────────────────────┐            │                    │
 │  │   KHỐI CHỌN XOAY  (always_comb, dòng 26) │            │                    │
 │  │                                          │            │                    │
 │  │   case (ptr)                             │            │                    │
 │  │     0 → quét 0,1,2  ─┐                   │            │                    │
 │  │     1 → quét 1,2,0  ─┼─▶ chuỗi ưu tiên   │            │                    │
 │  │     2/3 → quét 2,0,1─┘   (3 bộ mã hoá     │           │                    │
 │  │                          ưu tiên xoay)   │            │                    │
 │  └──────────────┬───────────────────────────┘            │                    │
 │                 │ selected_grant[2:0]                    │                    │
 │                 │ (one-hot hoặc 000)                     │                    │
 │                 ▼                                        │                    │
 │  ┌───────────────────────────────────────────────────────┴──────────────┐     │
 │  │          FSM GIAO DỊCH  (always_ff, dòng 49)                          │     │
 │  │                                                                       │     │
 │  │   ┌──────────┐   selected_grant≠0   ┌──────────┐                      │     │
 │  │   │  IDLE    │─────────────────────▶│  ACTIVE  │◀─┐ done=0           │     │
 │  │   │ state=0  │◀─────────────────────│ state=1  │──┘ (giữ)            │     │
 │  │   └──────────┘      done=1          └──────────┘                      │     │
 │  │        │                                  │                          │     │
 │  │        │ grant←selected_grant              │ done=1                   │     │
 │  │        │ busy ←1                           │ grant←000, busy←0        │     │
 │  │        │                                   │ ptr  ←next(grant)  ★     │     │
 │  └────────┼───────────────────────────────────┼──────────────────────────┘     │
 │           │                                   │                                │
 │           ▼                                   ▼                                │
 │   ┌───────────────┐                   ┌──────────────────┐                     │
 │   │ grant  3 FF   │──────────────────▶│  ptr     2 FF    │──┐                  │
 │   │ busy   1 FF   │───┐               │  (con trỏ công   │  │                  │
 │   │ state  1 FF   │   │               │   bằng)          │  │                  │
 │   └───────────────┘   │               └──────────────────┘  │                  │
 │          │            │                                     │                  │
 │          │            │        hồi tiếp ptr → khối chọn     │                  │
 │          │            │  ◀──────────────────────────────────┘                  │
 │          ▼            ▼                                                        │
 └──────grant[2:0]────busy─────────────────────────────────────────────────────────┘
                                   ❌ ptr KHÔNG được đưa ra cổng
                                      (Charter mục 4 yêu cầu uo_out[4:3])
```

**Vòng hồi tiếp `ptr → khối chọn → grant → ptr`** là cấu trúc trung tâm của F07. Chính vòng
này tạo ra hành vi vòng tròn; cắt nó đi thì còn lại một trọng tài ưu tiên cố định.

## 2. Bảng ánh xạ cấu trúc RTL → phần cứng sinh ra

| Dòng RTL | Cấu trúc | Phần cứng thật (đọc netlist) |
|---|---|---|
| 10–11 | `typedef enum logic {IDLE, ACTIVE}` + `state_t state` | **1 FF** — `_58_ dfxtp_1 .Q(state)` |
| 13 | `logic [1:0] ptr` | **2 FF** — `_63_ .Q(\ptr[0])`, `_64_ .Q(\ptr[1])` |
| 6 | `output logic [2:0] grant` (gán trong `always_ff`) | **3 FF** — `_59_ _60_ _61_`, `Q` nối **thẳng** ra cổng |
| 7 | `output logic busy` | **1 FF** — `_62_`, `Q` nối thẳng ra cổng |
| 14–15 | `selected_id`, `selected_grant` | `selected_grant`: logic tổ hợp. **`selected_id`: MÃ CHẾT** — không FF, không cell (xem §2.1) |
| 17–24 | `function onehot3` | **MÃ CHẾT** — không bao giờ được gọi |
| 26–47 | `always_comb` với `case (ptr)` | Ba bộ mã hoá ưu tiên + mux 3 chiều chọn bởi `ptr`. Trong netlist: `nor3b_1 ×3`, `o211ai_1 ×2`, `a21boi_0 ×2`, `a32oi_1`, `o2bb2ai_1`, `nor2_1 ×3`… |
| 50–54 | `if (!rst_n)` | **Reset đồng bộ** → cổng chèn trên đường `D` của cả 7 FF |
| 56–77 | `case (state)` | Mux next-state; `mux2i_1 ×3` là ứng viên rõ nhất |
| 64–65 | `ACTIVE`, `done=0`, **không gán gì** | **Mạch giữ** (mux hồi tiếp) — không phải latch |
| 67–72 | `case (grant)` để tiến `ptr` | Bộ giải mã 3→2 từ one-hot sang số thứ tự + 1 |
| 79–84 | `default` của `case (state)` | **Không sinh cell** — `state` 1 bit phủ hết 2 giá trị |

### 2.1 Mã chết trong RTL — xác nhận bằng netlist

`selected_id` (dòng 14) được gán ở 7 chỗ nhưng **không bao giờ được đọc**. Hàm `onehot3`
(dòng 17–24) không bao giờ được gọi. Bằng chứng netlist:

```
Number of public wires:      9      ← clk, rst_n, req[2:0]→1, done, grant→1, busy, state, ptr
Number of public wire bits:  13
```

Không có dây nào mang tên `selected_id`. Lệnh `opt_clean -purge` (synth.ys dòng 15) đã xoá.

**Tại sao vẫn nên dọn:** mã chết trong RTL là **nợ kỹ thuật**. Ai đọc `onehot3` sẽ tưởng
`selected_grant` được sinh qua hàm đó, trong khi thực tế nó được gán bằng hằng số
`3'b001`/`3'b010`/`3'b100` trực tiếp. Hai cách viết cho cùng kết quả, nhưng đọc nhầm dẫn
tới phân tích sai.

## 3. Khối con nào nằm trên đường tới hạn — **số THẬT**

`06_GDSII/sta/timing_report_max.txt`, đường xấu nhất (slack 8,46 ns MET):

```
  done ──▶ _53_ (o311a_1) ──▶ _54_ (mux2i_1) ──▶ _55_ (lpflow_isobufsrc_1) ──▶ _63_/D
  1.00 ns     +0.19 ns          +0.18 ns            +0.05 ns                  = 1.42 ns
  (input                                                                       ▲
   delay                                                                       │
   giả định)                                                          ★ _63_ = ptr[0]
```

| # | Instance | Cell | Delay | Khối con nào |
|---:|---|---|---:|---|
| 1 | `_53_` | `o311a_1` | 0,19 ns | Logic điều kiện `ACTIVE && done` |
| 2 | `_54_` | `mux2i_1` | 0,18 ns | Mux chọn `ptr` mới theo `case (grant)` |
| 3 | `_55_` | `lpflow_isobufsrc_1` | 0,05 ns | Cổng chèn **reset đồng bộ** |
| 4 | `_63_` | `dfxtp_1` | — | **FF `ptr[0]`** (endpoint) |

### 3.1 Phát hiện đáng chú ý nhất của F07

> **Đường tới hạn kết thúc ở `ptr[0]` — tức ở chính con trỏ công bằng.**

Đường thứ hai được báo cáo (slack cũng 8,46 ns) kết thúc ở `_64_` = `ptr[1]`, đi qua đúng
cùng cổng `_53_` rồi rẽ sang `_56_`/`_57_`. Hai đường chậm nhất của toàn thiết kế **đều là
đường cập nhật con trỏ**.

Điều này trả lời Charter mục 9 theo một cách mà chỉ đọc RTL không thấy được:

| Câu hỏi Charter mục 9 | Bằng chứng |
|---|---|
| *"phần logic nào bảo đảm tính chất không bỏ đói"* | Vòng `ptr → chọn xoay → grant → ptr`, cụ thể là `case (grant)` dòng 67–72 |
| *"nó tốn thêm bao nhiêu cell so với trọng tài ưu tiên cố định"* | ⬜ **chưa đo** — `f07_bad_fixed_priority` chưa được tổng hợp. Xem `tradeoff.md` §4. |
| *(hệ quả chưa được hỏi nhưng đo được)* | Nó tốn cả **đường tới hạn**: chính logic công bằng là đường chậm nhất, 1,42 ns |

Nói cách khác: **giá của công bằng phải trả bằng cả diện tích lẫn timing.** Trọng tài ưu
tiên cố định không có `ptr`, nên nó không có đường này — nó là một mạch tổ hợp thuần
(`f07_bad_fixed_priority.sv` chỉ có một `always_comb`, **không có `always_ff` nào**, không
có flip-flop nào).

### 3.2 Đọc con số 1,42 ns cho đúng

| Thành phần | Giá trị | Ghi chú |
|---|---:|---|
| `set_input_delay` **giả định** | 1,00 ns | Từ `design.sdc`, **không phải** của mạch |
| Logic thật (3 cell) | **0,42 ns** | Đây mới là đóng góp của F07 |
| Required (10,00 − 0,12 setup) | 9,88 ns | Chu kỳ 10 ns là **giả định** |
| **Slack** | **8,46 ns (MET)** | WNS/TNS = 0,00 / 0,00 |

70 % của "1,42 ns" là giả định của người ràng buộc. Không được diễn giải thành tần số.

## 4. Đối chiếu dự đoán với STA

| | |
|---|---|
| **Dự đoán từ RTL** | Đường dài nhất là khối chọn xoay: `req` → mã hoá ưu tiên 3 nhánh → mux theo `ptr` → `grant`. Lý do dự đoán: khối `always_comb` có ba tầng `if/else if/else if` lồng trong một `case` 3 nhánh. |
| **STA đo được** | Đường dài nhất là `done` → logic `ACTIVE&&done` → mux `ptr` → `ptr[0]`. Khối chọn xoay **không** nằm trên đường tới hạn. |
| **Lệch** | ✅ **Có lệch** — và lệch một cách có thể giải thích |

**Vì sao lệch — ba lý do, đều kiểm được từ netlist:**

1. **Chuỗi ưu tiên chỉ có 3 phần tử.** `if/else if/else if` trên 3 bit không sinh chuỗi sâu:
   `abc` gộp được thành các cổng phức hợp một tầng như `nor3b_1`, `o211ai_1`, `a32oi_1`.
   Ba tầng logic trong mã nguồn ≠ ba tầng cổng trong silicon.
2. **`done` có fanout 2 và đi thẳng vào một cổng phức hợp `o311a_1`** (4 đầu vào), rồi vào
   mux `ptr`. Đường này ngắn về số cell (3) nhưng mỗi cell **đắt**: 0,19 ns và 0,18 ns cho
   hai cổng đầu — cổng nhiều đầu vào có điện dung vào lớn hơn cổng hai đầu vào. *(Muốn so
   định lượng với một cổng đơn giản trong cùng thiết kế thì cần STA liệt kê thêm đường phụ;
   `sta/summary.txt` hiện chỉ báo đường tới hạn.)*
3. **Cell `lpflow_isobufsrc_1` chèn reset** được `abc` chọn cho đường này; nó rẻ (0,05 ns)
   nhưng vẫn là một tầng thêm.

> 📌 Bài học phương pháp: **đếm tầng `if/else` trong RTL không dự đoán được đường tới hạn.**
> `abc` ánh xạ lại toàn bộ ranh giới logic. Dự đoán từ RTL vẫn có ích — nó cho ta **giả
> thuyết để kiểm** — nhưng khi lệch thì **tin STA**, rồi quay lại netlist tìm lý do. Đó
> chính là việc vừa làm ở ba gạch đầu dòng trên.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
