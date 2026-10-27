# F07 · Sự cố đã biết và phán xử (Known Issues)

## Trạng thái: ✅ ĐÃ ÁP DỤNG (2026-09-24)

Bản vá **phương án B (§7.2)** và bản vá mô hình chuẩn **(§7.3)** đã được áp dụng. Nhật ký
chi tiết: [`08_ORIGINAL_SOURCE/PATCHLOG.md`](../08_ORIGINAL_SOURCE/PATCHLOG.md).

| Bản vá | Nội dung | Trạng thái |
|---|---|---|
| §7.2 (phương án B) | Tách ca "single requester" thành hai ca: cấp lại liên tiếp, rồi hạ `req` mới kiểm nhả bus | ✅ đã áp dụng |
| §7.3 | `test_back_to_back_regrant()` trong mô hình chuẩn Python | ✅ đã áp dụng, **mở rộng** thêm hai bước cuối — xem PATCHLOG §2 P-2 |
| §7.1 (phương án A) | — | ❌ không dùng (làm PASS nhưng vứt bỏ hành vi vừa phát hiện) |
| §7.4 (khử cảnh báo `sorry:`) | — | ❌ **cố ý không làm**, đúng khuyến nghị của chính §7.4 |

**RTL giữ nguyên tuyệt đối** — phán xử §2 vẫn đứng vững: DUT đúng, testbench sai.

**Kết quả xác minh bằng công cụ thật (2026-09-24):**

| Bước | Trước khi vá | Sau khi vá |
|---|---|---|
| `python3 reference_model.py` | PASS (5 ca, có điểm mù §5) | **PASS** — 6 ca, mã thoát 0 |
| `iverilog -g2012` | PASS, 9 cảnh báo `sorry:` | **PASS**, vẫn 9 cảnh báo `sorry:`, 0 lỗi |
| `vvp sim.vvp` | **`$fatal` tại t=156** (dòng 72) | **PASS** — `F07 TB completed`, `$finish` tại t=196 |
| `yosys` (sky130hd) | 36 cell / 7 FF / 327,8144 µm² | **36 cell / 7 FF / 327,8144 µm²** (không đổi) |

Ca "phục hồi sau reset" ở §6 (trước đây ⬜ **chưa chạy tới**) nay **đã chạy và PASS**.

Các việc §9 số 5, 6, 7 (INV-2/4/5, cổng `uo_out[4:3]`, timeout cho `done`) **vẫn còn mở** —
xem PATCHLOG §5.

Phần chẩn đoán bên dưới **giữ nguyên** làm tài liệu dạy học; nhãn "⚠️ CHƯA ÁP DỤNG" ở §7
nay phải đọc là *đã áp dụng (phương án B)*.

---

**Trạng thái mô phỏng RTL (trước khi vá): `RAN_WITH_ISSUES`** — biên dịch thành công, chạy được 156 đơn vị
thời gian, rồi dừng ở một `$fatal`.

---

## 1. Thông báo lỗi — trích nguyên văn

### 1.1 `05_VERIFICATION/simulation.log` (toàn bộ file)

```
FATAL: /…/runs/F07/work/f07_tb.sv:72: single requester completion failed
       Time: 156  Scope: f07_tb
```

### 1.2 `05_VERIFICATION/iverilog_compile.log` (9 dòng, tất cả cùng một loại)

```
/…/f07_bad_fixed_priority.sv:8: sorry: constant selects in always_* processes are not
                                currently supported (all bits will be included).
   (×3, đều ở dòng 8)
/…/f07_rr_arbiter.sv:26: sorry: constant selects in always_* processes are not
                         currently supported (all bits will be included).
   (×6, đều ở dòng 26)
```

### 1.3 Tách bạch hai thông báo trước khi phán xử

| | Log biên dịch (§1.2) | Log mô phỏng (§1.1) |
|---|---|---|
| Mức | **Cảnh báo** (`sorry:`) | **Lỗi chí mạng** (`$fatal`) |
| Có chặn biên dịch không? | ❌ Không — chương trình vẫn chạy tới t=156 | ✅ Dừng mô phỏng |
| Có phải nguyên nhân của §1.1 không? | ❌ **KHÔNG** — chứng minh ở §3 | — |

Đây là chỗ dễ kết luận nhầm nhất, nên phải xử lý riêng.

---

## 2. Phán xử: **LỖI NẰM Ở TESTBENCH**

| Khả năng | Phán xử | Lý do |
|---|:---:|---|
| Lỗi trong **DUT** (`f07_rr_arbiter.sv`) | ❌ **Không** | DUT hành xử **đúng đặc tả** tại thời điểm 156 — chứng minh ở §4 |
| Lỗi trong **mô hình chuẩn** (`reference_model.py`) | ❌ **Không** | Mô hình chuẩn PASS cả 5 ca; nó **nhất quán** với DUT ở tình huống này (§5) |
| Lỗi trong **testbench** (`f07_tb.sv`) | ✅ **ĐÚNG — đây là lỗi** | Assertion dòng 72 kỳ vọng sai; nó quên hạ `req` trước khi kiểm (§4) |
| **Giới hạn công cụ** (Icarus Verilog) | ⚠️ Có, nhưng **không liên quan** | Cảnh báo `sorry:` là thật nhưng vô hại (§3) |

---

## 3. Vì sao cảnh báo `sorry: constant selects` KHÔNG phải nguyên nhân

Dòng 26 của `f07_rr_arbiter.sv` là dòng mở `always_comb`:

```systemverilog
26:    always_comb begin
27:        selected_id    = 2'd0;
...
32:            if      (req[0]) begin selected_id=2'd0; selected_grant=3'b001; end
33:            else if (req[1]) begin …
34:            else if (req[2]) begin …
```

Icarus Verilog 12.0 chưa hỗ trợ đưa **một bit cụ thể** (`req[0]`, `req[1]`, `req[2]`) vào
danh sách nhạy cảm ngầm của `always_*`, nên nó **đưa toàn bộ `req`** vào — đúng như câu
thông báo nói: *"all bits will be included"*.

**Hệ quả:** danh sách nhạy cảm **rộng hơn** cần thiết. Khối tổ hợp được đánh giá lại nhiều
lần hơn mức tối thiểu.

**Hệ quả lên đúng/sai:** **KHÔNG CÓ.** Lý do:

1. Khối này **vốn đã đọc cả ba bit** `req[0]`, `req[1]`, `req[2]`. Danh sách nhạy cảm đúng
   đã phải là toàn bộ `req`. Công cụ "mở rộng" tới đúng cái mà lẽ ra nó phải có.
2. Khối bắt đầu bằng hai lệnh gán mặc định vô điều kiện (dòng 27–28), nên nó **không giữ
   trạng thái** — đánh giá lại bao nhiêu lần cũng cho cùng kết quả.
3. Bằng chứng trực tiếp: mô phỏng **chạy đúng** qua bốn assertion round-robin ở dòng 39,
   44, 49, 54 — tất cả đều phụ thuộc chính khối `always_comb` này. Nếu khối này sai, các
   assertion đó đã FAIL từ thời điểm 36, không phải 156.

> **Giá trị dạy học riêng của cảnh báo này:** `sorry:` trong Icarus là *"tôi làm được, nhưng
> không đúng cách tối ưu"*, khác hẳn `error:`. Sinh viên đọc log rất hay dừng ở dòng cảnh
> báo đầu tiên và kết luận sai nguyên nhân. Quy tắc: **đọc dòng có `$fatal` / `error`
> trước, cảnh báo sau.**

---

## 4. Vì sao đây là lỗi testbench — lập luận từ mã, theo từng chu kỳ

### 4.1 Đoạn mã gây lỗi

```systemverilog
65:        // Single requester.
66:        req=3'b100;
67:        tick();
68:        assert(grant==3'b100) else $fatal(1,"single requester failed");
69:
70:        complete();              // done=1; tick(); done=0;
71:        tick();
72:        assert(grant==3'b000) else $fatal(1,"single requester completion failed");
```

**`req` được đặt bằng `3'b100` ở dòng 66 và KHÔNG BAO GIỜ được hạ xuống** trước khi kiểm
ở dòng 72.

### 4.2 Truy vết từng cạnh clock tới đúng thời điểm 156

Clock chu kỳ 10, cạnh lên tại `t = 5, 15, 25, …`; `tick()` = `@(posedge clk); #1`.

| Cạnh | t | Trạng thái vào | `req` | `done` | Hành động của DUT | `grant` sau | `ptr` sau |
|---:|---:|---|:---:|:---:|---|:---:|:---:|
| 14 | 135 | `IDLE`, `ptr=1` | `100` | 0 | `scan(1) = 1,2,0` → `req[1]=0`, `req[2]=1` ⟹ chọn M2 | `100` | 1 |
| — | 136 | — | `100` | **1** | TB gọi `complete()` | — | — |
| 15 | 145 | `ACTIVE` | `100` | 1 | `done` ⟹ nhả bus; `grant=100` ⟹ `ptr ← 0` | `000` | **0** |
| — | 146 | — | `100` | 0 | `complete()` hạ `done` | — | — |
| 16 | **155** | `IDLE`, `ptr=0` | **`100`** | 0 | `scan(0) = 0,1,2` → `req[0]=0`, `req[1]=0`, **`req[2]=1`** ⟹ **cấp lại cho M2** | **`100`** | 0 |
| — | **156** | — | — | — | TB kiểm `assert(grant==3'b000)` ⟹ **`100 ≠ 000` ⟹ `$fatal`** | — | — |

Thời điểm **156** trong bảng khớp **chính xác** với `Time: 156` trong `simulation.log`.
Đây là bằng chứng rằng cách truy vết này đúng, không phải suy đoán.

### 4.3 DUT làm đúng hay sai?

**Đúng.** Theo `02_SPECIFICATION/functional_spec.md` §2.1: *"Khi bus rảnh, trọng tài cấp
quyền cho khối đầu tiên trong `scan(p)` có `req` bằng 1."* Tại cạnh 16, bus rảnh và
`req[2]=1`. **Không cấp quyền mới là sai.**

Hơn nữa, cấp lại ngay (back-to-back grant) là hành vi **mong muốn** của một trọng tài bus:
nếu chỉ có một khối xin, không có lý do gì để bus nằm không một chu kỳ. Một trọng tài chèn
chu kỳ nghỉ bắt buộc giữa hai giao dịch sẽ làm giảm thông lượng bus 33 % mà không đổi lấy gì.

### 4.4 Vì sao assertion tương tự ở dòng 63 lại PASS?

```systemverilog
56:        // Grant must remain stable even if req changes while ACTIVE.
57:        req=3'b000;        ← ★ CHỖ KHÁC BIỆT DUY NHẤT
58:        tick();
59:        assert(grant==3'b001 && busy) else $fatal(1,"active grant changed unexpectedly");
60:
61:        complete();
62:        tick();
63:        assert(grant==3'b000 && !busy) else $fatal(1,"completion failed");   ← PASS
```

Dòng 63 và dòng 72 kiểm **cùng một điều**, viết gần **giống hệt nhau**. Dòng 63 PASS chỉ vì
ở dòng 57 `req` đã được hạ về `000` (cho một mục đích khác — kiểm tính ổn định của grant).
Dòng 72 FAIL vì `req` vẫn còn `100`.

⟹ **Dòng 63 PASS một cách tình cờ.** Đây mới là điều đáng lo về chất lượng testbench: một
assertion đúng nhờ may mắn về thứ tự lệnh, chứ không nhờ được thiết kế.

---

## 5. Mô hình chuẩn Python có sai không?

**Không, nhưng nó cũng không bắt được lỗi này** — và lý do rất đáng đọc.

```python
def test_single_request():
    m=RoundRobinArbiter()
    for i in range(3):
        m.ptr=i
        g,_,_=m.step(1<<((i+1)%3))
        assert g==(1<<((i+1)%3))
        m.step(0, done=True)      # ← ★ truyền req=0 khi hoàn tất
```

Mô hình Python có **đúng cùng một điểm mù**: nó cũng truyền `req = 0` ở bước hoàn tất, nên
cũng không bao giờ kiểm tình huống "yêu cầu vẫn giữ khi giao dịch xong".

Nếu chạy mô hình Python đúng kịch bản của testbench:

```python
m = RoundRobinArbiter(); m.ptr = 1
m.step(0b100)              # → grant = 0b100, busy = True
m.step(0b100, done=True)   # → grant = 0,     busy = False,  ptr = 0
m.step(0b100)              # → grant = 0b100 (CẤP LẠI)  ← giống hệt DUT
```

⟹ **DUT và mô hình chuẩn nhất quán với nhau.** Chỉ testbench lệch khỏi cả hai.

> 👉 Đây là một bài học đắt giá về *diverse redundancy*: mô hình chuẩn độc lập chỉ bảo vệ ta
> khi nó **được chạy cùng kịch bản** với DUT. Ở đây mô hình Python và testbench SystemVerilog
> chạy **hai kịch bản khác nhau**, nên sự dư thừa không phát huy tác dụng. Gói hiện tại
> **không có** bộ so sánh tự động giữa hai mô hình (co-simulation / vector chung) — đó là
> khoảng trống phương pháp, không chỉ là một lỗi lập trình.

---

## 6. Phần nào của mô phỏng VẪN CÓ GIÁ TRỊ

`$fatal` ở thời điểm 156 **không** làm mất giá trị của phần trước đó. Mọi assertion chạy qua
đều đã thực sự được kiểm:

| Assertion | Dòng | t | Kiểm điều gì | Kết quả |
|---|---:|---:|---|:---:|
| `grant==000 && !busy` | 33 | 26 | Trạng thái rảnh sau reset | ✅ |
| `grant==001` | 39 | 36 | `ptr=0` ⟹ M0 thắng | ✅ |
| `$onehot0(grant)` | 40 | 36 | INV-1 | ✅ |
| `grant==010` | 44 | 56 | **Con trỏ đã tiến** ⟹ M1 | ✅ |
| `$onehot0(grant)` | 45 | 56 | INV-1 | ✅ |
| `grant==100` | 49 | 76 | Con trỏ tiến ⟹ M2 | ✅ |
| `$onehot0(grant)` | 50 | 76 | INV-1 | ✅ |
| `grant==001` | 54 | 96 | **Vòng tròn khép kín** — quay lại M0 | ✅ |
| `grant==001 && busy` | 59 | 106 | Quyền **không bị cướp** khi `req` đổi | ✅ |
| `grant==000 && !busy` | 63 | 126 | Nhả bus | ✅ (tình cờ — xem §4.4) |
| `grant==100` | 68 | 136 | Một khối xin, `ptr=1` | ✅ |
| `grant==000` | **72** | **156** | — | ❌ **FATAL** |
| `grant==0 && !busy` | 80 | — | Phục hồi sau reset | ⬜ **chưa chạy tới** |

**Kết luận về giá trị bằng chứng:** chuỗi phục vụ `M0 → M1 → M2 → M0` khi cả ba cùng xin
liên tục **đã được chứng minh trên RTL thật** (bốn assertion dòng 39–54). Đó chính là nội
dung Charter mục 9 và câu hỏi Charter mục 2 số 2. Bằng chứng này **hợp lệ**, mặc dù mô phỏng
không chạy hết. Điều **chưa** chứng minh được là **phục hồi sau reset** (dòng 74–80).

---

## 7. Bản vá tối thiểu đề xuất

> ⚠️ **BẢN VÁ NÀY CHƯA ĐƯỢC ÁP DỤNG.** RTL, testbench và mô hình chuẩn trong hồ sơ **giữ
> nguyên bản gốc của thầy**. Cần thầy duyệt trước khi sửa bất kỳ file nào.

### 7.1 Phương án A — sửa tối thiểu (1 dòng), giữ nguyên ý định của ca kiểm thử

```diff
--- a/05_VERIFICATION/testbench/f07_tb.sv
+++ b/05_VERIFICATION/testbench/f07_tb.sv
@@ -67,6 +67,7 @@
         assert(grant==3'b100) else $fatal(1,"single requester failed");
 
         complete();
+        req=3'b000;   // ha yeu cau truoc khi kiem nha bus, giong dong 57
         tick();
         assert(grant==3'b000) else $fatal(1,"single requester completion failed");
```

**Giải thích:** ca kiểm thử này muốn kiểm *"trọng tài có nhả bus khi `done` không"*. Muốn
kiểm điều đó một cách cô lập thì phải loại bỏ mọi lý do để trọng tài cấp quyền lại — tức
phải hạ `req`. Dòng 57 đã làm đúng như vậy cho ca trước đó; dòng này chỉ là **áp dụng nhất
quán** cùng một cách làm.

### 7.2 Phương án B — vá tốt hơn: biến lỗi thành một ca kiểm thử mới

Phương án A làm testbench PASS nhưng **vứt bỏ** một hành vi quan trọng vừa được phát hiện.
Tốt hơn là kiểm **cả hai**:

```diff
         complete();
+        // Ca 1: yeu cau VAN GIU -> trong tai phai cap lai NGAY (back-to-back grant)
+        tick();
+        assert(grant==3'b100 && busy)
+            else $fatal(1,"persistent request must be re-granted back-to-back");
+        assert($onehot0(grant)) else $fatal(1,"grant not one-hot");
+
+        // Ca 2: ha yeu cau -> bus moi thuc su ranh
+        complete();
+        req=3'b000;
         tick();
         assert(grant==3'b000) else $fatal(1,"single requester completion failed");
```

**Vì sao phương án B đáng chọn hơn:** nó biến một lỗi testbench thành **hai** ca kiểm thử
có giá trị — một ca về thông lượng (cấp lại liên tiếp), một ca về nhả bus. Hành vi
back-to-back grant hiện **chưa có ca nào** trong cả testbench lẫn mô hình Python.

### 7.3 Vá thêm cho mô hình chuẩn (tuỳ chọn, nhưng nên)

```diff
--- a/05_VERIFICATION/golden_model/reference_model.py
+++ b/05_VERIFICATION/golden_model/reference_model.py
@@
+def test_back_to_back_regrant():
+    m = RoundRobinArbiter(); m.ptr = 1
+    g,_,_ = m.step(0b100);            assert g == 0b100
+    m.step(0b100, done=True)          # hoan tat, ptr -> 0
+    g,b,_ = m.step(0b100)             # yeu cau VAN GIU
+    assert g == 0b100 and b           # phai cap lai ngay
```

Thêm ca này vào danh sách gọi trong `run()`. Nó lấp đúng điểm mù đã phân tích ở §5.

### 7.4 Khử cảnh báo `sorry:` (tuỳ chọn, thuần hình thức)

```diff
-    always_comb begin
+    always @(*) begin
```

hoặc viết danh sách nhạy cảm tường minh `always @(req or ptr)`. **Không khuyến nghị**:
`always_comb` cho ta kiểm tra ngữ nghĩa mạnh hơn (báo lỗi nếu suy ra latch), và cảnh báo
này vô hại. Đổi đi là **đánh đổi an toàn lấy log sạch** — nước đi sai.

---

## 8. Giá trị dạy học của lỗi này

Đây là một **bẫy kinh điển**, đáng giữ lại làm bài tập:

1. **Assertion đúng vì may mắn.** Dòng 63 và dòng 72 gần như giống hệt nhau; một cái PASS,
   một cái FAIL, chỉ vì một dòng gán `req` ở xa 15 dòng phía trên được viết vì **lý do khác**.
   Bài học: mỗi ca kiểm thử phải **tự thiết lập đầy đủ trạng thái đầu vào của nó**, không
   được dựa vào tàn dư của ca trước.

2. **Testbench cũng là mã, và cũng có lỗi.** Khi mô phỏng FAIL, phản xạ đầu tiên của sinh
   viên là sửa DUT. Ở đây sửa DUT sẽ **phá hỏng một mạch đang đúng** — và mạch bị phá theo
   hướng làm giảm thông lượng bus 33 %. Quy trình đúng: đọc đặc tả trước, truy vết từng chu
   kỳ, rồi mới quyết định ai sai.

3. **Sự dư thừa đa dạng chỉ có tác dụng khi chạy cùng kịch bản.** Mô hình Python và DUT ở
   đây **đồng ý với nhau**; chỉ testbench lệch. Nếu có một bộ so sánh tự động chạy cùng
   vector trên cả hai mô hình, lỗi đã lộ ra là "testbench kỳ vọng khác cả hai", thay vì
   "DUT FAIL".

4. **Đọc log đúng thứ tự.** 9 dòng cảnh báo `sorry:` đứng **trước** dòng `$fatal` trong thư
   mục log. Kết luận "Icarus không hỗ trợ cú pháp nên mạch chạy sai" là kết luận sai mà rất
   nhiều người sẽ rút ra. `sorry:` ≠ `error:`.

5. **`$fatal` không xoá sạch giá trị của những gì đã chạy.** Bằng chứng round-robin ở §6 vẫn
   dùng được để trả lời Charter mục 9. Biết phần nào còn giá trị, phần nào mất, là một kỹ
   năng đọc kết quả kiểm chứng.

---

## 9. Trạng thái và việc cần làm

| # | Việc | Ai | Trạng thái |
|---|---|---|---|
| 1 | Duyệt phán xử ở §2 | Giảng viên | ⬜ chờ |
| 2 | Áp dụng bản vá §7.2 (phương án B) | Sau khi duyệt | ⬜ **chưa áp dụng** |
| 3 | Chạy lại `01_run_sim.sh`, kiểm tới hết dòng 83 | — | ⬜ |
| 4 | Bổ sung ca back-to-back vào mô hình Python (§7.3) | — | ⬜ |
| 5 | Bổ sung INV-2, INV-4, INV-5 vào `properties.sv` | — | ⬜ |
| 6 | Quyết định về cổng `uo_out[4:3]` thiếu (xem `functional_spec.md`) | Giảng viên | ⬜ |
| 7 | Quyết định về lỗ hổng "không có timeout cho `done`" | Giảng viên | ⬜ |

> Nhắc lại: **RTL của thầy chưa bị sửa một dòng nào.** Mọi thay đổi ở §7 là đề xuất.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
