# F07 · Phân tích đánh đổi (Trade-off)

---

## 1. Ràng buộc phạm vi phải đọc trước

Charter mục 3 liệt vào **ngoài phạm vi**: *"Ưu tiên động (đó là J10), nhiều bus, chia tách
giao dịch"*, cộng các ràng buộc chung (analog, physical design tự làm, sign-off, tape-out).

⟹ Các kiến trúc thay thế ở §2 chỉ được **so sánh trên giấy**. **Không** thay kiến trúc trong
RTL của thầy. Mọi khuyến nghị ở đây là **đề xuất chờ duyệt**.

## 2. Bảng so sánh kiến trúc trọng tài

| # | Kiến trúc | Ô nhớ | Công bằng | Độ phức tạp | Khi nào nên dùng |
|---|---|---|---|---|---|
| **A** | **Round-robin con trỏ** *(đang dùng)* | 2 (`ptr`) + 1 (`state`) + 4 (`grant`,`busy`) = **7 đo được** | ✅ Chặn trên **2 giao dịch** | Trung bình — 3 chuỗi ưu tiên + mux + bộ giải mã one-hot | **Mặc định đúng** khi ba khối chủ ngang hàng nhau về mức quan trọng |
| **B** | **Ưu tiên cố định** *(`f07_bad_fixed_priority` — phản ví dụ)* | **0** — mạch tổ hợp thuần | ❌ **Bỏ đói tuyệt đối**: M0 xin liên tục ⟹ M1, M2 không bao giờ được phục vụ | Tối thiểu — một chuỗi `if/else if` | Chỉ khi các khối **thật sự** có mức ưu tiên khác nhau và khối ưu tiên cao xin **thưa** |
| **C** | **Mặt nạ xoay** (rotating mask / thermometer) | 3 (mask one-hot) + FSM | ✅ tương đương A | Trung bình — mask + bộ mã hoá ưu tiên hai lần | Khi số khối chủ lớn (≥8): mask one-hot mở rộng tốt hơn con trỏ nhị phân vì không cần bộ giải mã |
| **D** | **Vòng thẻ bài** (token ring) | 3 (vị trí thẻ) | ✅ tuyệt đối công bằng | Thấp | Khi lưu lượng **đều**. **Kém khi lưu lượng lệch**: thẻ vẫn đi qua khối không xin ⟹ lãng phí chu kỳ. A không có nhược điểm này (quét bỏ qua khối không xin). |
| **E** | **Ưu tiên động có trọng số** | nhiều hơn | ✅ + điều chỉnh được | Cao | ⬛ **Charter mục 3: ngoài phạm vi — đó là đề J10** |

### 2.1 So bằng số thật — chỉ có một cột có số

| Chỉ số | **A** `f07_rr_arbiter` (đo được) | **B** `f07_bad_fixed_priority` |
|---|---:|---|
| Cell | **36** | ⬜ **chưa đo** |
| Flip-flop | **7** | **0** (đọc từ RTL: không có `always_ff`) |
| Diện tích | **327,8144 µm²** | ⬜ chưa đo |
| Đường tới hạn | `done → _53_ → _54_ → _55_ → _63_(ptr[0])` | ⬜ chưa đo |
| Data arrival | **1,42 ns** (gồm 1,00 ns input delay giả định) | ⬜ |
| Slack | **8,46 ns (MET)**, WNS/TNS = 0,00/0,00 | ⬜ |
| Công suất | **3,46e-05 W** — tuần tự 88,3 %, tổ hợp 11,7 % | ⬜ |
| **Có công bằng không?** | ✅ **CÓ** | ❌ **KHÔNG** |
| **Có khái niệm giao dịch không?** | ✅ (`done`, `busy`) | ❌ |

> 👉 Giống F06, dòng quan trọng nhất là hai dòng cuối. Kiến trúc B sẽ thắng mọi chỉ số kỹ
> thuật — 0 flip-flop, diện tích nhỏ hơn nhiều, không có đường `done → ptr` — và **giải sai
> bài toán**. So sánh chỉ có nghĩa khi hai phương án cùng thoả đặc tả.

### 2.2 Vì sao con số 7 FF vượt dự đoán 3–5 của Charter mục 10

Charter mục 10 ghi: *"2 (con trỏ ưu tiên) + 1–2 (bận) ≈ 3–5 ô nhớ. Nhỏ hơn sinh viên tưởng."*

| Thành phần | Charter dự đoán | Đo được | Chênh do đâu |
|---|---:|---:|---|
| Con trỏ `ptr` | 2 | **2** | ✅ khớp |
| Bận `busy` | 1–2 | **1** | ✅ khớp |
| FSM `state` | (không tính) | **1** | RTL tách trạng thái giao dịch riêng |
| `grant[2:0]` | **(không tính — ngầm coi là tổ hợp)** | **3** | ★ **Đây là toàn bộ chênh lệch** |
| **Tổng** | **3–5** | **7** | **+2..4** |

**Kết luận:** Charter ngầm giả định một trọng tài kiểu **Mealy** — `grant` suy thẳng từ
`req` và `ptr` bằng logic tổ hợp. RTL của thầy chọn kiểu **Moore** — `grant` đi qua
flip-flop. Chênh lệch 3–4 FF **không phải lỗi**, mà là hệ quả của một quyết định kiến trúc
có lý do chính đáng (§3).

## 3. Moore hay Mealy — đánh đổi trung tâm của F07

| | **Moore** (RTL hiện tại) | **Mealy** (Charter ngầm giả định) |
|---|---|---|
| FF | **7** (đo được) | ≈3 |
| Diện tích | 327,8144 µm² (đo được) | ⬜ nhỏ hơn, chưa đo |
| Độ trễ `req` → `grant` | **1 chu kỳ** | **0 chu kỳ** |
| Chu kỳ nghỉ giữa hai giao dịch | **1** (bắt buộc qua `IDLE`) | 0 — cấp lại ngay |
| **Glitch trên `grant`** | **Không** — `Q` nối thẳng ra cổng | **Có** — `grant` đổi theo `req` trong chu kỳ |
| Đường tổ hợp in→out | Không có | Có — `req → grant` |
| Rủi ro tranh chấp bus | Thấp | ⚠️ **Cao** — glitch trên `grant` có thể làm hai khối cùng lái bus vài trăm ps |

> **Vì sao Moore là lựa chọn đúng ở đây, dù tốn hơn:** `grant` không phải một tín hiệu bình
> thường — nó mở bộ đệm ba trạng thái lên một bus chung. Một glitch rộng 200 ps trên hai bit
> `grant` cùng lúc tạo ra **dòng ngắn mạch thật** giữa hai khối chủ, không chỉ là dữ liệu
> sai. Với loại tín hiệu này, "không glitch" đáng giá hơn 4 flip-flop và 1 chu kỳ độ trễ.
>
> Đây là một đánh đổi mà **chỉ hiểu bối cảnh ứng dụng mới quyết định đúng được** — nhìn
> thuần số liệu thì Mealy thắng.

## 4. Ba việc cần đo để trả lời Charter mục 9

> Charter mục 9: *"Chứng minh bằng mô phỏng rằng không khối nào bị bỏ đói khi cả ba cùng xin
> liên tục. Nêu trong báo cáo phần logic nào bảo đảm tính chất đó, và nó tốn thêm bao nhiêu
> cell so với trọng tài ưu tiên cố định."*

| Phần của câu hỏi | Trạng thái | Bằng chứng / việc cần làm |
|---|---|---|
| **(a)** Chứng minh không bỏ đói bằng mô phỏng | ✅ **ĐÃ CÓ** | TB dòng 39–54: chuỗi `M0→M1→M2→M0` với `req=111` — 4 assertion PASS. Python: 9 giao dịch, `[0,1,2]×3` PASS. |
| **(b)** Phần logic nào bảo đảm | ✅ **ĐÃ CÓ** | `ptr` (2 FF thật, netlist dòng 239–248) + `case (grant)` dòng 67–72 + `case (ptr)` dòng 30–46. Xem `fsm.md` §3, §8. |
| **(c)** Tốn thêm bao nhiêu cell so với ưu tiên cố định | ⬜ **CHƯA ĐO** | Cần chạy tổng hợp lần hai — xem bên dưới |

### 4.1 Cách lấy số cho phần (c) — và một cái bẫy phải tránh

**Chạy ngây thơ:**

```
# sửa 06_GDSII/synthesis/synth.ys dòng 4:
hierarchy -check -top f07_bad_fixed_priority
bash 04_IMPLEMENTATION/scripts/02_run_synth.sh
```

**Cái bẫy:** phép so này **không công bằng**. Hai module không cùng chức năng:

| | `f07_rr_arbiter` | `f07_bad_fixed_priority` |
|---|---|---|
| Có `done` / `busy` | ✅ | ❌ |
| Giữ quyền qua nhiều chu kỳ | ✅ | ❌ |
| `grant` đăng ký | ✅ (3 FF) | ❌ (tổ hợp) |
| Có `ptr` | ✅ (2 FF) | ❌ |

Phần lớn chênh lệch sẽ đến từ **cơ chế giao dịch**, không phải từ **round-robin**. Báo cáo
"round-robin tốn thêm 36 cell" sẽ là một kết luận **sai**.

**Cách so đúng — cần một module thứ ba:** cùng FSM `IDLE/ACTIVE`, cùng `grant`/`busy` đăng
ký, nhưng bỏ `ptr` và dùng một chuỗi ưu tiên cố định duy nhất. Chênh lệch khi đó mới là giá
thật của công bằng, dự đoán ≈ **2 FF + hai bộ mã hoá ưu tiên phụ + mux 3 chiều**.

Module thứ ba này **chưa tồn tại** trong gói. Viết nó là việc của sinh viên, và bản thân
việc thiết kế đúng thí nghiệm so sánh **là nội dung học** — có lẽ đáng hơn cả con số.

### 4.2 Một phần của câu trả lời đã có sẵn và hay bị bỏ qua

Giá của công bằng không chỉ là **cell**, mà còn là **timing**. STA cho thấy hai đường chậm
nhất của toàn thiết kế **đều là đường cập nhật `ptr`**:

```
  done ──▶ _53_(o311a_1) ──▶ _54_(mux2i_1) ──▶ _55_(isobufsrc) ──▶ ptr[0]   1,42 ns
  done ──▶ _53_(o311a_1) ──▶ _56_(mux2i_1) ──▶ _57_(isobufsrc) ──▶ ptr[1]   1,42 ns
```

Trọng tài ưu tiên cố định **không có đường này** — nó không có `ptr`. ⟹ **Round-robin tốn
thêm cả diện tích lẫn đường tới hạn**, và phần timing thì **đã đo được** ngay hôm nay:
0,42 ns logic thật trên đường dài nhất.

## 5. Đánh đổi bên trong kiến trúc A

| Lựa chọn trong RTL | Phương án khác | Giá / lợi |
|---|---|---|
| `ptr` **nhị phân 2 bit** | Mặt nạ one-hot 3 bit | ✅ −1 FF. ❌ Cần bộ giải mã `case (grant)` để tiến con trỏ. Với 3 khối, nhị phân thắng; với ≥8 khối, one-hot thắng. |
| `ptr ← (khối được phục vụ + 1)` qua **bảng tra** | `ptr ← ptr + 1` | ✅ **Đúng** về công bằng. ❌ Cần bộ giải mã one-hot→nhị phân. `ptr+1` rẻ hơn nhưng **sai**: khối được phục vụ có thể vẫn ở gần đầu hàng đợi. |
| `grant` dùng **hai vai** (đầu ra + trạng thái "ai đang phục vụ") | Thêm thanh ghi `served_id[1:0]` | ✅ −2 FF. ❌ Đọc mã khó hơn một chút. |
| `busy` là FF riêng | `assign busy = (grant != 0)` | ❌ +1 FF. ✅ Không có đường tổ hợp từ FF ra cổng; và Charter mục 4 yêu cầu `busy` ở `uo_out[5]`. |
| `state` **1 bit** (`enum logic`) | `enum logic [1:0]` | ✅ −1 FF **và** xoá hẳn khả năng có trạng thái bất hợp lệ. Xem `fsm.md` §5.1. |
| `default` của `case (ptr)` gộp `ptr=2` và `ptr=3` | `2'd2:` riêng + `default: selected_grant = 0` | ✅ **Tự phục hồi** khi `ptr=3`. ❌ Cách kia gây **deadlock**. Xem `fsm.md` §6.2. |
| **Không có timeout** | Thêm watchdog đếm chu kỳ `ACTIVE` | ❌ Lỗ hổng: một khối chủ hỏng treo bus vĩnh viễn. ✅ Tiết kiệm bộ đếm. **Cần thầy quyết định** — xem `control.md` §7. |

## 6. Những đánh đổi **KHÔNG được phép** trong đề này

| Đánh đổi | Vì sao cấm | Nguồn |
|---|---|---|
| Đổi sang **ưu tiên động / có trọng số** | Charter mục 3: đó là đề **J10** | Charter mục 3 |
| Thêm **bus thứ hai** | Ngoài phạm vi | Charter mục 3 |
| **Chia tách giao dịch** (split transaction) | Ngoài phạm vi | Charter mục 3 |
| Đổi `grant` thành **tổ hợp** để tiết kiệm 3 FF | Trái `functional_spec.md` §2.2 (quyền không bị cướp) và tạo rủi ro glitch trên bus | §3 |
| Cho phép **cướp quyền** khi khối ưu tiên cao xin | Trái đặc tả; TB dòng 56–59 kiểm điều ngược lại | `functional_spec.md` §2.2 |
| Bỏ `busy` vì suy được từ `grant` | Charter mục 4 chốt `uo_out[5]` — hợp đồng giao diện | Charter mục 4 |
| **Sửa RTL để "chữa" cổng `ptr` còn thiếu** | Hồ sơ chỉ **ghi nhận** và **đề xuất**, không tự sửa | SPEC §0.2, §3 |
| **Sửa DUT để testbench PASS** | Phán xử đã chỉ rõ lỗi ở testbench. Sửa DUT sẽ phá một mạch đang đúng và giảm thông lượng bus 33 % | `known_issues.md` §4 |
| Tự tối ưu netlist bằng tay | Ngoài phạm vi chung | Charter mục 3 |
| Tuyên bố tần số từ slack 8,46 ns | Chưa có ký sinh dây, một góc PVT | `02_SPECIFICATION/timing.md` §3 |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
