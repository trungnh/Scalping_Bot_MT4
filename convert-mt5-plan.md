# Kế hoạch chuyển đổi Indicators M1, M5 và EAs sang MT5 (MQL5)

Kế hoạch này chi tiết việc chuyển đổi 2 indicator xác định cấu trúc (`Scapling_Indicator_M1`, `Scapling_Indicator_M5`) và 2 EA (`BigDick_DCA_Signal`, `BigDick_DCA`) từ MT4 (MQL4) sang MT5 (MQL5). Mục tiêu cao nhất là duy trì **100% logic hiện tại** và khắc phục triệt để các vấn đề về độ trễ entry thông qua cơ chế của MT5.

---

## 1. Yêu cầu & Lưu ý Quan trọng từ User (User Review Required)

> [!IMPORTANT]
> * **Tài khoản Hedging trong MT5**: EA DCA chạy lưới lệnh đa chiều bắt buộc phải chạy trên tài khoản **MT5 Hedging** (cho phép nhiều vị thế Buy/Sell cùng lúc trên một cặp tiền), không thể chạy trên tài khoản Netting. Tài khoản Exness mặc định thường là Hedging.
> * **Giữ nguyên 9 Indicator Buffers**: Chúng ta không sử dụng bản Pine Script port rút gọn (chỉ có 3 buffers) hiện tại trong thư mục MT5. Phiên bản port mới của M1 và M5 sẽ giữ nguyên **9 buffers** gốc để truyền dữ liệu cấu trúc (CHOCH, BOS, OB, ATR Count) chính xác cho EA qua buffer.
> * **Sử dụng CopyBuffer thay cho iCustom cũ**: Thay vì gọi `iCustom()` liên tục mỗi tick làm chậm EA, bản MT5 sẽ tạo indicator handles trong `OnInit()` và dùng `CopyBuffer()` tốc độ cao để lấy dữ liệu.

---

## 2. Chiến lược Ánh xạ API MQL4 sang MQL5 (MQL5 Parity Mapping)

Để đảm bảo không sai lệch logic giao dịch, chúng ta sẽ định nghĩa các hàm wrapper tương thích MQL4 trong code MT5:

| MQL4 (Cũ) | MQL5 (Mới) | Giải pháp Porting / Wrappers |
| :--- | :--- | :--- |
| `iCustom()` (Mỗi tick) | `iCustom()` (Handle-based) + `CopyBuffer()` | Tạo handles trong `OnInit()`. Đọc dữ liệu bằng hàm helper sử dụng `CopyBuffer()`. |
| `iClose()`, `iHigh()`, `iLow()`, `iTime()` | `CopyClose()`, `CopyHigh()`, etc. | Viết các hàm helper tương thích: `iCloseMQL4()`, `iHighMQL4()`, `iTimeMQL4()`, và `iBarShiftMQL4()`. |
| `OrderSend()`, `OrderModify()` | Class `CTrade` | Sử dụng `#include <Trade\Trade.mqh>`. Gọi `trade.Buy()`, `trade.Sell()`, `trade.PositionModify()` để đặt lệnh. |
| `OrderSelect()`, `OrdersTotal()`, `OrderType()` | Class `CPositionInfo` | Duyệt qua các vị thế đang chạy bằng `PositionsTotal()` và lấy thuộc tính của Position qua `PositionGet...`. |
| `ObjectSetText()` | `ObjectSetString(..., OBJPROP_TEXT, ...)` | Cập nhật hàm vẽ `Draw()` và `RectLabelCreate()` theo chuẩn MT5. |

---

## 3. Danh sách các File cần thay đổi & tạo mới

### Component 1: MT5 Custom Indicators
Chúng ta sẽ triển khai 2 indicator trong thư mục MT5 Indicators:

#### [NEW] [Scapling_Indicator_M1.mq5](file:///c:/Users/Admin/AppData/Roaming/MetaQuotes/Terminal/CE1A01FB406CE08661396411159D4591/MQL5/Indicators/Scapling_Indicator_M1.mq5)
* Chuyển đổi chính xác logic quét cấu trúc M1 từ `Scapling_Indicator_M1.mq4`.
* Cấu hình **9 buffers** truyền dữ liệu tính toán.
* Giữ nguyên giới hạn: `BOS >= 2` chặn entry, nhãn vẽ `"1CHoCH"` và `"1BOS"`.

#### [NEW] [Scapling_Indicator_M5.mq5](file:///c:/Users/Admin/AppData/Roaming/MetaQuotes/Terminal/CE1A01FB406CE08661396411159D4591/MQL5/Indicators/Scapling_Indicator_M5.mq5)
* Chuyển đổi logic cấu trúc M5 từ `Scapling_Indicator_M5.mq4`.
* Cấu hình **9 buffers**.
* Giữ nguyên giới hạn: `BOS >= 3` chặn entry, nhãn vẽ `"5CHoCH"` và `"5BOS"`.

---

### Component 2: MT5 Expert Advisors
Chúng ta sẽ triển khai 2 EA trong thư mục MT5 Experts:

#### [NEW] [BigDick_DCA_Signal.mq5](file:///c:/Users/Admin/AppData/Roaming/MetaQuotes/Terminal/CE1A01FB406CE08661396411159D4591/MQL5/Experts/BigDick_DCA_Signal.mq5)
* Phiên bản MT5 của EA DCA Signal.
* Khởi tạo các handle cho M1 và M5 indicator trong `OnInit()`.
* **Logic Giao dịch**: Kế thừa nguyên vẹn logic lọc Trend, logic xác nhận `BOS 1 + ATR Candle` (không vào lệnh nếu nến tạo BOS trùng với nến ATR).
* **Độ trễ tối thiểu**: Đảm bảo `doAction()` chạy trước khi cập nhật UI để lệnh được gửi đi ngay lập tức tại đầu nến.

#### [NEW] [BigDick_DCA.mq5](file:///c:/Users/Admin/AppData/Roaming/MetaQuotes/Terminal/CE1A01FB406CE08661396411159D4591/MQL5/Experts/BigDick_DCA.mq5)
* Phiên bản MT5 của EA DCA Grid (EA quản lý lưới lệnh thủ công/bên ngoài).
* Duy trì thứ tự thực thi: `doAction()` chạy trước, vẽ UI status board chạy sau.

---

## 4. Kế hoạch Kiểm thử & Xác nhận (Verification Plan)

### Kiểm thử Tự động (Compile & Log)
* Biên dịch toàn bộ file `.mq5` bằng MT5 MetaEditor:
  - Biên dịch `Scapling_Indicator_M1.mq5` & `Scapling_Indicator_M5.mq5`
  - Biên dịch `BigDick_DCA_Signal.mq5` & `BigDick_DCA.mq5`
* Đảm bảo **0 lỗi (0 errors)**, không có cảnh báo nghiêm trọng ảnh hưởng logic.

### Kiểm thử Thủ công (Manual Check)
1. **So sánh Chart**: Kéo indicator M1 và M5 bản MT5 lên biểu đồ. So sánh các điểm vẽ CHOCH, BOS và vùng Order Blocks trực quan side-by-side với bản MT4 để kiểm tra tính đồng bộ.
2. **Chạy Backtest (Strategy Tester)**: Chạy EA DCA Signal trên MT5 Strategy Tester để:
   - Xác nhận lệnh L1 Buy/Sell vào chính xác ở giá mở cửa của cây nến tiếp theo nến ATR.
   - Xác nhận cơ chế chặn vào lệnh khi nến BOS 1 trùng nến ATR hoạt động đúng.
   - Kiểm tra các lệnh lưới DCA mở đúng khoảng cách pips và hệ số nhân lot.

---

## 5. Câu hỏi Làm rõ cho User (Open Questions)

1. **Ủy quyền tài khoản giao dịch**: Bạn có xác nhận tài khoản MT5 của mình là loại tài khoản **Hedging** không?
2. **Cách đặt lệnh lưới (DCA)**: Khi EA mở lưới lệnh DCA, các lệnh tiếp theo nên được gửi theo dạng **Đặt trực tiếp (Market Order)** ngay khi đạt khoảng cách hay dùng **Lệnh chờ (Limit/Stop Order)** để tối ưu hóa tốc độ khớp lệnh của sàn? (Hiện tại bản MT4 dùng Market Order trực tiếp khi check khoảng cách).
3. **Hành vi nút bấm UI**: Các nút đóng lệnh nhanh trên màn hình (Close All, Close Buy, Close Sell, Move to BE) sẽ đóng vị thế bằng cách gửi lệnh đóng đồng thời tới sàn (MT5 hỗ trợ gửi bất đồng bộ rất nhanh). Bạn có muốn giữ nguyên giao diện nút bấm và màu sắc như bản MT4 cũ không?
