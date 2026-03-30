# UART VIP Requirements — v2

## What is this

A UVM-based UART VIP. Drives UART frames onto a serial line, monitors what comes back, checks data in a scoreboard. Designed to be reusable — drop it into any testbench with minimal changes.

v2 adds functional coverage, SVA protocol assertions, and error injection on top of the v1 foundation.

---

## Protocol support

8N1 with optional parity and configurable stop bits:
- 8 data bits (configurable via `data_bits`)
- 1 start bit
- 1 or 2 stop bits
- optional even/odd parity
- LSB first
- idle line = logic 1

---

## Configuration

Everything goes through `uart_cfg`, no hardcoded values.

| Field | Description |
|-------|-------------|
| `vif` | virtual interface handle, set from tb_top |
| `mode` | `UART_ACTIVE` or `UART_PASSIVE` |
| `clocks_per_bit` | sets baud rate (baud = clk_freq / clocks_per_bit) |
| `data_bits` | data width, default 8 |
| `parity_en` | 0 = no parity, 1 = parity enabled |
| `parity_odd` | 0 = even parity, 1 = odd parity |
| `stop_bits` | 1 or 2 |

Config passed via `uvm_config_db`. No direct hierarchical references.

---

## Interface (`uart_if`)

Serial lines:

| Signal | Direction | Description |
|--------|-----------|-------------|
| `tx` | VIP → DUT | serial output driven by driver |
| `rx` | DUT → VIP | serial input watched by monitor |

Debug signals (parallel vectors, for wave viewing):

| Signal | Description |
|--------|-------------|
| `drv_tx_data` | byte driver is about to send, as vector |
| `drv_tx_valid` | 1-cycle pulse when driver starts a new frame |
| `mon_rx_shift` | live shift register filling up bit by bit |
| `mon_rx_bit_cnt` | which bit position monitor is on |
| `mon_rx_data` | fully captured byte |
| `mon_rx_valid` | 1-cycle pulse when monitor finishes a frame |

---

## Transaction (`uart_seq_item`)

One transaction = one UART frame.

| Field | Type | Description |
|-------|------|-------------|
| `data` | rand logic [7:0] | payload byte |
| `parity_en` | rand logic | mirrors config |
| `parity_odd` | rand logic | mirrors config |
| `stop_bits` | rand logic [1:0] | mirrors config |
| `parity_ok` | bit | set by monitor — 1 if parity matched |
| `framing_ok` | bit | set by monitor — 1 if stop bit was high |

`convert2string` prints both hex and binary for easy wave matching.

---

## Error Injection (`uart_error_seq_item`)

Extends `uart_seq_item` with injection control flags. Used with `uart_error_driver`.

| Flag | What it does |
|------|-------------|
| `inject_bad_stop` | drives stop bit as 0 → framing error at DUT |
| `inject_bad_parity` | flips computed parity bit → parity error at DUT |
| `inject_glitch` | pulls TX low for 1 cycle then back high (false start) |
| `inject_break` | holds TX low for 2 full frame durations (UART break) |

Default constraint keeps all flags at 0, so existing tests are unaffected. Lift with `c_no_error_default.constraint_mode(0)`.

---

## Driver (`uart_driver`)

- gets items from sequencer
- drives start bit, data bits, optional parity, stop bit(s)
- timing from `uart_cfg`
- holds line high when idle
- sets `drv_tx_data` and `drv_tx_valid` debug signals before driving

## Error Driver (`uart_error_driver`)

Extends `uart_driver`. Activated via factory override. On plain `uart_seq_item` calls `super.drive_item()` unchanged. On `uart_error_seq_item` injects the requested error at pin level.

---

## Monitor

- watches `rx` line
- detects falling edge → start bit → samples data bits at mid-point
- checks stop bit → sets `framing_ok`
- checks parity if enabled → sets `parity_ok`
- writes completed `uart_seq_item` to analysis port
- updates live debug signals throughout frame capture

---

## Agent

- always creates monitor
- creates sequencer + driver only in active mode
- passes config to all subcomponents

---

## Sequences

| Sequence | Description |
|----------|-------------|
| `uart_tx_seq` | sends N bytes from `data_q`, loaded by test |
| `uart_bad_stop_seq` | single frame with injected bad stop bit |
| `uart_bad_parity_seq` | single frame with flipped parity (parity_en must be 1) |
| `uart_glitch_seq` | 1-cycle false start glitch, followed by valid frame |
| `uart_break_seq` | TX held low for 2× frame duration (UART break) |
| `uart_error_mix_seq` | all error types in order, clean recovery frames between each |

---

## Scoreboard

- dual analysis import ports: `actual_export` (monitor) and `expected_export` (test)
- items queued internally, matched in arrival order
- reports framing error, parity error, data mismatch separately
- `check_phase` flags unmatched items
- prints PASS/FAIL summary in `report_phase`

---

## Functional Coverage (`uart_coverage`)

UVM subscriber connected to monitor's analysis port.

| Covergroup | What it measures |
|------------|-----------------|
| `cg_data_value` | corner bytes (0x00, 0xFF, 0x55, 0xAA), walking-1/0, quartile ranges |
| `cg_frame_integrity` | `framing_ok` × `parity_ok` cross — all 4 outcomes |
| `cg_parity_cfg` | `parity_en` × `parity_odd` cross, impossible combos in `ignore_bins` |
| `cg_stop_bits` | 1-stop and 2-stop frames |
| `cg_data_transitions` | back-to-back byte transitions (0x00→0xFF, same byte twice, etc.) |
| `cg_error_types` | confirms error injection scenarios are exercised |

Coverage summary printed in `report_phase`.

---

## SVA Protocol Assertions (`uart_assertions`)

Bound to `uart_if` via `uart_assertions_bind.sv`. No DUT or testbench changes needed.

| Group | Checks |
|-------|--------|
| Reset / Idle | TX and RX high after reset; no X/Z on either line |
| Start Bit | low for full `CLKS_PER_BIT`; TX was idle before |
| Stop Bit | arrives within frame window; high for minimum `CLKS_PER_BIT` |
| Frame Timing | `drv_tx_valid` and `mon_rx_valid` are single-cycle pulses; echo arrives within latency bound |
| Data Validity | `mon_rx_data` is not X/Z when `mon_rx_valid` pulses |

Six cover properties track: complete TX frame, back-to-back frames, corner byte values, framing error exercised.

---

## Environment

- contains agent, scoreboard, and coverage subscriber
- distributes config via `uvm_config_db`
- connects monitor analysis port to both scoreboard and coverage

---

## Tests

| Test | Category | Description |
|------|----------|-------------|
| `uart_test` | CLEAN | smoke test — 8N1, 3 directed bytes, echo checked |
| `uart_error_test` | EXPECT | all 4 error types via `uart_error_mix_seq`; UVM_ERROR expected for each fault, UVM_FATAL never acceptable |

---

## Regression

`scripts/run_xrun_regression.sh` compiles once then runs all tests against the same snapshot. CLEAN tests must produce zero UVM_ERROR and zero UVM_FATAL. EXPECT tests may produce UVM_ERROR but never UVM_FATAL.

---

## File organization

```
if/
  uart_if.sv
  uart_assertions.sv
  uart_assertions_bind.sv
common/
  uart_seq_item.sv
  uart_error_seq_item.sv
  uart_cfg.sv
agent/
  uart_sequencer.sv
  uart_driver.sv
  uart_error_driver.sv
  uart_monitor.sv
  uart_agent.sv
seq/
  uart_tx_seq.sv
  uart_error_seq.sv
env/
  uart_scoreboard.sv
  uart_coverage.sv
  uart_env.sv
tests/
  uart_test.sv
  uart_error_test.sv
example_dut/
  uart_dut.sv
tb/
  example_tb_top.sv
scripts/
  run_xrun.sh
  run_xrun_regression.sh
  run_questa.sh
  clean.sh
  files.f
  how_to_run.txt
doc/
  requirements.md
  test_procedure.md
  test_report.md
uart_vip_pkg.sv
```
