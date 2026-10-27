# F07 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng — ba khối chủ chia nhau một bus

Charter mục 1: *"Khối phân xử quyền dùng bus dữ liệu chung giữa ba khối trong một vi mạch
nhỏ."*

```
 ┌──────────┐      ┌──────────┐      ┌──────────┐
 │ MASTER 0 │      │ MASTER 1 │      │ MASTER 2 │     (ví dụ: CPU · DMA · khối ngoại vi)
 │          │      │          │      │          │
 └─┬──┬───┬─┘      └─┬──┬───┬─┘      └─┬──┬───┬─┘
   │  │   │          │  │   │          │  │   │
 req│  │done      req│  │done       req│  │done
   │  │   │          │  │   │          │  │   │
   │  │   │ grant    │  │   │ grant    │  │   │ grant
   │  │   ◀──────┐   │  │   ◀──────┐   │  │   ◀──────┐
   ▼  ▼          │   ▼  ▼          │   ▼  ▼          │
 ┌────────────────┴──────┴─────────┴──────┴──────────┴───────┐
 │  req[2:0]          done                   grant[2:0]      │
 │  ╔══════════════════════════════════════════════════════╗ │
 │  ║        ███  KHỐI F07 — TRỌNG TÀI ROUND-ROBIN  ███    ║ │
 │  ║   FSM giao dịch (IDLE/ACTIVE) + con trỏ ptr[1:0]     ║ │
 │  ╚══════════════════╤═══════════════════════════════════╝ │
 └─────────────────────┼─────────────────────────────────────┘
                       │ busy
                       ▼
 ═══════════════════════════════════════════════════════════════
   BUS DỮ LIỆU CHUNG   (địa chỉ · dữ liệu · điều khiển)
 ═══════════════════════════════════════════════════════════════
                       │
                       ▼
              ┌────────────────┐
              │  SLAVE (RAM,   │
              │  thanh ghi…)   │
              └────────────────┘
```

### Điều sơ đồ này làm rõ: F07 **không nằm trên đường dữ liệu**

Bus dữ liệu **không đi qua** F07. F07 chỉ phát tín hiệu `grant` để mở/đóng bộ đệm ba trạng
thái (hoặc chân chọn của mux) ở từng khối chủ. Hệ quả kiến trúc:

| Hệ quả | Vì sao |
|---|---|
| F07 rất nhỏ | **36 cell, 327,8144 µm²** đo được — không có đường dữ liệu rộng nào đi qua |
| F07 **không** là nút thắt thông lượng | Nó không chạm vào dữ liệu; chỉ cấp phép |
| Nhưng F07 **là** nút thắt về độ trễ giao dịch | Mỗi giao dịch tốn tối thiểu 2 chu kỳ (1 cấp + 1 nhả) vì `grant` là đầu ra đăng ký |
| Một lỗi ở F07 rất nguy hiểm | `grant` không one-hot ⟹ hai khối cùng lái bus ⟹ tranh chấp điện |

## 2. Ranh giới khối

| Hạng mục | Thuộc F07? | Ai lo |
|---|:-:|---|
| Chọn khối được cấp quyền | ✅ | F07 |
| Lưu thứ tự vòng tròn (`ptr`) | ✅ | F07 |
| Giữ quyền tới khi `done` | ✅ | F07 |
| Báo bus đang bận (`busy`) | ✅ | F07 |
| **Lái bus dữ liệu** | ❌ | Từng khối chủ (bộ đệm ba trạng thái ở khối đó) |
| **Phát `done` khi xong giao dịch** | ❌ | **Khối chủ đang được cấp quyền** |
| Giải mã địa chỉ, chọn slave | ❌ | Tầng ngoài |
| Đồng bộ hoá `req` từ domain clock khác | ❌ | Tầng ngoài |
| Timeout khi khối chủ treo | ❌ **và không ai lo** | ⚠️ **lỗ hổng** — xem §2.1 |

### 2.1 Nghĩa vụ hợp đồng của tầng ngoài — và một lỗ hổng chưa được vá

| # | Nghĩa vụ | Nếu vi phạm |
|---|---|---|
| 1 | `req[i]` giữ ổn định tới khi được cấp quyền | Có thể mất yêu cầu (`req` chỉ được lấy mẫu ở trạng thái `IDLE`) |
| 2 | **Khối được cấp quyền BẮT BUỘC phát `done`** trong thời gian hữu hạn | ⚠️ **Bus treo vĩnh viễn.** `busy` dính 1, hai khối kia bị bỏ đói tuyệt đối. |
| 3 | Không khối nào lái bus khi `grant[i] = 0` | Tranh chấp bus |
| 4 | `req`, `done` đồng bộ với `clk` | Metastability |
| 5 | `rst_n` giữ ≥ 1 chu kỳ khi clock đang chạy (reset **đồng bộ**) | F07 không được khởi tạo |

> **Nghĩa vụ số 2 là điểm yếu kiến trúc lớn nhất của F07.** Tính công bằng của round-robin
> chỉ đúng **với điều kiện** mọi khối chủ tuân thủ hợp đồng. RTL không có watchdog, không có
> timeout, không có đường huỷ quyền. Một khối chủ hỏng làm sụp đổ hoàn toàn tính chất mà
> Charter mục 9 yêu cầu chứng minh. Ghi nhận để thầy quyết định — **không tự sửa RTL**.

## 3. Phân loại — analog / digital / mixed

| Thành phần | Phân loại |
|---|---|
| F07, các khối chủ, slave | **Digital đồng bộ** |
| Bộ đệm ba trạng thái trên bus | Digital, nhưng có khía cạnh điện (tranh chấp = dòng ngắn mạch thật) |
| Toàn hệ thống | **Thuần digital** |

Bằng chứng F07 là digital tuần tự thuần: `synth_stat.txt` chỉ có standard cell
`sky130_fd_sc_hd`, `Number of memories: 0`; `power_report.txt` cho `Macro 0.0%`, `Pad 0.0%`.

> Một chi tiết đáng chú ý trong bảng cell: có **4 cell `lpflow_isobufsrc_1`**. Đây là cell
> đệm cách ly (isolation buffer) thuộc họ low-power của sky130. Yosys/`abc` chọn nó **không
> phải vì lý do power-domain** mà đơn giản vì nó có đặc tính delay/drive phù hợp — `abc` chỉ
> nhìn thư viện Liberty như một tập hàm logic có giá. Một trong bốn cell này (`_55_`) nằm
> trên đường tới hạn. Sinh viên đọc netlist hay hiểu nhầm chỗ này thành "thiết kế có
> power gating" — **không có**.

## 4. Vòng đời RTL → GDSII — trạng thái THẬT

Lấy từ `06_GDSII/physical_report.md` §1 và `brief/F07.md`.

```
 ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
 │ Đặc tả      │──▶│ RTL         │──▶│ Mô phỏng    │──▶│ Tổng hợp    │
 │ (Charter)   │   │ .sv         │   │ hành vi     │   │ Yosys       │
 │     ✅      │   │     ✅      │   │  ⚠️ FATAL   │   │     ✅      │
 └─────────────┘   └─────────────┘   └──────┬──────┘   └──────┬──────┘
                                            │                 │
                              known_issues.md│                 │ netlist.v
                              (lỗi TESTBENCH)│                 ▼
 ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
 │ STA         │──▶│ Công suất   │──▶│ Floorplan   │──▶│ Placement   │
 │ OpenSTA     │   │ OpenSTA     │   │ LibreLane   │   │ LibreLane   │
 │     ✅      │   │  ✅ ước lg. │   │     ⬜      │   │     ⬜      │
 └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘
                                                              │
 ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌──────┴──────┐
 │ GDS         │◀──│ LVS         │◀──│ DRC         │◀──│ CTS + Route │
 │     ⬜      │   │     ⬜      │   │     ⬜      │   │     ⬜      │
 └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘

 ⬛ KHÔNG ÁP DỤNG (Charter mục 3):
    ưu tiên động (đề J10) · nhiều bus · chia tách giao dịch ·
    analog transistor · physical design tự làm · sign-off · tape-out · chế tạo
```

### 4.1 Đọc sơ đồ vòng đời cho đúng

Khác với F06, **chuỗi bằng chứng của F07 KHÔNG bị đứt**: cả mô phỏng và tổng hợp đều chạy
trên cùng một top module `f07_rr_arbiter` (`f07_tb.sv` dòng 7 và `synth.ys` dòng 4 đều dùng
module này). Số liệu 36 cell / 7 FF / 327,8144 µm² **thuộc về đúng mạch** đã được mô phỏng.

Điểm ⚠️ ở ô "Mô phỏng" là **lỗi testbench**, không phải lỗi mạch:

| | |
|---|---|
| Phần đã chứng minh trên RTL | Chuỗi round-robin `M0→M1→M2→M0`; one-hot ×3; quyền không bị cướp; trạng thái rảnh sau reset |
| Phần **chưa** chứng minh | Phục hồi sau reset giữa chừng (TB dòng 74–80 — chưa chạy tới) |
| Phán xử | **Lỗi ở testbench** — `05_VERIFICATION/known_issues.md` §2 |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
