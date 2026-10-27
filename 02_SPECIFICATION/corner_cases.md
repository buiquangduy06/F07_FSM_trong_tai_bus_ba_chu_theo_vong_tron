# F07 · Ca biên và ca góc (Corner Cases)

> Đọc trực tiếp từ `05_VERIFICATION/testbench/f07_tb.sv`,
> `05_VERIFICATION/testbench/properties.sv` và
> `05_VERIFICATION/golden_model/reference_model.py`.
>
> ⚠️ Mô phỏng dừng ở `$fatal` tại dòng 72, thời điểm 156. Cột "đã chạy?" dưới đây phân biệt
> rõ ca **đã chạy và PASS** với ca **chưa chạy tới**. Xem `05_VERIFICATION/known_issues.md`.

---

## 1. Ca bắt buộc của Charter mục 8

| Ca (Charter) | Lý do kỹ thuật — nó bắt lỗi gì | TB có? | Đã chạy? |
|---|---|---|:---:|
| **Một khối xin** | Ca cơ bản nhất. Bắt lỗi mạch chọn hoàn toàn hỏng. **Không** phát hiện được lỗi công bằng — một trọng tài ưu tiên cố định cũng qua ca này. | ✅ dòng 66–68 | ✅ PASS (t=136) |
| **Hai khối xin** | Bắt lỗi chọn sai thứ tự quét trong một bước. Vẫn **chưa** đủ để lộ round-robin: với hai khối, ưu tiên cố định và round-robin có thể cho cùng kết quả ở lượt đầu. | ⚠️ **chỉ gián tiếp** — dòng 36 đặt `req=3'b111`, không có ca hai khối riêng | — |
| **Ba khối xin liên tục (kiểm luân phiên)** | **Ca quyết định.** Chỉ ca này phân biệt round-robin với ưu tiên cố định: ưu tiên cố định sẽ cho `001, 001, 001…`, round-robin cho `001, 010, 100, 001…` | ✅ dòng 36–54 | ✅ **PASS** (t=36…96) |
| **Không khối nào xin** | Bắt lỗi gán mặc định thiếu trong `always_comb` (suy ra latch) và lỗi `busy` dính mức 1. | ✅ dòng 32–33 | ✅ PASS (t=26) |

> **Charter mục 10 cảnh báo đúng chỗ:** *"Test một và hai khối xin rồi kết luận đúng. Ca ba
> khối xin liên tục mới lộ được luân phiên."* Testbench của gói này làm đúng — bốn assertion
> ở dòng 39, 44, 49, 54 kiểm chuỗi `M0 → M1 → M2 → M0` trên RTL thật, và **tất cả đều đã
> chạy PASS trước khi mô phỏng dừng**. Đây là phần bằng chứng có giá trị nhất của F07 và nó
> **không bị mất** vì lỗi ở dòng 72.

### 1.1 Vì sao ca "ba khối xin" phải **liên tục**, không phải "ba khối xin một lần"

```
   Nếu chỉ xin MỘT lượt:        req=111 → grant=001.  Xong.
                                 → Ưu tiên cố định cũng cho 001. KHÔNG PHÂN BIỆT ĐƯỢC.

   Phải xin LIÊN TỤC qua nhiều giao dịch:
        giao dịch 1: 001      giao dịch 2: 010      giao dịch 3: 100      giao dịch 4: 001
        ▲ ưu tiên cố định     ▲ ưu tiên cố định     ▲ ưu tiên cố định     ▲ vòng khép kín
          cũng cho 001          sẽ cho 001 → LỘ      sẽ cho 001 → LỘ        chứng minh xoay
```

Assertion ở **dòng 44** (`expected M1 second`) là assertion đầu tiên mà một trọng tài ưu
tiên cố định sẽ FAIL. Đó là ca đắt giá nhất trong cả testbench.

## 2. Ca tự xây dựng đã có

| Ca | Ở đâu | Lý do kỹ thuật | Đã chạy? |
|---|---|---|:---:|
| **Quyền không bị cướp** (`req` đổi lúc đang `ACTIVE`) | TB dòng 56–59 | **Ca biên quan trọng.** Bắt lỗi trạng thái `ACTIVE` đọc `req`. Nếu `grant` được tính lại mỗi chu kỳ, khối đang lái bus sẽ bị cắt giữa chừng ⟹ hỏng dữ liệu. | ✅ PASS (t=106) |
| **One-hot tại mọi lần cấp quyền** | TB dòng 40, 45, 50 + `properties.sv` dòng 3 | INV-1 — trả lời Charter mục 2 câu 3. | ✅ PASS ×3 |
| **Vòng khép kín** (wrap `ptr: 2 → 0`) | TB dòng 52–54 | Ca biên của số học modulo. Bắt lỗi `ptr <= ptr+1` không wrap (`ptr` lên 3 rồi kẹt). | ✅ PASS (t=96) |
| **Phục hồi sau reset giữa chừng** | TB dòng 74–80 | Bắt lỗi reset không phủ hết `ptr`. | ❌ **CHƯA CHẠY TỚI** |
| **Chọn khi `ptr` trỏ vào khối không xin** | Python `test_priority_scan()` dòng 49–55 | `ptr=1`, `req=101` ⟹ phải bỏ qua M1, chọn M2, rồi `ptr ← 0`. Ép nhánh quét vòng. | ✅ PASS (Python) |
| **Ổn định của grant** | Python `test_grant_stability()` dòng 73–78 | Cùng ý với TB dòng 56–59, ở mô hình độc lập. | ✅ PASS (Python) |

## 3. Phân loại ca theo tiêu chí kỹ thuật riêng của F07

F07 có **ba** trục độc lập. Một ma trận phủ nghiêm túc phải là tích của cả ba:

**Trục A — số khối cùng xin:** `0 · 1 · 2 · 3`
**Trục B — vị trí `ptr` so với khối xin:** `ptr trỏ đúng khối xin` · `ptr trỏ khối không xin (phải quét vòng)` · `ptr trỏ khối không xin, phải quét 2 bước`
**Trục C — nhánh FSM:** `IDLE giữ` · `IDLE → ACTIVE` · `ACTIVE giữ` · `ACTIVE → IDLE`

### Ma trận phủ thật sự đo được

| Nhánh / tình huống | Ca nào phủ | Trạng thái |
|---|---|---|
| `IDLE` giữ nguyên (`req=000`) | TB dòng 32–33 | ✅ |
| `IDLE → ACTIVE` | TB dòng 38–39 và 5 lần khác | ✅ |
| `ACTIVE` giữ nguyên (`done=0`) | TB dòng 58–59 | ✅ |
| `ACTIVE → IDLE` (`done=1`) | `complete()` ×5 | ✅ |
| `ptr=0` chọn M0 | TB dòng 39 | ✅ |
| `ptr=1` chọn M1 | TB dòng 44 | ✅ |
| `ptr=2` chọn M2 | TB dòng 49 | ✅ |
| **`ptr=1` phải quét vòng tới M2** | TB dòng 68 (`req=100`, `ptr=1`) | ✅ |
| **`ptr=0` phải quét vòng 2 bước tới M2** | TB dòng 68 sau `complete()` — chính là tình huống gây FATAL ở t=155 | ⚠️ đã xảy ra nhưng **bị hiểu nhầm là lỗi** |
| Đúng **hai** khối xin | — | ❌ **THIẾU** |
| Cấp lại liên tiếp (back-to-back) | — | ❌ **THIẾU** (là nội dung của lỗi — xem `known_issues.md` §7.2) |
| `done=1` khi đang `IDLE` | — | ❌ **THIẾU** |
| `ptr = 3` (bất hợp lệ) | — | ⬛ **không thể phủ bằng kích thích** — xem `fsm.md` §6.2 |
| Phục hồi sau reset | TB dòng 74–80 | ❌ **chưa chạy tới** |

### 3.1 Ba ca **còn thiếu** cần bổ sung (có lý do)

| Ca đề xuất | Vì sao cần | Kích thích |
|---|---|---|
| **CA-BS-1 · Đúng hai khối xin, `ptr` trỏ vào khối thứ ba** | Trục A hiện chỉ có `0`, `1`, `3`. Với `ptr=0`, `req=110`: phải chọn M1 (bỏ qua M0 không xin, chọn khối đầu tiên trong `scan` có `req`). Đây là ca duy nhất ép **chính xác một bước quét vòng** trong khi vẫn còn khối khác xin — phân biệt "quét tới khối xin đầu tiên" với "quét tới `ptr+1` máy móc". | `ptr=0`, `req=3'b110` ⟹ kỳ vọng `grant=010` |
| **CA-BS-2 · Cấp lại liên tiếp (back-to-back grant)** | Hành vi này **đã xảy ra** ở t=155 và không ca nào định nghĩa kỳ vọng cho nó — nên testbench hiểu nhầm thành lỗi. Đây là ca về **thông lượng bus**: nếu trọng tài chèn một chu kỳ nghỉ bắt buộc, thông lượng giảm 33 %. | `req=100` giữ nguyên qua `complete()` ⟹ kỳ vọng `grant=100` ngay chu kỳ kế, `busy=1` |
| **CA-BS-3 · `done` phát khi bus đang rảnh** | Ca **biên về hợp đồng giao diện**. Nếu một khối chủ hỏng và phát `done` sai lúc, trọng tài có bị đẩy vào trạng thái lạ không? RTL bỏ qua (nhánh `IDLE` không đọc `done`) — nhưng điều đó **chưa được kiểm**, và đang là hành vi ngầm định chứ không phải đặc tả. | `req=0`, `done=1` trong 3 chu kỳ ⟹ kỳ vọng `grant=000`, `busy=0`, `ptr` không đổi |

## 4. Ca **KHÔNG áp dụng** cho F07 — và vì sao

| Ca thường gặp | Vì sao không áp dụng | Bằng chứng |
|---|---|---|
| **Ưu tiên động / có trọng số** | Charter mục 3: *"Ngoài phạm vi. Ưu tiên động (đó là J10)"*. F07 có ưu tiên **xoay cố định**, không có khái niệm trọng số. | Charter mục 3 |
| **Nhiều bus** | Charter mục 3 liệt vào ngoài phạm vi. Một `grant` one-hot ⟹ đúng một bus. | Charter mục 3 |
| **Chia tách giao dịch** (split transaction) | Ngoài phạm vi. F07 giữ quyền liên tục tới `done`; không có khái niệm tạm nhả rồi lấy lại. | Charter mục 3 |
| **Cướp quyền** (preemption) | **Trái đặc tả**, không phải ngoài phạm vi. `functional_spec.md` §2.2 chốt quyền không bị cướp, và TB dòng 56–59 kiểm điều đó. | `functional_spec.md` §2.2 |
| Tràn số / bão hoà | `ptr` chỉ nhận 3 giá trị qua phép gán hằng, không có phép cộng nào. | `fsm.md` §6.2 |
| Ca timing/glitch | Mô phỏng zero-delay. Hơn nữa `grant` là **đầu ra đăng ký** (Moore) nên về nguyên tắc không có glitch. | `fsm.md` §7 |
| Đồng bộ hoá `req` từ domain khác | Ngoài ranh giới khối — tầng ngoài lo. | `interface.md` §4 |

## 5. Ca phải bổ sung khi chuyển sang gate-level / post-layout

| Lớp | Ca mới | Vì sao chỉ xuất hiện ở lớp đó |
|---|---|---|
| **L4 — gate-level** | Chạy lại toàn bộ ca trên `06_GDSII/synthesis/netlist.v` | Chứng minh tương đương RTL ↔ netlist. **Cần làm sau khi vá testbench** — chạy netlist với một testbench sai thì vô nghĩa. |
| **L4** | **INV-1 (one-hot) trên netlist** | Ở RTL, `grant` được gán từ **hằng số** one-hot (`3'b001`…), nên one-hot gần như hiển nhiên. Sau tổng hợp, ba bit `grant` là ba FF **độc lập** (netlist `_59_ _60_ _61_`); một lỗi ánh xạ có thể làm hai bit cùng lên. Chỉ mô phỏng gate-level mới bắt được. |
| **L4** | X-propagation sau reset | Reset **đồng bộ** + `dfxtp_1` không có chân reset ⟹ trước cạnh clock đầu tiên, cả 7 FF ở `X` thật. Cần kiểm `grant` không lan `X` ra bus. |
| **L4** | Ép `ptr = 3` bằng `force` rồi kiểm tự phục hồi | Trạng thái bất hợp lệ **không thể** tạo bằng kích thích ở cổng vào (`fsm.md` §6.2). Chỉ ép được ở mức netlist/RTL bằng `force`, và đây là cách duy nhất kiểm nhánh `default` của `case (ptr)`. |
| **L5 — post-layout + SDF** | Setup/hold trên đường `done → ptr[0]` | Đây là **đường tới hạn thật** đo được (`sta/summary.txt`: `done → _63_/D`, 1,42 ns). Sau routing nó sẽ dài hơn. |
| **L5** | Độ rộng xung `busy` khi giao dịch dài 1 chu kỳ | Hiện `busy` lên 1 chu kỳ tối thiểu. Sau routing phải kiểm tầng nhận bắt kịp. |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
