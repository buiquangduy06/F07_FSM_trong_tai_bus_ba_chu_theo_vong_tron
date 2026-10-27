# F07 · Đặc tả chức năng (Functional Spec)

> ## ⚠️ CẢNH BÁO ĐẦU FILE — RTL THIẾU CỔNG CHARTER MỤC 4 YÊU CẦU · **CHƯA THOẢ**
>
> Đối chiếu Charter mục 4 với danh sách cổng đọc từ `04_IMPLEMENTATION/rtl/f07_rr_arbiter.sv`:
>
> | Charter mục 4 chốt | Có trong RTL? | Ghi chú |
> |---|---|---|
> | `ui_in[2:0]` = yêu cầu | ✅ `req[2:0]` | khớp |
> | `uo_out[2:0]` = cấp quyền | ✅ `grant[2:0]` | khớp |
> | **`uo_out[4:3]` = chủ đang được ưu tiên** | ❌ **KHÔNG CÓ** | `ptr[1:0]` tồn tại **bên trong** (netlist dòng 239–248, hai FF `\ptr[0]`, `\ptr[1]`) nhưng **không được đưa ra cổng**. |
> | `uo_out[5]` = bus đang bận | ✅ `busy` | khớp |
> | *(không có trong Charter)* | ⚠️ **`done`** — cổng vào thứ tư | RTL **thêm** một tín hiệu bắt tay mà ngân sách chân của Charter (3 bit vào) **không cấp phát**. |
>
> **Hai sai lệch, hai mức nghiêm trọng khác nhau:**
>
> 1. **Thiếu `uo_out[4:3]` — CHƯA THOẢ, và làm mất bằng chứng.** Charter mục 2 câu 1 hỏi
>    *"round-robin hiện ra trong phần cứng dưới dạng gì — con trỏ quay hay ưu tiên xoay?"*.
>    Đưa `ptr` ra cổng chính là cách trả lời câu đó **bằng quan sát được từ ngoài**. Không
>    có cổng đó, muốn chứng minh phải thọc vào tín hiệu nội bộ (`dut.ptr`) — bằng chứng yếu
>    hơn hẳn, và **không dùng được ở mức gate-level** vì tên tín hiệu bị đổi.
> 2. **Thêm `done` — sai lệch có lý do kỹ thuật, nhưng phải được duyệt.** Không có `done`
>    thì trọng tài không biết giao dịch kết thúc lúc nào, và `busy` (mà Charter **có** yêu
>    cầu ở `uo_out[5]`) trở nên vô nghĩa. Nhiều khả năng Charter mục 4 viết thiếu chứ không
>    phải RTL viết thừa. **Ghi nhận, không tự sửa.**
>
> **Ngân sách chân thật sau khi sửa theo Charter:** 3 (`req`) + 1 (`done`) = 4 bit vào;
> 3 (`grant`) + 2 (`ptr`) + 1 (`busy`) = 6 bit ra ⟹ 10/24 chân. Vẫn thừa chỗ.
>
> **Kết luận: REQ-F07-002 CHƯA THOẢ.** Hồ sơ **không tự sửa RTL** (SPEC §0.2, §3).
>
> ---
>
> ### ⚠️ Cảnh báo thứ hai — mô phỏng KHÔNG PASS
>
> `05_VERIFICATION/simulation.log` dừng ở `$fatal` tại `f07_tb.sv:72`, thời điểm 156.
> Phán xử đầy đủ (lỗi ở DUT / mô hình chuẩn / testbench / công cụ) nằm ở
> **`05_VERIFICATION/known_issues.md`**. Tóm tắt: **lỗi ở TESTBENCH**, DUT hành xử đúng.
> Mọi khẳng định chức năng trong file này chỉ có giá trị tới thời điểm 156.

---

## 1. Bài toán: định nghĩa chính xác

Ba khối chủ (master) dùng chung một bus dữ liệu. Tại một thời điểm chỉ **một** khối được
quyền lái bus — nếu hai khối cùng lái, bus bị tranh chấp (contention): về điện là dòng
ngắn mạch, về logic là dữ liệu hỏng.

Trọng tài (arbiter) giải bài toán này. Nhưng "chỉ một khối được cấp quyền" mới là **một
nửa** đặc tả, và là nửa dễ. Nửa khó là **công bằng**: không khối nào bị bỏ đói (starvation)
khi cả ba cùng xin liên tục.

Một trọng tài **ưu tiên cố định** thoả nửa đầu và vi phạm nửa sau: nếu M0 xin liên tục thì
M1 và M2 **không bao giờ** được phục vụ. Phản ví dụ `f07_bad_fixed_priority.sv` trong gói
chính là mạch đó, và nó tồn tại để đặt cạnh so sánh.

**Round-robin** giải nửa sau bằng một ý tưởng: giữ một **con trỏ** chỉ ra ai được quét
trước; sau mỗi lần phục vụ, con trỏ tiến sang khối kế tiếp. Nhờ đó mỗi khối luôn tiến dần
lên đầu hàng đợi.

## 2. Đặc tả hành vi đúng (độc lập với hiện thực)

Ký hiệu: `req[2:0]` là vector yêu cầu; `p ∈ {0,1,2}` là con trỏ ưu tiên;
`scan(p)` là thứ tự quét `(p, (p+1) mod 3, (p+2) mod 3)`.

### 2.1 Quy tắc chọn

> **Khi bus rảnh, trọng tài cấp quyền cho khối đầu tiên trong `scan(p)` có `req` bằng 1.
> Nếu không khối nào xin, không cấp quyền cho ai.**

### 2.2 Quy tắc giữ và nhả

> **Khi đã cấp quyền cho khối `i`, quyền đó được giữ cho tới khi `done = 1`, bất kể `req`
> đổi thế nào. Khi `done = 1`: nhả quyền, và đặt `p ← (i+1) mod 3`.**

Hai chi tiết đáng gạch chân:

- Con trỏ tiến **sau khối được phục vụ thật**, không phải `p ← (p+1) mod 3`. Khác biệt này
  quan trọng: nếu `p = 0` mà M0 không xin, M2 được phục vụ, thì `p` phải nhảy tới **0**
  (=(2+1) mod 3), không phải tới 1. Chỉ cách làm này mới bảo đảm khối vừa được phục vụ
  **xuống cuối** hàng đợi.
- Quyền **không bị cướp** giữa chừng (non-preemptive). Đây là lý do `busy` tồn tại.

### 2.3 Bảng hành vi đầy đủ

| # | Điều kiện | `grant'` | `busy'` | `p'` |
|---|---|---|---|---|
| B1 | rảnh, `req = 000` | `000` | 0 | giữ |
| B2 | rảnh, tồn tại `i` đầu tiên trong `scan(p)` có `req[i]=1` | `onehot(i)` | 1 | giữ |
| B3 | bận, `done = 0` | giữ | 1 | giữ |
| B4 | bận, `done = 1`, đang phục vụ `i` | `000` | 0 | `(i+1) mod 3` |
| B5 | `rst_n = 0` | `000` | 0 | `0` |

### 2.4 Định nghĩa từng đầu ra

| Đầu ra | Định nghĩa |
|---|---|
| `grant[2:0]` | **One-hot hoặc toàn 0.** `grant[i]=1` ⟺ khối `i` đang giữ bus. |
| `busy` | `busy = 1 ⟺ grant ≠ 000`. **Dư thừa về thông tin** (suy được từ `grant`) nhưng tiện cho tầng ngoài và Charter mục 4 yêu cầu. |
| `uo_out[4:3]` = `p` | Con trỏ ưu tiên hiện tại. ❌ **RTL không xuất** — xem cảnh báo đầu file. |

### 2.5 Trạng thái sau reset và độ trễ

| Hạng mục | Giá trị | Bằng chứng RTL |
|---|---|---|
| Sau reset | `grant=000`, `busy=0`, `p=0`, FSM ở `IDLE` | dòng 50–54 |
| Độ trễ `req` → `grant` | **1 chu kỳ** (đầu ra đăng ký) | `grant <= selected_grant` dòng 58 |
| Độ trễ `done` → nhả bus | **1 chu kỳ** | dòng 73–74 |
| Độ trễ tối thiểu một giao dịch | **2 chu kỳ** (1 cấp + 1 nhả) | — |
| Thời gian chờ xấu nhất của một khối | **2 giao dịch** của hai khối kia | suy từ quy tắc `p ← (i+1) mod 3` |

## 3. Ràng buộc cấu trúc bắt buộc

Tên đề chốt **"theo vòng tròn"** (round-robin), nên RTL **bắt buộc** mô tả tường minh cơ
chế vòng tròn, không được là ưu tiên cố định trá hình.

| RB | Nội dung | RTL hiện có |
|---|---|---|
| RB-1 | Phải có **trạng thái lưu thứ tự ưu tiên** — không thể suy round-robin từ mạch tổ hợp thuần | ✅ `logic [1:0] ptr` (dòng 13), hiện thành **2 FF** thật trong netlist (dòng 239–248) |
| RB-2 | Thứ tự quét phải **xoay** theo con trỏ | ✅ `case (ptr)` với ba thứ tự quét khác nhau (dòng 30–46) |
| RB-3 | Con trỏ phải tiến theo **khối được phục vụ**, không theo `ptr+1` máy móc | ✅ `case (grant) 3'b001: ptr<=1; 3'b010: ptr<=2; 3'b100: ptr<=0;` (dòng 67–72) |
| RB-4 | Phải là **FSM**, không phải logic tổ hợp | ✅ `typedef enum logic {IDLE, ACTIVE}` + `case (state)` |
| RB-5 | Chỉ một khối được cấp quyền cùng lúc | ✅ `selected_grant` luôn là hằng one-hot hoặc `000` — xem INV-1 |

## 4. Tính chất bất biến (invariants)

| ID | Phát biểu | Dạng kiểm |
|---|---|---|
| **INV-1** | `grant` luôn one-hot **hoặc** `000` — không bao giờ có 2 bit cùng bằng 1. | `assert property (@(posedge clk) $onehot0(grant));` — đã có ở `testbench/properties.sv` dòng 3 và ở `f07_tb.sv` dòng 40, 45, 50 |
| **INV-2** | `busy = (grant ≠ 000)` tại mọi thời điểm. | `assert property (@(posedge clk) busy == (grant != 3'b000));` ❌ **chưa có** |
| **INV-3** | Khi `busy = 1` và `done = 0`, `grant` **không đổi** ở chu kỳ sau. | `properties.sv` dòng 4–5; ở `f07_tb.sv` kiểm bằng tay dòng 59 |
| **INV-4** | `grant[i] = 1` ⟹ `req[i]` đã bằng 1 **tại lúc cấp quyền**. | cần lưu `$past` — ❌ chưa có |
| **INV-5** | `ptr ∈ {0,1,2}` — giá trị `3` không bao giờ đạt tới. | `assert property (@(posedge clk) dut.ptr != 2'd3);` ❌ chưa có. Xem `fsm.md` §6. |
| **INV-6** | **Không bỏ đói:** nếu `req[i]` giữ 1 liên tục, thì trong **≤ 2 giao dịch hoàn tất** khối `i` sẽ được cấp quyền. | Chứng minh ở §6 — đây là tính chất **liveness**, không kiểm được bằng một assertion đơn chu kỳ. |
| **INV-7** | Sau `rst_n=0` một cạnh: `grant=000`, `busy=0`, `ptr=0`. | `f07_tb.sv` dòng 74–80 — **chưa chạy tới** (sim dừng ở dòng 72). |

## 5. Điều kiện biên và hành vi không xác định

| Ca | Đặc tả yêu cầu | RTL làm gì | Đánh giá |
|---|---|---|---|
| `req = 000` khi rảnh | Không cấp quyền, `busy=0` | `selected_grant` giữ giá trị khởi tạo `3'b000`, `busy <= 0` | ✅ kiểm ở TB dòng 33 |
| `req` đổi **giữa lúc bận** | Không ảnh hưởng — quyền không bị cướp | `state=ACTIVE` không đọc `req` chút nào (dòng 64–77) | ✅ kiểm ở TB dòng 57–59 |
| `req` **vẫn giữ 1** khi giao dịch vừa xong | **Cấp lại ngay chu kỳ kế** — hợp lệ và mong muốn | `IDLE` cấp lại ngay | ⚠️ **Testbench giả định ngược lại** ⟹ đây chính là nguyên nhân FAIL. Xem `known_issues.md`. |
| `done = 1` khi đang `IDLE` | **Không đặc tả rõ** | Bị **bỏ qua** hoàn toàn — nhánh `IDLE` không đọc `done` | ✅ hành vi an toàn, nhưng nên ghi vào đặc tả tầng ngoài |
| `done = 1` kéo dài nhiều chu kỳ | **Không đặc tả rõ** | Chu kỳ đầu nhả bus về `IDLE`; các chu kỳ sau bị bỏ qua | ✅ an toàn |
| `ptr = 3` (bất hợp lệ) | Không được kẹt | `default` của `case (ptr)` (dòng 41) dùng thứ tự quét `2,0,1` ⟹ thoát được | ✅ có xử lý — xem `fsm.md` §6 |
| Khối được cấp quyền **rút `req`** trước khi `done` | **Không đặc tả** | Trọng tài vẫn giữ quyền tới khi `done` ⟹ **bus có thể treo vĩnh viễn** nếu khối đó không bao giờ phát `done` | ⚠️ **Lỗ hổng liveness.** Cần watchdog/timeout, hoặc hợp đồng bắt buộc khối phải phát `done`. |
| Cả ba `req` lên **đúng cùng một chu kỳ** sau reset | `ptr=0` ⟹ M0 thắng | ✅ | kiểm ở TB dòng 36–39 |

> **Ghi nhận lỗ hổng quan trọng nhất:** hàng áp chót. RTL **không có timeout**. Nếu một khối
> chủ hỏng và không bao giờ phát `done`, `busy` dính mức 1 vĩnh viễn và hai khối kia bị bỏ
> đói tuyệt đối — đúng cái mà round-robin sinh ra để chống. Tính công bằng của F07 vì vậy là
> **có điều kiện**: nó chỉ đúng khi mọi khối chủ tuân thủ hợp đồng phát `done`. Điều này
> **phải** được ghi vào đặc tả giao diện, và hiện chưa có ở đâu trong hồ sơ.

## 6. Chứng minh không bỏ đói (INV-6) — lập luận từ mã

Giả sử `req[i] = 1` giữ liên tục. Xét thời điểm bất kỳ với con trỏ `p`.

1. Mỗi giao dịch hoàn tất đều đặt `p ← (j+1) mod 3` với `j` là khối **vừa được phục vụ**
   (dòng 67–72). Nghĩa là khối `j` bị đẩy xuống **cuối** thứ tự quét `scan(p')`.
2. Do đó khối `i` **không thể** bị một khối `j ≠ i` vượt mặt hai lần liên tiếp: sau khi `j`
   được phục vụ, `j` đứng sau `i` trong `scan`.
3. Có hai khối khác `i`. Vậy sau **nhiều nhất 2 giao dịch hoàn tất**, `i` đứng đầu `scan(p)`
   và vì `req[i]=1` nên `i` được cấp quyền ở chu kỳ `IDLE` kế tiếp.

**Chặn trên: 2 giao dịch.** Với mỗi giao dịch tối thiểu 2 chu kỳ, thời gian chờ xấu nhất là
`2 × (độ dài giao dịch) + 1` chu kỳ.

**Bằng chứng thực nghiệm đã có:** lần chạy mô phỏng đi **qua** các assertion dòng 39, 44,
49, 54 của `f07_tb.sv` — tức đã chứng minh chuỗi phục vụ `M0 → M1 → M2 → M0` khi cả ba xin
liên tục — **trước khi** dừng ở dòng 72. Bằng chứng về round-robin **vẫn có giá trị** dù
mô phỏng không chạy hết. Xem `known_issues.md` §6.

Mô hình chuẩn Python độc lập xác nhận chặt hơn: `test_all_request_rotation()` chạy 9 giao
dịch và khẳng định chuỗi phục vụ đúng `[0,1,2,0,1,2,0,1,2]` — PASS
(`python_reference_run.log`).

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
