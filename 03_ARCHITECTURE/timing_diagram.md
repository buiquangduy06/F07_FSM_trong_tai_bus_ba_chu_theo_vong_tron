# F07 · Giản đồ thời gian (Timing Diagram)

> F07 là mạch **tuần tự** ⟹ dùng giản đồ dạng sóng theo chu kỳ clock.
>
> ⚠️ **Mô phỏng HÀNH VI (zero-delay).** Mọi tín hiệu đổi đúng tại cạnh clock; không có
> `t_ckq`, không có độ trễ cổng, không có glitch. L4 (gate-level) và L5 (SDF) ⬜ chưa chạy.

---

## 1. Giao dịch điển hình — tái dựng đúng lần chạy thật

Suy từng chu kỳ từ `05_VERIFICATION/testbench/f07_tb.sv`; clock chu kỳ 10, cạnh lên tại
`t = 5, 15, 25, …`; `tick()` = `@(posedge clk); #1`.

**Mốc kiểm chứng:** `simulation.log` ghi `$fatal` tại **Time: 156**. Bảng dưới đây cho
`$fatal` đúng tại t=156 (cạnh #16 + `#1`) — đó là bằng chứng rằng cách đọc này khớp lần chạy
thật, không phải tự vẽ.

### 1.1 Ba khối xin liên tục — phần chứng minh round-robin (cạnh #3 → #10)

```
 cạnh #     3     4     5     6     7     8     9    10
 t (ns)    25    35    45    55    65    75    85    95
          ─┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬──
 clk     ─┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘└──

 req      000 │←──────────── 111 (cả ba xin liên tục) ─────────────→
          ────┼──────────────────────────────────────────────────────

 done      0     0     1     0     1     0     1     0
                     ┌──┐        ┌──┐        ┌──┐
          ───────────┘  └────────┘  └────────┘  └───────────

 state    IDLE  ACT   IDLE  ACT   IDLE  ACT   IDLE  ACT
                ▲           ▲           ▲           ▲
 grant    000   001   000   010   000   100   000   001
                ▲           ▲           ▲           ▲
                M0          M1          M2          M0 ← VÒNG KHÉP KÍN

 busy      0     1     0     1     0     1     0     1

 ptr       0     0     1     1     2     2     0     0
                       ▲           ▲           ▲
                  ptr←1 sau     ptr←2 sau    ptr←0 sau
                  phục vụ M0    phục vụ M1   phục vụ M2

 assert          ✅          ✅          ✅          ✅
 (dòng)         39,40       44,45       49,50        54
```

**Đây là toàn bộ bằng chứng round-robin, và nó ĐÃ CHẠY PASS trên RTL thật.** Bốn assertion
ở dòng 39, 44, 49, 54 chứng minh chuỗi phục vụ `M0 → M1 → M2 → M0` khi cả ba xin liên tục.
Một trọng tài ưu tiên cố định sẽ FAIL ngay ở assertion dòng 44.

### 1.2 Quyền không bị cướp và nhả bus (cạnh #10 → #13)

```
 cạnh #    10    11    12    13
 t (ns)    95   105   115   125
          ─┬─────┬─────┬─────┬──
 clk     ─┘└────┘└────┘└────┘└──

 req      111 │← 000 (TẤT CẢ rút yêu cầu giữa lúc M0 đang lái bus) →
          ────┼────────────────────

 done      0     0     1     0
                     ┌──┐
          ───────────┘  └────────

 state    ACT   ACT   IDLE  IDLE
 grant    001   001   000   000
                 ▲
           ★ grant KHÔNG ĐỔI dù req đã về 000
             → quyền không bị cướp (INV-3)

 busy      1     1     0     0
 ptr       0     0     1     1

 assert          ✅          ✅
 (dòng)          59          63
```

Cạnh #11 là ca biên quan trọng: `req` đã bằng `000` nhưng `grant` **vẫn** bằng `001` vì
trạng thái `ACTIVE` không đọc `req` (xem `control.md` §3).

### 1.3 Ca "một khối xin" và thời điểm `$fatal` (cạnh #14 → #16)

```
 cạnh #    14    15    16
 t (ns)   135   145   155      156 ← $fatal
          ─┬─────┬─────┬────────┬──
 clk     ─┘└────┘└────┘└────────┘

 req      │←──────── 100 (M2 xin, KHÔNG BAO GIỜ được hạ) ────────→
          ─────────────────────────

 done      0     1     0
                ┌──┐
          ──────┘  └───────────────

 state    ACT   IDLE  ACT
 grant    100   000   100  ◀── ★ CẤP LẠI NGAY (back-to-back grant)
                       ▲
 busy      1     0     1   │
 ptr       1     0     0   │
                           │
 assert    ✅          ❌ FATAL: "single requester completion failed"
 (dòng)    68              72     — testbench kỳ vọng grant==000

                           └─ DUT ĐÚNG: bus rảnh + req[2]=1 ⟹ phải cấp quyền
```

**Phán xử:** DUT hành xử đúng đặc tả; testbench quên hạ `req` trước khi kiểm. Truy vết đầy
đủ và bản vá ở **`05_VERIFICATION/known_issues.md`** §4.

Chú ý cạnh #14: `ptr = 1` nhưng `req = 100` (chỉ M2 xin). Thứ tự quét `scan(1) = 1,2,0` bỏ
qua M1 (không xin) và chọn M2. Đây chính là ca "quét vòng" — nó **đã chạy và PASS**.

## 2. Độ trễ đầu vào → đầu ra

| Đường | Độ trễ | Bằng chứng trên waveform |
|---|---|---|
| `req` lên (bus rảnh) → `grant` | **1 chu kỳ** | cạnh #3 (`req=111` từ t=26) → cạnh #4 `grant=001` |
| `done` lên → `grant` về 000 | **1 chu kỳ** | `done=1` tại t=36 → cạnh #5 `grant=000` |
| `done` lên → `ptr` tiến | **1 chu kỳ**, cùng cạnh với nhả `grant` | cạnh #5: `ptr 0→1` |
| Giao dịch ngắn nhất | **2 chu kỳ** (1 cấp + 1 nhả) | cạnh #4 → #5 |
| Một vòng đầy đủ 3 khối | **6 chu kỳ** | cạnh #4 → #10 |
| Chờ xấu nhất của một khối | **2 giao dịch** = 4 chu kỳ (giao dịch ngắn nhất) | suy từ `ptr ← (i+1) mod 3` |
| Cấp lại liên tiếp | **1 chu kỳ nghỉ** giữa hai giao dịch | cạnh #15 (`grant=000`) → #16 (`grant=100`) |

> Chi tiết đáng chú ý ở hàng cuối: dù yêu cầu vẫn giữ, vẫn có **một chu kỳ bus rảnh** giữa
> hai giao dịch — vì FSM bắt buộc đi qua `IDLE`. Đó là cái giá của đầu ra đăng ký (Moore).
> Một thiết kế Mealy có thể cấp lại **không cần chu kỳ nghỉ**, đổi lại chịu glitch. Xem
> `tradeoff.md` §3.

## 3. Chứng minh câu hỏi Charter mục 2 bằng waveform

### 3.1 Câu 1 — *"round-robin hiện ra dưới dạng gì?"*

Hàng `ptr` trong §1.1 là câu trả lời trực quan: `0 → 1 → 2 → 0`, mỗi lần tiến **đúng vào
cạnh có `done = 1`**, không tiến ở bất kỳ cạnh nào khác. Con trỏ là **trạng thái**; thứ tự
quét là **hàm** của trạng thái đó.

⚠️ Hàng `ptr` trong waveform này là **tín hiệu nội bộ** (`dut.ptr`), không phải cổng ra —
Charter mục 4 yêu cầu `uo_out[4:3]` mà RTL không có. Xem cảnh báo ở `functional_spec.md`.

### 3.2 Câu 2 — *"bằng chứng nào chứng minh không khối nào bị bỏ đói?"*

Hàng `grant` ở §1.1: với `req` giữ `111` liên tục, chuỗi phục vụ là `M0, M1, M2, M0` — **mọi
khối đều được phục vụ trong 3 giao dịch liên tiếp**. Đây là bằng chứng thực nghiệm; chứng
minh hình thức (chặn trên 2 giao dịch) ở `functional_spec.md` §6.

Mô hình Python độc lập xác nhận chặt hơn với 9 giao dịch:
`served == [0,1,2,0,1,2,0,1,2]` — PASS (`python_reference_run.log`).

### 3.3 Câu 3 — *"chỉ một khối được cấp quyền — chứng minh bằng gì?"*

Ba tầng bằng chứng, độ mạnh tăng dần:

| Tầng | Bằng chứng | Trạng thái |
|---|---|---|
| Hành vi | `assert($onehot0(grant))` ×3 — TB dòng 40, 45, 50 | ✅ PASS |
| Cấu trúc RTL | `selected_grant` chỉ nhận **hằng số** one-hot hoặc `000`; không có phép OR nào giữa các bit | ✅ đọc được từ mã |
| Gate-level | 3 bit `grant` là 3 FF **độc lập** (`_59_ _60_ _61_`) — one-hot **không** được bảo đảm bởi cấu trúc | ⬜ **chưa kiểm** — cần L4 |

Tầng thứ ba là tầng quan trọng nhất và chưa có. Sau tổng hợp, không còn gì trong phần cứng
*bắt buộc* `grant` phải one-hot; nó one-hot chỉ vì logic điều khiển đúng.

## 4. Những gì giản đồ này **không** chứng minh

| Không chứng minh | Vì sao | Cần gì |
|---|---|---|
| Không có glitch trên `grant` | Zero-delay không sinh glitch. Về nguyên tắc Moore ⟹ không glitch, nhưng đó là lập luận, không phải đo. | L5 + SDF |
| `t_ckq` thật của `grant` | Waveform vẽ đổi tại đúng cạnh | L5 |
| Phục hồi sau reset giữa chừng | TB dòng 74–80 **chưa chạy tới** (dừng t=156) | vá testbench, chạy lại |
| Hành vi khi `ptr = 3` | Không tạo được bằng kích thích ở cổng vào | `force` ở L4 |
| Hành vi khi khối chủ không phát `done` | Không có ca nào; và RTL không có timeout | thêm ca + quyết định kiến trúc |
| Netlist tương đương RTL | Chưa mô phỏng gate-level | L4 |
| Tần số hoạt động | Chu kỳ 10 ns là giả định; chưa có ký sinh dây; một góc PVT | STA sau routing |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
