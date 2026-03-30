# UART VIP Test Procedure — v2

## Before you start

Make sure you have:
- all VIP source files (v2 tree)
- simulator — Questa or Xcelium
- UVM library available
- scripts marked executable

```bash
cd scripts
chmod +x run_xrun.sh run_xrun_regression.sh run_questa.sh clean.sh
```

---

## How to run a single test

```bash
cd scripts

# Default — runs uart_test
./run_xrun.sh

# Run a specific test
./run_xrun.sh uart_error_test

# Override verbosity
./run_xrun.sh uart_test UVM_MEDIUM

# Questa
./run_questa.sh
```

## How to run full regression

```bash
cd scripts
./run_xrun_regression.sh
```

Compiles once, runs all tests against the same snapshot. Results go to `regression_summary.log`. Per-test logs: `regression_<testname>.log`.

---

## Compile order

```
1. uart_if.sv
2. uart_assertions.sv
3. uart_assertions_bind.sv
4. uart_vip_pkg.sv
5. uart_dut.sv
6. example_tb_top.sv
```

All of this is handled by `files.f`. You do not need to set it manually.

---

## Test descriptions

### `uart_test` — CLEAN

Smoke test. Sends 3 directed bytes (0xE6, 0xA5, 0x3C) through the echo DUT and checks that each one comes back correctly.

**Config:** 8 data bits, no parity, 1 stop bit, `clocks_per_bit=16`, `ECHO_DELAY=10`

**Pass criteria:**
- zero UVM_ERROR
- zero UVM_FATAL
- scoreboard shows `PASS=3 FAIL=0`
- coverage summary prints at end of sim

**What to check in wave:**

| Signal | Expected |
|--------|----------|
| `u_if.tx` | start bit → 8 data bits → stop bit for each frame |
| `u_if.drv_tx_valid` | 1-cycle pulse at start of each frame |
| `u_if.mon_rx_data` | matches `drv_tx_data` for each frame |
| `u_if.mon_rx_valid` | 1-cycle pulse when each echo is captured |

---

### `uart_error_test` — EXPECT

Error injection test. Runs `uart_error_mix_seq`, which sends the following sequence:

```
clean(AA) → bad_stop(DE) → clean(55) → bad_parity(BE) →
clean(CC) → glitch+clean(AB) → clean(12) → break → clean(FF)
```

**Pass criteria:**
- zero UVM_FATAL
- scoreboard logs `FRAMING ERROR` for bad_stop frame — this is expected and correct
- scoreboard logs `PARITY ERROR` for bad_parity frame — expected
- clean frames before and after each error match correctly
- coverage `cg_error_types` shows both `framing_err` and `parity_err` bins hit

**What to check in wave:**

| Scenario | What to look for |
|----------|-----------------|
| Bad stop bit | stop bit position on `tx` is 0 instead of 1; monitor sets `framing_ok=0` |
| Bad parity | parity bit is flipped; monitor sets `parity_ok=0` |
| Glitch | single-cycle low pulse on `tx` before the real start bit; assertion `AST_START_BIT_WIDTH` fires |
| Break | `tx` held low for ~320 cycles (2 frame lengths); DUT recovers and echoes clean(FF) after |

---

## Assertion behavior

SVA assertions are always active when the sim is running. Expected assertion firings:

| Test | Assertion | Expected? |
|------|-----------|-----------|
| `uart_test` | none | no assertions should fire |
| `uart_error_test` (glitch) | `AST_START_BIT_WIDTH` | yes — glitch is 1 cycle, shorter than `CLKS_PER_BIT` |
| `uart_error_test` (bad stop) | `AST_STOP_BIT_ARRIVES` | yes — stop bit arrives as 0 |

Any other assertion firing in `uart_test` is a real bug.

---

## Coverage goals

| Covergroup | Minimum target |
|------------|---------------|
| `cg_data_value` | 70% (corner + walking bins need directed stimulus) |
| `cg_frame_integrity` | 100% (both tests together hit all 4 cross bins) |
| `cg_parity_cfg` | 50% (parity-off covered by uart_test; parity-on by uart_error_test) |
| `cg_stop_bits` | 50% (1-stop covered; 2-stop needs additional directed test) |
| `cg_data_transitions` | 30% (improve by adding random sequence) |
| `cg_error_types` | 100% after uart_error_test |

---

## What to look at in the wave

| Signal | What it shows |
|--------|--------------|
| `u_if.tx` | raw serial TX driven by VIP |
| `u_if.rx` | raw serial RX echoed by DUT |
| `u_if.drv_tx_data` | byte driver is sending, as vector |
| `u_if.drv_tx_valid` | pulses when driver starts a new byte |
| `u_if.mon_rx_shift` | byte building up bit by bit as monitor samples |
| `u_if.mon_rx_bit_cnt` | which bit position monitor is on |
| `u_if.mon_rx_data` | final captured byte |
| `u_if.mon_rx_valid` | pulses when monitor finishes capturing a byte |
| `dut_rx_state` | DUT RX FSM — 0=idle 1=start 2=data 3=stop |
| `dut_tx_state` | DUT TX FSM — same encoding |
| `dut_rx_shift` | byte filling up inside DUT |
| `dut_tx_shift` | byte DUT is currently echoing |

---

## Pass / Fail summary

**PASS:**
- simulation finishes without timeout
- scoreboard FAIL count is 0 for CLEAN tests
- no unexpected UVM_FATAL anywhere
- no unexpected UVM_ERROR in CLEAN tests
- expected UVM_ERRORs present in EXPECT tests (bad_stop, bad_parity)

**FAIL:**
- any UVM_FATAL
- unexpected UVM_ERROR in `uart_test`
- missing UVM_ERROR in `uart_error_test` (means error wasn't actually injected)
- simulation timeout
- scoreboard unmatched item at `check_phase`
