# UART VIP Example Test Procedure

## Before you start

Make sure you have:
- all VIP source files
- a DUT connected to the UART interface (the example echo DUT works fine for this)
- UVM library available
- simulator (Questa or Xcelium)
- scripts set up and executable

---

## How to run

```bash
cd scripts
chmod +x run_questa.sh run_xrun.sh clean.sh

# Questa:
./run_questa.sh

# Xcelium:
./run_xrun.sh

# Clean build artifacts:
./clean.sh
```

Compile order matters:
1. `uart_if.sv`
2. `uart_vip_pkg.sv`
3. `uart_dut.sv`
4. `example_tb_top.sv`

---

## What the test does, step by step

1. Reset is applied and held for a few clocks
2. Reset releases, testbench waits ~50 clocks before doing anything
3. Config is set up — 8N1, active mode, clocks_per_bit=16
4. Virtual interface is passed to test via config_db
5. TX sequence starts, sends N random bytes one by one
6. Each byte also goes into scoreboard expected mailbox before being driven
7. Driver converts each item to start+data+stop bits on the tx line
8. DUT receives the frame, waits ECHO_DELAY clocks, sends it back
9. Monitor watches the rx line, reconstructs each frame
10. Scoreboard compares expected vs actual for each byte
11. Test waits for all echoes to finish, then drops objection
12. Scoreboard prints final pass/fail summary

---

## Tests

### Smoke test — basic 8N1 transfer

**What it checks:** driver sends a byte, DUT echoes it back, monitor captures it, scoreboard says match.

**Config:** 8 data bits, no parity, 1 stop bit, clocks_per_bit=16

**Steps:**
1. Run the test
2. Check console output — each byte should print "PASS [N] data=8'hXX (XXXXXXXX)"
3. Check scoreboard summary at end — FAIL count should be 0
4. Open wave, check drv_tx_data and mon_rx_data match for each transaction

**Pass if:**
- no UVM errors
- scoreboard shows 0 fails
- wave looks clean — start bit, 8 data bits, stop bit visible for each frame

---

### Multi-byte directed test

**What it checks:** several bytes in a row, none are lost, order is correct.

**Steps:**
1. Set n_trans to something like 8 or 16
2. Run and check that scoreboard matched all of them
3. In wave, check frames are back to back with no garbage between them

**Pass if:**
- pass count matches n_trans
- no dropped or extra transactions

---

### Randomized data test

**What it checks:** random byte values work, not just 0x00 or 0xFF.

**Steps:**
1. Let sequence randomize data (default behavior)
2. Run a few times with different seeds
3. Check scoreboard each time

**Pass if:**
- all randomized values matched
- no framing or parity errors on a clean line

---

### Framing error test

**What it checks:** monitor correctly flags bad stop bit.

**Steps:**
1. Force rx line low during stop bit (or modify driver to not send stop bit)
2. Check that framing_ok comes back 0 in the monitor
3. Check that scoreboard logs a framing error, not a data mismatch

**Pass if:**
- framing_ok = 0 in captured transaction
- scoreboard prints FRAMING ERROR, not DATA MISMATCH

---

### Reset during transfer test

**What it checks:** asserting reset mid-frame does not leave VIP in broken state.

**Steps:**
1. Start sending a frame
2. Assert rst_n = 0 mid-frame
3. Release reset
4. Send a clean frame after reset
5. Check the post-reset frame is captured and matched correctly

**Pass if:**
- no fatal errors
- post-reset transaction is captured cleanly
- no leftover state from the interrupted frame

---

## What to look at in the wave

These are the most useful signals to add to your wave window:

| Signal | What it shows |
|--------|--------------|
| u_if.tx | raw serial line going into DUT |
| u_if.rx | raw serial line coming back from DUT |
| u_if.drv_tx_data | byte driver is sending, as a vector |
| u_if.drv_tx_valid | pulses when driver starts a new byte |
| u_if.mon_rx_shift | byte building up bit by bit as monitor samples |
| u_if.mon_rx_bit_cnt | which bit position monitor is on right now |
| u_if.mon_rx_data | final captured byte, as a vector |
| u_if.mon_rx_valid | pulses when monitor finishes capturing a byte |
| dut_rx_state | DUT RX FSM state (0=idle 1=start 2=data 3=stop) |
| dut_tx_state | DUT TX FSM state (same encoding) |
| dut_rx_shift | byte filling up inside DUT as it receives |
| dut_tx_shift | byte DUT is currently sending back |

---

## Pass/fail criteria

**PASS:**
- simulation finishes without fatal errors
- scoreboard FAIL count is 0
- no unexpected UVM errors in log
- wave looks correct for the test scenario

**FAIL:**
- any scoreboard mismatch
- unexpected framing or parity error
- simulation timeout
- UVM_FATAL anywhere in log
