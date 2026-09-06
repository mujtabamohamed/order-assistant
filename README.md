# OrderAssistant — Advanced Order Manager EA
## Features

- **Interactive GUI Panel** rendered directly on the MT5 chart — no external tools needed.
- **4 Order Types** — BUY, SELL, BUY STOP, SELL STOP via toggle buttons.
- **Batch Order Placement** — place multiple orders in one click, spaced by a configurable USD distance.
- **USD-based TP/SL** — enter Take Profit and Stop Loss in dollar amounts; the EA converts them to price distances automatically.
- **Smart Order Spacing** — orders are distributed at equal price intervals, each with its own adjusted TP/SL.
- **Dry Run Mode** — simulate all operations without touching live orders; results are logged to MT5's Expert tab.
- **Session-scoped Management** — each EA session generates a unique Magic Number, allowing targeted management of only the orders placed during the current session.
- **One-click Close Actions**:
  - Close **all** pending orders on the symbol
  - Close only **session-specific** pending orders
  - Close all **profitable** positions from the current session
  - Close all **loss-making** positions from the current session
- **Live Position Summary** — real-time display of total BUY and SELL lot sizes open on the symbol.

---

## Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpSymbol` | `EURUSD` | The trading symbol the EA operates on |
| `InpDryRun` | `false` | Enable simulation mode (no real orders placed) |

---

## GUI Controls

### Input Fields

| Field | Description |
|-------|-------------|
| **Lot Size** | Volume per order (e.g. `0.01`) |
| **Take Profit (USD)** | TP distance in USD per order. Set to `0` to disable |
| **Stop Loss (USD)** | SL distance in USD per order. Set to `0` to disable |
| **Number of Orders** | How many orders to place in one batch |
| **Space (USD)** | USD-equivalent price gap between each order in a batch |
| **Limit Price** | Optional entry price. Leave as `0` to auto-calculate from current market price |

### Direction Buttons

| Button | Order Type |
|--------|-----------|
| **BUY** | Market buy order |
| **SELL** | Market sell order |
| **BUY STOP** | Pending buy stop order |
| **SELL STOP** | Pending sell stop order |

### Action Buttons

| Button | Action |
|--------|--------|
| **PLACE ORDER** | Execute the configured order(s) |
| **CL ALL Pending (N)** | Cancel all N pending orders on the symbol |
| **CL Pending (N)** | Cancel only session-specific pending orders |
| **CL Profitable (N)** | Close all profitable session positions |
| **CL Loss (N)** | Close all loss-making session positions |

> Counts shown in parentheses update in real time on every tick.

---

## How It Works

### Order Placement Logic

1. The EA reads all input field values from the GUI.
2. If **Limit Price** is `0`, the first order price is auto-calculated relative to the current Ask/Bid price, offset by the configured **Space** amount.
3. Additional orders in a batch are staggered at equal **Space** intervals from the first order — in the direction that benefits the trade (e.g. lower for BUYs, higher for SELLs).
4. TP and SL are individually recalculated for each order in the batch based on each order's entry price.

### USD-to-Price Conversion

The EA converts USD amounts to price distances using the formula:

```
PriceDistance = (USD × TickSize) / (TickValue × LotSize)
```

This ensures accurate TP/SL/spacing calculations across different symbols, lot sizes, and account currencies.

### Magic Number & Session Tracking

On initialization, the EA generates a random **Magic Number** that identifies all orders placed in the current session. This allows the "CL Pending" and position close buttons to target only session-specific orders, leaving any pre-existing orders untouched.

---

## Dry Run Mode

When `InpDryRun = true`, no orders are sent to the broker. Instead, all actions are logged to MT5's **Experts** tab with a `[DRY RUN]` prefix. Use this to verify order logic and pricing before going live.

---

## Installation

1. Copy `orderAssistant.mq5` into your MetaTrader 5 `MQL5/Experts/` directory.
2. Open MetaEditor and compile the file (press **F7**).
3. Drag the EA onto any chart.
4. Set `InpSymbol` to your desired trading symbol.
5. Enable **Allow Automated Trading** in MT5.

---

## Requirements

- MetaTrader 5 (build 2361+)
- MQL5 standard library (`Trade\Trade.mqh`, `Trade\PositionInfo.mqh`, `Trade\OrderInfo.mqh`)
- A live or demo brokerage account with order execution enabled

---

## Notes & Warnings

> **Always test with Dry Run mode or on a demo account before using with real funds.**

- Confirm/cancel dialogs are shown before any destructive close operations.
- The EA uses `ORDER_FILLING_FOK` (Fill or Kill). Change this in `OnInit()` if your broker requires a different fill policy.
- Slippage tolerance is set to **10 points** by default.

---

## License

MIT — free to use, modify, and distribute.
