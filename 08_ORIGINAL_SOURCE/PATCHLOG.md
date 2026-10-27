# F07 · Nhật ký vá (PATCHLOG)

**Ngày vá:** 2026-09-24 · **Người duyệt:** giảng viên đã duyệt áp dụng toàn bộ bản vá

## 1. Tóm tắt

| # | File | Loại lỗi | Mô tả một dòng | Ảnh hưởng số liệu |
|---|---|---|---|---|
| P-1 | `05_VERIFICATION/testbench/f07_tb.sv` | **Lỗi testbench** | Ca "single requester" quên hạ `req` trước khi kiểm nhả bus ⇒ `$fatal` ở t=156 dù DUT đúng. Vá theo phương án B: tách thành **hai** ca — cấp lại liên tiếp, rồi mới nhả bus | **Không** — RTL không bị chạm |
| P-2 | `05_VERIFICATION/golden_model/reference_model.py` | Điểm mù của mô hình chuẩn | Thêm `test_back_to_back_regrant()` — mọi ca cũ đều hạ `req=0` khi hoàn tất nên không ca nào phủ tình huống "yêu cầu vẫn giữ" | Không |

**RTL (`04_IMPLEMENTATION/rtl/*.sv`) giữ nguyên tuyệt đối** — phán xử §2 của
`known_issues.md` kết luận DUT hành xử đúng đặc tả; sửa DUT sẽ phá hỏng một mạch đang đúng.

## 2. Chi tiết từng bản vá

### P-1 — Testbench quên hạ `req` trước khi kiểm nhả bus

**File:** `05_VERIFICATION/testbench/f07_tb.sv` · **Dòng:** 70–72 (bản gốc) ·
**Phán xử:** lỗi ở **testbench**.

**Trước:**
```systemverilog
        // Single requester.
        req=3'b100;
        tick();
        assert(grant==3'b100) else $fatal(1,"single requester failed");

        complete();
        tick();
        assert(grant==3'b000) else $fatal(1,"single requester completion failed");
```

**Sau:**
```systemverilog
        // Single requester.
        req=3'b100;
        tick();
        assert(grant==3'b100) else $fatal(1,"single requester failed");

        complete();
        // Ca 1: yeu cau VAN GIU -> trong tai phai cap lai NGAY (back-to-back grant).
        tick();
        assert(grant==3'b100 && busy)
            else $fatal(1,"persistent request must be re-granted back-to-back");
        assert($onehot0(grant)) else $fatal(1,"grant not one-hot");

        // Ca 2: ha yeu cau -> bus moi thuc su ranh.
        complete();
        req=3'b000;
        tick();
        assert(grant==3'b000) else $fatal(1,"single requester completion failed");
```

**Vì sao:** `req` được đặt `3'b100` và **không bao giờ được hạ**. Tại cạnh clock t=155 bus
đã rảnh (`ptr=0`, `state=IDLE`) trong khi `req[2]` vẫn bằng 1, nên trọng tài **phải** cấp
lại quyền cho M2 — đúng `functional_spec.md` §2.1. Assertion cũ kỳ vọng `grant==000` là kỳ
vọng **sai**. (Assertion gần giống hệt ở dòng 63 PASS chỉ vì dòng 57 tình cờ đã đặt
`req=3'b000` vì một mục đích khác.)

**Chọn phương án B (§7.2 của `known_issues.md`) chứ không phải A:** phương án A (thêm một
dòng `req=3'b000;`) làm testbench PASS nhưng **vứt bỏ** hành vi vừa phát hiện. Phương án B
biến lỗi thành hai ca kiểm thử có giá trị: một ca về thông lượng (cấp lại liên tiếp — hành
vi trước đây **không có ca nào** phủ), một ca về nhả bus.

**Hệ quả:** mô phỏng chạy hết, tới `$finish` tại t=196; ca "phục hồi sau reset" (dòng 74–80
bản gốc) **lần đầu tiên được chạy tới**. Không ảnh hưởng số liệu vật lý.

### P-2 — Mô hình chuẩn có cùng điểm mù với testbench

**File:** `05_VERIFICATION/golden_model/reference_model.py` · **Phán xử:** thiếu ca kiểm
thử (mô hình **không sai**, nhưng không bắt được lỗi).

**Sau (thêm mới):**
```python
def test_back_to_back_regrant():
    # Diem mu cu: moi ca deu ha req=0 khi hoan tat, nen khong ca nao kiem
    # tinh huong "yeu cau van giu sau khi giao dich xong".
    m = RoundRobinArbiter(); m.ptr = 1
    g,_,_ = m.step(0b100);            assert g == 0b100
    m.step(0b100, done=True)          # hoan tat, ptr -> 0
    g,b,_ = m.step(0b100)             # yeu cau VAN GIU
    assert g == 0b100 and b           # phai cap lai ngay
    m.step(0b100, done=True)
    g,b,_ = m.step(0b000)             # ha yeu cau -> bus moi thuc su ranh
    assert g == 0 and not b
```
được gọi trong `__main__` ngay sau `test_single_request()`, kèm một dòng
`print("Back-to-back re-grant on persistent request PASS")`.

**Chênh lệch so với bản vá đã soạn (§7.3):** bản soạn dừng ở kiểm "phải cấp lại ngay"; bản
áp dụng thêm hai bước cuối để mô hình chuẩn phủ **đúng cùng kịch bản** với hai ca mới của
testbench (cấp lại, rồi hạ `req` mới thật sự rảnh). Đây là điểm mà §5 của `known_issues.md`
gọi là *diverse redundancy chỉ có tác dụng khi chạy cùng kịch bản*.

**Hệ quả:** không ảnh hưởng số liệu.

### Không vá — cảnh báo `sorry: constant selects`

9 dòng cảnh báo `sorry:` của Icarus **vẫn còn** sau khi vá, và **cố ý giữ nguyên**. Theo
§3 và §7.4 của `known_issues.md`: cảnh báo này vô hại (danh sách nhạy cảm bị mở rộng tới
đúng cái mà nó lẽ ra phải có, và khối tổ hợp có gán mặc định vô điều kiện nên không giữ
trạng thái). Đổi `always_comb` → `always @(*)` chỉ để log sạch là **đánh đổi an toàn lấy
thẩm mỹ** — không làm.

## 3. Kết quả xác minh sau khi vá

| Bước | Trước khi vá | Sau khi vá |
|---|---|---|
| Mô hình chuẩn Python | PASS (5 ca, có điểm mù) | **PASS** — 6 ca, mã thoát 0 |
| Biên dịch | PASS (9 cảnh báo `sorry:`) | **PASS** — vẫn 9 cảnh báo `sorry:`, 0 lỗi |
| Mô phỏng | **RAN_WITH_ISSUES** — `$fatal` tại t=156, dòng 72 | **PASS** — `F07 TB completed`, `$finish` tại t=196, không còn `$fatal` |
| Tổng hợp | 36 cell / 7 FF / 327,8144 µm² | **36 cell / 7 FF / 327,8144 µm²** (không đổi — RTL không bị chạm) |

Cell sau khi vá: 7 × `dfxtp_1` (1 bit `state` + 2 bit `ptr` + 3 bit `grant` + 1 bit `busy`)
+ 29 cell tổ hợp, diện tích `f07_rr_arbiter` = **327,8144 µm²**. Yosys 0.33 không báo
`ERROR` (26 cảnh báo thường lệ của `abc`/liberty).

Lệnh đã chạy để xác minh:

```bash
D=.../out/F07_FSM_trong_tai_bus_ba_chu_theo_vong_tron
T=$(mktemp -d)
LIB=.../sky130hd.lib

# (a) mo hinh chuan Python
python3 $D/05_VERIFICATION/golden_model/reference_model.py

# (b) bien dich + mo phong
iverilog -g2012 -o $T/sim.vvp \
   $D/04_IMPLEMENTATION/rtl/*.sv \
   $D/05_VERIFICATION/testbench/*.sv
cd $T && vvp sim.vvp | tail -20

# (c) tong hop
yosys -Q -p "read_verilog -sv $D/04_IMPLEMENTATION/rtl/*.sv; \
   hierarchy -check -top f07_rr_arbiter; proc; opt; fsm; opt; memory; opt; \
   techmap; opt; dfflibmap -liberty $LIB; abc -liberty $LIB; setundef -zero; \
   splitnets; opt_clean -purge; stat -liberty $LIB"
```

> Ghi chú: `05_VERIFICATION/golden_model/` của F07 không có file `.sv`, nên glob đó được bỏ.
> `05_VERIFICATION/testbench/properties.sv` biên dịch được vì toàn bộ nội dung nằm trong
> `` `ifdef F07_SVA `` (không định nghĩa ⇒ file rỗng).

## 4. Cách quay lui

```bash
cp 08_ORIGINAL_SOURCE/rtl/*            04_IMPLEMENTATION/rtl/
cp 08_ORIGINAL_SOURCE/golden_model/*   05_VERIFICATION/golden_model/
cp 08_ORIGINAL_SOURCE/testbench/*      05_VERIFICATION/testbench/
```

## 5. Việc còn lại

Các mục sau của `known_issues.md` §9 **chưa** thuộc phạm vi đợt vá sửa lỗi này (đều là bổ
sung tính năng hoặc thay đổi giao diện, cần quyết định riêng của giảng viên):

- Bổ sung INV-2, INV-4, INV-5 vào `05_VERIFICATION/testbench/properties.sv`.
- Cổng `uo_out[4:3]` còn thiếu so với Charter (`functional_spec.md`) — **thay đổi giao diện
  module**, sẽ kéo theo sinh lại tài liệu tầng 02.
- Lỗ hổng "không có timeout cho `done`": nếu một chủ bus không bao giờ phát `done`, trọng
  tài kẹt vĩnh viễn ở `ACTIVE`. Đây là **thiếu sót đặc tả**, không phải lỗi cài đặt — vá nó
  đòi thêm bộ đếm timeout và một cổng cấu hình, tức đổi đặc tả. Để lại cho giảng viên.

## 6. Áp dụng lại (2026-09-24)

Một bước sinh tài liệu tự động (`generate2.py`) đã **chép mã nguồn gốc từ `runs/F07/work/`
đè lên** `04_IMPLEMENTATION/rtl/`, `05_VERIFICATION/golden_model/` và
`05_VERIFICATION/testbench/`, xoá sạch toàn bộ bản vá §2. Lỗi của bộ sinh đã được sửa; hai
bản vá dưới đây được **áp dụng lại nguyên văn** theo §2 của chính tài liệu này.

| Bản vá | File | Trạng thái |
|---|---|---|
| P-1 | `05_VERIFICATION/testbench/f07_tb.sv` | ✅ áp dụng lại |
| P-2 | `05_VERIFICATION/golden_model/reference_model.py` | ✅ áp dụng lại |

Không có bản vá nào chạm RTL, đúng như §1 đã ghi (`diff` giữa `08_ORIGINAL_SOURCE/rtl/` và
`04_IMPLEMENTATION/rtl/` không khác biệt).

**Kết quả xác minh lần này** (iverilog 12.0 / Yosys 0.33, cùng lệnh ở §3):

| Bước | Kết quả đo lại | Khớp §3? |
|---|---|---|
| Mô hình chuẩn Python | PASS — 6 ca, mã thoát 0 | ✅ |
| Biên dịch | PASS — 0 lỗi, 9 cảnh báo `sorry: constant selects` | ✅ |
| Mô phỏng | PASS — `F07 TB completed`, `$finish` tại t=196, không `$fatal` | ✅ |
| Tổng hợp | **36 cell / 7 FF (`dfxtp_1`) / 327,8144 µm²**, 0 `ERROR`, 26 cảnh báo | ✅ |

Toàn bộ số liệu **trùng khớp** bảng §3. Không có chênh lệch nào so với bản vá đã ghi.
