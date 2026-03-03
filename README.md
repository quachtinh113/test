# NowTrading Demon-Mode RSI Basket EA (MQL5)

EA cho MT5 theo chiến lược **"NowTrading Demon-Mode $20/30min"** cho **single symbol** (khuyến nghị EURUSD).

## Đường dẫn deliverables
- `src/NowTradingDemonRsiBasketEA.mq5`
- `src/lib/PipUtils.mqh`
- `src/lib/Indicators.mqh`
- `src/lib/BasketState.mqh`
- `src/lib/TradeUtils.mqh`

## Logic chính

### 1) Entry schedule
- Chỉ evaluate ENTRY tại phút **01** và **31** theo **terminal local time**.
- Nếu đang có basket active (position hoặc pending của EA, cùng symbol+magic+tag) => không mở basket mới.

### 2) Điều kiện vào lệnh (RSI14, closed bars)
- BUY:
  - RSI(H4) >= 55
  - RSI(H1) >= 55
  - RSI(M30) cross up 50: `prev <= 50 && curr > 50` (2 nến M30 đã đóng gần nhất)
- SELL:
  - RSI(H4) <= 45
  - RSI(H1) <= 45
  - RSI(M30) cross down 50: `prev >= 50 && curr < 50`
- Không trade nếu H4 hoặc H1 thuộc neutral 45..55.

### 3) Basket construction
Khi có tín hiệu:
- Mở market ngay: `0.15 + 0.15` lot
- Đặt 1 limit: `0.10` lot tại:
  - BUY: entry - 10 pips
  - SELL: entry + 10 pips
- Tag comment chuẩn: `NOWTRADING_DEMON_RSI_BASKET|...`

### 4) DCA
- Lot mỗi layer: `0.10`
- Spacing: `30 pips` từ `last_fill_price`
- Max DCA layers: `3`
- Chỉ cho phép khi:
  - Basket age < 6h
  - Free margin % >= 60
  - `dca_count < MaxDcaLayers`

### 5) Exit rules
- Basket TP: profit >= +20 USD => close all + cancel pending
- Hard stop: profit <= -250 USD => close all + cancel pending
- Emergency reversal (sau 12h):
  - BUY basket: RSI(H4)<45 và RSI(D1)<45 => close all
  - SELL basket: RSI(H4)>55 và RSI(D1)>55 => close all

### 6) Guards
- `MaxSpreadPips` block ENTRY (không block exit)
- `MaxBasketsPerDay` block ENTRY (vẫn quản lý basket active)
- `DryRunMode=true` => chỉ log, không gửi lệnh.

## Inputs mặc định quan trọng
- `InpMagicNumber = 20260302`
- `InpRsiPeriod = 14`
- `InpMaxSpreadPips = 2.0`
- `InpMinFreeMarginPercent = 60`
- `InpMaxBasketsPerDay = 6`
- `InpMaxDcaLayers = 3`
- `InpBasketTpUsd = 20`
- `InpHardStopUsd = -250`
- `InpDryRunMode = false`

## Hướng dẫn compile (MetaEditor)
1. Mở MetaEditor.
2. Copy thư mục `src` vào `MQL5/Experts/NowTradingDemon/` (hoặc giữ nguyên cấu trúc include tương đối).
3. Mở file `NowTradingDemonRsiBasketEA.mq5`.
4. Nhấn **Compile**.
5. Đảm bảo không có lỗi compile.

## Hướng dẫn backtest nhanh
1. MT5 Strategy Tester -> Expert: `NowTradingDemonRsiBasketEA`.
2. Symbol: EURUSD, model "Every tick based on real ticks".
3. Set spread phù hợp (<=2 pips để thấy entry thường xuyên).
4. Bật visualization để kiểm tra mốc phút 01/31 và hành vi DCA/exit.
5. Khuyến nghị test riêng từng guard:
   - Spread cao để xác nhận block entry
   - DryRunMode=true để audit log quyết định
   - MaxBasketsPerDay thấp (ví dụ 1) để test daily cap

## Ghi chú kỹ thuật
- Pip math hỗ trợ chuẩn 5-digit/3-digit qua `PipSize/PipToPrice/PriceToPips`.
- RSI dùng **closed bars** (`shift=1`, M30 cross dùng `shift=1,2`).
- Có retry cho trade gửi lệnh và xử lý retcode có thể retry.
