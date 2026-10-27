# F07 — FSM trọng tài bus ba chủ theo vòng tròn · Ghi chú thực hiện

---

## 1. Bài toán này thực chất là gì

Ba khối chủ dùng chung một bus dữ liệu. Tại một thời điểm chỉ **một** khối được lái bus —
nếu hai khối cùng lái, đó không chỉ là dữ liệu sai mà là **dòng ngắn mạch thật** giữa hai
bộ đệm đầu ra.

Nhưng "chỉ một khối được cấp quyền" mới là nửa dễ của bài toán. Một mạch `if (req[0]) ...
else if (req[1]) ... else if (req[2])` thoả nửa đó trong 3 dòng. Nửa khó là **công bằng**:
nếu M0 xin liên tục, mạch ba dòng kia sẽ **không bao giờ** phục vụ M1 và M2. Đó là bỏ đói
(starvation), và nó không phải một lỗi hiếm — nó là hành vi mặc định của cách viết tự nhiên
nhất.

Gói RTL có sẵn đúng mạch ba dòng đó trong `f07_bad_fixed_priority.sv`, với ghi chú ở dòng 1:
*"EDUCATIONAL ANTI-PATTERN. Fixed priority is intentionally shown to contrast with
round-robin."* Đặt hai mạch cạnh nhau là cách dạy hiệu quả nhất cho đề này.

Round-robin giải nửa khó bằng một ý tưởng: giữ một **con trỏ** chỉ ra ai được quét trước, và
sau mỗi lần phục vụ, đẩy khối vừa được phục vụ **xuống cuối** thứ tự quét.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

Cơ chế gói trong một câu: **thứ tự ưu tiên không cố định trong dây, nó là hàm của một thanh
ghi 2 bit; và thanh ghi đó chỉ đổi khi một giao dịch hoàn tất.**

Ba tầng điều khiển lồng nhau, có chu kỳ thay đổi rất khác nhau:

| Tầng | Đại lượng | Đổi khi nào | Ô nhớ |
|---|---|---|---:|
| 1 · giao dịch | `state` (IDLE/ACTIVE) | mỗi lần cấp/nhả quyền | 1 FF |
| 2 · chọn | `selected_grant` | **tổ hợp** — đổi liên tục theo `req` | 0 |
| 3 · công bằng | `ptr` | **chỉ khi `done = 1`** | 2 FF |

Tầng 3 đổi chậm nhất nhưng quyết định tính chất quan trọng nhất. Đây là cấu trúc điển hình
của mọi bộ trọng tài: **chính sách ở tầng chậm, cơ chế ở tầng nhanh**.

Chi tiết tinh tế nhất — và là chỗ phân biệt round-robin **thật** với round-robin **hình
thức** — nằm ở cách con trỏ tiến. RTL viết `ptr ← (khối ĐƯỢC PHỤC VỤ + 1) mod 3`, không
phải `ptr ← ptr + 1`. Khác biệt lộ ra khi `ptr = 0` mà M0 không xin: M2 được phục vụ, và
`ptr` phải nhảy thẳng tới **0** (= (2+1) mod 3), không phải tới 1. Chỉ cách này mới bảo đảm
khối vừa được phục vụ xuống cuối hàng đợi. Viết `ptr+1` sẽ để M2 vẫn ở gần đầu và có thể
được phục vụ lại sớm — công bằng bị phá mà mọi ca kiểm thử đơn giản vẫn PASS.

Cơ chế thứ hai đáng nói: **quyền không bị cướp**. Trạng thái `ACTIVE` **hoàn toàn không đọc
`req`** — đọc kỹ nhánh `ACTIVE` sẽ thấy `req` vắng mặt. Nhờ đó một khối đang lái bus không
bị cắt giữa chừng khi khối khác giơ tay. Đây là lý do `busy` tồn tại, và là lý do `grant`
phải được **đăng ký** chứ không gán thẳng từ logic tổ hợp.

Cơ chế thứ ba, ít ai để ý: **`grant` đóng hai vai**. Nó vừa là đầu ra, vừa là thanh ghi
trạng thái lưu "ai đang được phục vụ" — vì `case (grant)` đọc lại chính nó để tiến `ptr`.
Nhờ vậy module không cần thêm thanh ghi `served_id`, tiết kiệm 2 FF.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

Trái tim của round-robin là khối chọn xoay:

```systemverilog
always_comb begin
    selected_id    = 2'd0;
    selected_grant = 3'b000;              // ← gán mặc định: chặn suy ra latch
    case (ptr)
        2'd0: begin
            if      (req[0]) begin selected_id=2'd0; selected_grant=3'b001; end
            else if (req[1]) begin selected_id=2'd1; selected_grant=3'b010; end
            else if (req[2]) begin selected_id=2'd2; selected_grant=3'b100; end
        end
        2'd1: begin   /* thứ tự 1,2,0 */ end
        default: begin /* thứ tự 2,0,1 — BẮT CẢ ptr=2 LẪN ptr=3 */ end
    endcase
end
```

Ba điều đọc được ngay:

1. **Ba chuỗi ưu tiên tĩnh, một mux chọn giữa chúng.** "Ưu tiên xoay" trong phần cứng không
   phải một bộ xoay bit — nó là ba bộ mã hoá ưu tiên viết sẵn, và `ptr` chọn dùng bộ nào.
2. **`default` gộp `ptr=2` và `ptr=3`.** Đây là một lựa chọn tốt hơn vẻ ngoài: `ptr=3` là mã
   bất hợp lệ (2 bit, 3 giá trị dùng), và gộp nó vào một nhánh hợp lệ làm FSM **tự phục
   hồi**. Nếu viết `2'd2:` riêng rồi `default: selected_grant = 3'b000`, thì `ptr=3` sẽ
   không cấp quyền cho ai, `done` không bao giờ tới, `ptr` không bao giờ được ghi lại —
   **deadlock**. Cùng một mã bất hợp lệ, hai cách viết, một tự phục hồi và một treo.
3. **Gán mặc định ở hai dòng đầu** làm khối `always_comb` đầy đủ với mọi tổ hợp
   `(ptr, req)` — 32 tổ hợp — nên không suy ra latch.

Đoạn thứ hai, nơi công bằng thật sự được thực thi:

```systemverilog
ACTIVE: begin
    if (done) begin
        case (grant)                      // ĐỌC grant như trạng thái
            3'b001: ptr <= 2'd1;
            3'b010: ptr <= 2'd2;
            3'b100: ptr <= 2'd0;          // ← WRAP: toàn bộ phần "vòng tròn"
            default: ptr <= ptr;
        endcase
        grant <= 3'b000;  busy <= 1'b0;  state <= IDLE;
    end
    // KHÔNG CÓ else — và req không xuất hiện ở đâu trong nhánh này
end
```

Việc **không có `else`** là cố ý: trong `always_ff`, không gán nghĩa là giữ nguyên, sinh mux
hồi tiếp chứ không sinh latch. Và việc `req` vắng mặt chính là cơ chế bảo đảm INV-3.

Cuối cùng, một chi tiết nên dọn: `selected_id` (dòng 14) được gán ở 7 chỗ nhưng **không bao
giờ được đọc**, và hàm `onehot3` (dòng 17–24) **không bao giờ được gọi**. Cả hai là mã chết;
`opt_clean -purge` xoá sạch, và netlist xác nhận — không có dây nào tên `selected_id`. Vô
hại về phần cứng, nhưng gây hiểu nhầm khi đọc mã.

## 4. Vì sao chọn kiến trúc này

Có ít nhất bốn cách làm trọng tài công bằng (`03_ARCHITECTURE/tradeoff.md` §2): con trỏ nhị
phân, mặt nạ xoay one-hot, vòng thẻ bài, ưu tiên động. Với **ba** khối chủ:

- **Vòng thẻ bài** thua vì thẻ vẫn đi qua khối không xin, lãng phí chu kỳ. Round-robin quét
  **bỏ qua** khối không xin.
- **Mặt nạ one-hot** tốn 3 FF thay vì 2, đổi lại không cần bộ giải mã. Với 3 khối, con trỏ
  nhị phân thắng; từ khoảng 8 khối trở lên thì ngược lại.
- **Ưu tiên động** nằm ngoài phạm vi (Charter mục 3: đó là đề J10).

Bên trong kiến trúc con trỏ, quyết định lớn nhất là **Moore thay vì Mealy** — đăng ký
`grant` và `busy` thay vì để chúng tổ hợp. Cái giá đo được: **7 FF** thay vì ≈3, và thêm
1 chu kỳ độ trễ. Charter mục 10 dự đoán 3–5 FF, tức ngầm giả định Mealy.

Vì sao Moore vẫn đúng: `grant` mở bộ đệm ba trạng thái lên bus chung. Một glitch rộng 200 ps
trên hai bit `grant` cùng lúc tạo dòng ngắn mạch thật, không chỉ dữ liệu sai. Với loại tín
hiệu này, "không glitch" đáng hơn 4 flip-flop. **Đây là đánh đổi mà chỉ hiểu bối cảnh ứng
dụng mới quyết định đúng được** — nhìn thuần số liệu thì Mealy thắng.

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| Bước | Việc | Trạng thái F07 | Bằng chứng |
|---|---|---|---|
| 1 | Bảng hành vi + invariant từ Charter | ✅ | `functional_spec.md` §2, §4 |
| 2 | Mô hình chuẩn Python độc lập | ✅ PASS 5 ca | `python_reference_run.log` |
| 3 | RTL mô tả tường minh FSM + con trỏ | ✅ | `f07_rr_arbiter.sv` |
| 4 | Testbench tự kiểm | ⚠️ **FATAL t=156 — lỗi testbench** | `known_issues.md` |
| 5 | Tổng hợp, đọc `synth_stat` | ✅ 36 cell · 7 FF · 327,8144 µm² | `synth_stat.txt` |
| 6 | STA, đọc đường tới hạn | ✅ `done → ptr[0]`, 1,42 ns, slack 8,46 | `timing_report_max.txt` |
| 7 | Ước lượng công suất | ✅ 3,46e-05 W | `power_report.txt` |
| 8 | P&R → DRC → LVS → GDS | ⬜ chưa chạy | `physical_report.md` §1 |

Khác với F06, chuỗi bằng chứng của F07 **không bị đứt**: `f07_tb.sv` dòng 7 và `synth.ys`
dòng 4 dùng **cùng** top module `f07_rr_arbiter`. Số liệu cấu trúc thuộc về đúng mạch đã
được mô phỏng.

## 6. Số liệu thật đã đo được và cách đọc chúng

| Chỉ số | Giá trị | Nguồn |
|---|---:|---|
| Số cell | **36** | `synth_stat.txt` |
| Flip-flop | **7** | như trên |
| Diện tích | **327,8144 µm²** | như trên |
| Startpoint → Endpoint | `done` → `_63_` (= `ptr[0]`) | `sta/summary.txt` |
| Data arrival | **1,42 ns** | `timing_report_max.txt` |
| Slack | **8,46 ns (MET)** | như trên |
| WNS / TNS | 0,00 / 0,00 | `wns.txt`, `tns.txt` |
| Công suất | **3,46e-05 W** — tuần tự 88,3 %, tổ hợp 11,7 % | `power_report.txt` |
| Mô phỏng RTL | RAN_WITH_ISSUES — FATAL t=156 | `simulation.log` |
| Mô hình chuẩn Python | PASS | `python_reference_run.log` |

**Ánh xạ 7 flip-flop sang tín hiệu** (đọc từ `netlist.v` dòng 214–248):
`_58_`→`state`, `_59_ _60_ _61_`→`grant[0..2]`, `_62_`→`busy`, `_63_ _64_`→`ptr[0..1]`.

**Những số này chứng minh gì:**

- Mạch tổng hợp được ra `sky130_fd_sc_hd` thật, 7 FF ⟹ đúng phân loại "Tuần tự".
- `grant` và `busy` là **đầu ra đăng ký**: chân `Q` nối **thẳng** ra cổng, không cổng tổ hợp
  nào ở giữa ⟹ bằng chứng mức netlist rằng đây là máy **Moore**.
- Round-robin hiện thành **2 flip-flop `ptr` thật** — trả lời Charter mục 2 câu 1 bằng phần
  cứng, không phải bằng lời.
- Không có đường timing âm ở chu kỳ giả định 10 ns, góc `tt_025C_1v80`, **sau tổng hợp**.

**Những số này KHÔNG chứng minh gì:**

1. **1,42 ns không phải độ trễ logic.** 1,00 ns trong đó là `set_input_delay` **giả định**
   từ `design.sdc`; logic thật chỉ **0,42 ns** (3 cell: 0,19 + 0,18 + 0,05).
2. **Slack 8,46 ns không dịch thành tần số.** Chưa P&R, chưa có ký sinh dây, một góc PVT.
3. **Đường tới hạn có thể đổi nếu SDC đổi.** `done` là cổng vào nên mang 1,0 ns giả định;
   khối chọn xoay bắt đầu từ FF `ptr`, nên arrival của nó chỉ bằng `t_ckq` — nhỏ hơn 1,0 ns
   rất nhiều. Chênh lệch điểm xuất phát đó đủ để đảo thứ hạng. Một phần "đường tới hạn" là
   hệ quả của **cách ràng buộc**, không phải của mạch. (Giá trị `t_ckq` của `_63_` ⬜ chưa
   có — STA của F07 chỉ báo các đường `input → FF`.)
4. **36 cell không so được với `f07_bad_fixed_priority`** cho tới khi module đó được tổng
   hợp — và ngay cả khi có số, phép so vẫn không công bằng (§8).
5. **7 FF không chứng minh `grant` luôn one-hot.** Sau tổng hợp, ba bit là ba FF độc lập;
   one-hot chỉ đúng nhờ logic điều khiển, không nhờ cấu trúc. Cần mô phỏng gate-level.

**Phát hiện đáng chú ý nhất:** đường tới hạn kết thúc ở **`ptr[0]`**, và đường chậm thứ hai
(slack cũng 8,46 ns) kết thúc ở **`ptr[1]`**. Hai đường chậm nhất của toàn thiết kế đều là
đường cập nhật con trỏ công bằng. Nói cách khác, **giá của công bằng phải trả bằng cả diện
tích lẫn timing** — và phần timing thì đã đo được ngay hôm nay.

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

**Câu 1 — *"Round-robin hiện ra trong phần cứng dưới dạng gì — con trỏ quay hay ưu tiên
xoay?"***
**Cả hai, và chúng là hai bộ phận khác nhau.** Con trỏ quay hiện thành **2 flip-flop**
(`netlist.v` dòng 239–248). Ưu tiên xoay hiện thành **logic tổ hợp** — ba bộ mã hoá ưu tiên
viết sẵn trong `case (ptr)`, được chọn bởi con trỏ. Con trỏ là **trạng thái**; ưu tiên xoay
là **hàm của trạng thái đó**. Không có con trỏ thì không có ký ức về lượt; không có ưu tiên
xoay thì con trỏ vô dụng.

**Câu 2 — *"Bằng chứng nào chứng minh không khối nào bị bỏ đói khi cả ba xin liên tục?"***
Hai bằng chứng độc lập, cộng một chứng minh hình thức:
(a) **RTL**: TB dòng 39, 44, 49, 54 với `req=3'b111` liên tục — chuỗi phục vụ `M0→M1→M2→M0`,
cả bốn assertion **PASS** (t=36…96, trước khi mô phỏng dừng ở t=156).
(b) **Python**: `test_all_request_rotation()` chạy 9 giao dịch, `served == [0,1,2]×3` PASS.
(c) **Chứng minh**: mỗi giao dịch đẩy khối vừa phục vụ xuống cuối `scan`; có 2 khối khác ⟹
chặn trên **2 giao dịch** (`functional_spec.md` §6).
⚠️ Bảo đảm này **có điều kiện**: nó chỉ đúng khi mọi khối chủ phát `done`. RTL **không có
timeout** — xem §11.

**Câu 3 — *"Chỉ một khối được cấp quyền tại một thời điểm — chứng minh bằng gì?"***
Ba tầng, độ mạnh tăng dần: (a) hành vi — `assert($onehot0(grant))` ×3, PASS;
(b) cấu trúc RTL — `selected_grant` chỉ nhận hằng one-hot hoặc `000`, không có phép OR nào
giữa các bit; (c) gate-level — ⬜ **chưa kiểm**, và đây là tầng quan trọng nhất vì sau tổng
hợp ba bit `grant` là ba FF độc lập.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

> *"Chứng minh bằng mô phỏng rằng không khối nào bị bỏ đói… Nêu phần logic nào bảo đảm tính
> chất đó, và nó tốn thêm bao nhiêu cell so với trọng tài ưu tiên cố định."*

| Phần | Trạng thái |
|---|---|
| (a) Chứng minh bằng mô phỏng | ✅ **ĐÃ CÓ** — §7 câu 2 |
| (b) Phần logic nào bảo đảm | ✅ **ĐÃ CÓ** — `ptr` (2 FF) + `case (grant)` dòng 67–72 + `case (ptr)` dòng 30–46 |
| (c) Tốn thêm bao nhiêu cell | ⬜ **CHƯA ĐO** |

Phần (c) chưa có số vì `synth.ys` dòng 4 đặt top là `f07_rr_arbiter`, nên
`f07_bad_fixed_priority` bị loại khỏi thiết kế và không xuất hiện trong `synth_stat.txt`.

**Và ở đây có một cái bẫy phải nói rõ:** ngay cả khi tổng hợp `f07_bad_fixed_priority` rồi
lấy `36 − (số cell của nó)`, con số đó **không phải** giá của round-robin. Hai module không
cùng chức năng: phản ví dụ **không có** `done`, **không có** `busy`, **không** giữ quyền qua
nhiều chu kỳ, `grant` **tổ hợp** (0 flip-flop). Phần lớn chênh lệch đến từ **cơ chế giao
dịch**, không phải từ công bằng.

Phép so đúng cần một module **thứ ba** chưa tồn tại: cùng FSM `IDLE/ACTIVE`, cùng `grant`/
`busy` đăng ký, nhưng bỏ `ptr` và dùng ưu tiên cố định. Chênh lệch khi đó ≈ **2 FF + hai bộ
mã hoá ưu tiên phụ + mux 3 chiều**. Thiết kế đúng thí nghiệm so sánh có lẽ đáng học hơn cả
con số.

Một phần câu trả lời **đã có sẵn** và hay bị bỏ qua: giá của công bằng không chỉ là cell mà
còn là **timing** — hai đường chậm nhất của thiết kế đều là đường `done → ptr`, 0,42 ns
logic thật. Trọng tài ưu tiên cố định không có đường này.

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| # | Sai lầm | Hậu quả | Phát hiện bằng bằng chứng nào |
|---|---|---|---|
| 1 | **`ptr <= ptr + 1`** thay vì tiến theo khối được phục vụ | Round-robin **hình thức**: khối vừa phục vụ vẫn ở gần đầu hàng đợi | Ca `ptr=1`, `req=3'b101`: phải phục vụ M2 rồi `ptr←0`. Nếu `ptr←2` là sai. Python `test_priority_scan()` kiểm đúng điều này. |
| 2 | **Test một và hai khối rồi kết luận đúng** | Không phân biệt được round-robin với ưu tiên cố định | Charter mục 10 cảnh báo đúng chỗ này. Chỉ assertion dòng 44 (`expected M1 second`) mới lộ. |
| 3 | **Để `ACTIVE` đọc `req`** | Cướp quyền giữa giao dịch ⟹ hỏng dữ liệu bus | TB dòng 57–59: hạ `req` về `000` khi đang `ACTIVE`, `grant` phải **không đổi**. |
| 4 | **Gán `grant` tổ hợp** để tiết kiệm FF | Glitch trên đường cấp quyền bus ⟹ nguy cơ tranh chấp điện | Đọc netlist: chân `Q` của FF phải nối **thẳng** ra cổng `grant`. Nếu có cổng logic ở giữa là Mealy. |
| 5 | **Sửa DUT khi testbench FAIL** | Phá một mạch đang đúng; giảm thông lượng bus 33 % | Truy vết từng chu kỳ tới đúng `Time: 156` rồi đối chiếu đặc tả §2.1. Xem `known_issues.md` §4. |
| 6 | **Đọc cảnh báo `sorry:` thành nguyên nhân lỗi** | Kết luận sai hoàn toàn về nguyên nhân | `sorry:` ≠ `error:`. Bằng chứng: mô phỏng chạy qua 11 assertion trước khi dừng. `known_issues.md` §3. |
| 7 | **Quên `default` trong `always_comb`** | Suy ra latch trong khối chọn | Tìm cell `dlxtp`/`dlatch` trong `synth_stat.txt`; đọc cảnh báo latch trong `yosys.log`. |
| 8 | **Viết `2'd2:` riêng rồi `default: grant=0`** | `ptr=3` ⟹ **deadlock** vĩnh viễn | Ép `force dut.ptr = 2'd3` rồi chạy — FSM phải tự phục hồi sau 1 giao dịch. `fsm.md` §6.2. |
| 9 | **Báo "round-robin tốn thêm 36 cell"** sau khi so với phản ví dụ | Kết luận sai — phần lớn chênh lệch là cơ chế giao dịch | So bảng cổng hai module: phản ví dụ không có `done`, `busy`, 0 FF. §8. |
| 10 | **Tin `grant` one-hot vì RTL gán hằng số** | Sau tổng hợp, 3 bit là 3 FF độc lập — one-hot không còn được cấu trúc bảo đảm | Phải mô phỏng gate-level với assertion `$onehot0`. ⬜ chưa chạy. |
| 11 | **Quên rằng bảo đảm không bỏ đói là CÓ ĐIỀU KIỆN** | Phát biểu vượt mức | Không có timeout trong RTL. Một khối chủ treo ⟹ bỏ đói tuyệt đối. `control.md` §7. |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|---|---|---|
| 1 | Chỉ ra **flip-flop** nào trong netlist mang tính công bằng. | `_63_` và `_64_` — `ptr[0]`, `ptr[1]`. Netlist dòng 239–248. |
| 2 | Vì sao `ptr` tiến theo `grant` chứ không theo `ptr+1`? | Để đẩy khối **vừa được phục vụ** xuống cuối. Nếu `ptr=0`, M0 không xin, M2 được phục vụ, thì `ptr` phải về 0 — `ptr+1` cho 1, sai. |
| 3 | Trạng thái `ACTIVE` đọc `req` ở đâu? | **Không đọc ở đâu cả.** Đó chính là cơ chế "quyền không bị cướp". Kiểm bằng TB dòng 57–59. |
| 4 | Máy này Mealy hay Moore? Bằng chứng mạnh nhất? | **Moore.** Bằng chứng mạnh nhất ở **netlist**: `Q` của `_59_.._62_` nối thẳng ra `grant`/`busy`, không cổng nào ở giữa. STA cũng không báo đường in→out nào. |
| 5 | Charter dự đoán 3–5 FF, đo được 7. Giải thích. | Charter ngầm giả định `grant` tổ hợp (Mealy). RTL đăng ký `grant` (3 FF) + `busy` (1) + `state` (1) + `ptr` (2) = 7. Không phải lỗi — là đánh đổi chống glitch trên bus. |
| 6 | `ptr = 3` có xảy ra không? Nếu có thì sao? | Không xảy ra (INV-5): reset đặt 0, mọi gán chỉ sinh 0/1/2. Nếu bị ép, `default` của `case (ptr)` dùng thứ tự `2,0,1` ⟹ vẫn cấp quyền, tự phục hồi sau 1 giao dịch. |
| 7 | Đường tới hạn đi từ đâu tới đâu, và vì sao là đường đó? | `done → o311a_1 → mux2i_1 → isobufsrc → ptr[0]`, 1,42 ns. Vì `done` là cổng vào (mang 1,0 ns input delay giả định) và cổng phức hợp trên đường này đắt hơn cổng đơn. Khối chọn xoay bị `abc` gộp thành cổng phức hợp nên nông hơn dự đoán. |
| 8 | Mô phỏng FAIL ở dòng 72. Ai sai — DUT, mô hình chuẩn, hay testbench? | **Testbench.** `req=3'b100` không được hạ trước khi kiểm `grant==000`; DUT cấp lại đúng đặc tả. Mô hình Python **đồng ý với DUT**. Truy vết tới đúng `Time: 156`. |
| 9 | Vì sao assertion gần như giống hệt ở dòng 63 lại PASS? | Vì dòng 57 đã hạ `req` về `000` — vì một mục đích khác. Dòng 63 PASS **một cách tình cờ**. |
| 10 | Bằng chứng round-robin có còn giá trị khi mô phỏng FAIL không? | **Có.** Bốn assertion dòng 39–54 đã chạy PASS **trước** t=156. Phần mất là assertion phục hồi sau reset (dòng 74–80). |
| 11 | Nếu một khối chủ không bao giờ phát `done` thì sao? | Bus **treo vĩnh viễn**, hai khối kia bỏ đói tuyệt đối. RTL không có timeout. Bảo đảm công bằng là **có điều kiện**. |
| 12 | Muốn mở rộng lên 8 khối chủ thì đổi gì? | `ptr` lên 3 bit; `case (ptr)` lên 8 nhánh — **bùng nổ**. Lúc đó nên chuyển sang **mặt nạ one-hot xoay**: chi phí tuyến tính thay vì nhân bản 8 bộ mã hoá ưu tiên. |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

**Đã chứng minh:**

- **Round-robin đúng trên RTL thật**: chuỗi `M0→M1→M2→M0` với ba khối xin liên tục, 4
  assertion PASS (t=36…96). Đây là nội dung chính của Charter mục 9 phần (a).
- **Quyền không bị cướp**: `grant` giữ nguyên khi `req` về `000` giữa giao dịch (t=106).
- **One-hot** ở cả ba lần cấp quyền, ở mức hành vi.
- Mô hình chuẩn Python độc lập PASS 5 ca, trong đó có ca 9 giao dịch liên tiếp.
- Tổng hợp ra 36 cell sky130 thật, 7 FF, 327,8144 µm²; STA MET với slack 8,46 ns ở chu kỳ
  giả định 10 ns, góc `tt_025C_1v80`, **sau tổng hợp**.
- **Máy là Moore** — bằng chứng mức netlist.
- **Con trỏ là 2 flip-flop thật**, không phải khái niệm trừu tượng.

**Chưa chứng minh — và không được nói là đã:**

- **Phục hồi sau reset giữa chừng**: TB dòng 74–80 chưa chạy tới (dừng t=156).
- **Giá của công bằng tính bằng cell**: Charter mục 9 phần (c) ⬜ chưa đo, và cần một thí
  nghiệm so sánh được thiết kế đúng (§8).
- **`grant` one-hot ở mức gate**: sau tổng hợp là 3 FF độc lập; chưa mô phỏng gate-level.
- **Hành vi khi `ptr = 3`**: không tạo được bằng kích thích ở cổng vào; cần `force`.
- **Yêu cầu Charter mục 4 chưa thoả**: thiếu cổng `uo_out[4:3]` cho `ptr`; thừa cổng `done`
  không có trong ngân sách chân. Đánh dấu **CHƯA THOẢ** ở `functional_spec.md`.
- **Không có bảo vệ khi khối chủ treo**: không timeout, không watchdog. Tính công bằng là
  bảo đảm **có điều kiện**, và điều kiện đó chưa được ghi ở tầng đặc tả tự sinh.
- Netlist tương đương RTL; độ trễ sau routing; biên qua các góc PVT; DRC/LVS/GDS: ⬜.

**Hành động đề xuất, chờ thầy duyệt** (hồ sơ không tự sửa RTL/testbench): áp dụng bản vá
`known_issues.md` §7.2 (biến lỗi thành hai ca kiểm thử), chạy lại mô phỏng cho hết, tổng hợp
module so sánh thứ ba để trả lời Charter mục 9 phần (c), bổ sung INV-2/INV-4/INV-5 vào
`properties.sv`, và quyết định về hai vấn đề kiến trúc: cổng `ptr` còn thiếu và cơ chế
timeout.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
