# UART VIP Requirements - as an Examplle

## What is this

This is a UVM-based UART VIP. The goal is simple — drive UART frames onto a line, monitor what comes back, and check if the data is correct. Nothing fancy, just a clean reusable component that can be dropped into different testbenches without much rework.

---

## What it needs to support

First version is 8N1 only:
- 8 data bits
- 1 start bit
- 1 stop bit
- no parity
- LSB first
- idle line = logic 1

Should be easy to extend later for parity, 2 stop bits, different data widths, error injection etc. but none of that is needed right now.

---

## Configuration

Everything should be configurable through a config object, not hardcoded. At minimum:
- active or passive mode
- clocks per bit (this sets the baud rate)
- data bits
- parity enable
- parity type (odd/even)
- stop bit count

Config object gets passed around using uvm_config_db. No direct hierarchical references.

---

## Interface

A SystemVerilog interface with at least:
- clk
- rst_n
- tx
- rx

Driver and monitor talk to DUT through virtual interface, not direct signal access.

Extra debug signals are also on the interface (parallel data vectors, valid pulses) so you can see what is happening in the wave without decoding the serial line manually.

---

## Transaction

One transaction = one UART frame. Fields:
- data byte (rand)
- parity_en, parity_odd, stop_bits (rand, used for config matching)
- parity_ok, framing_ok (filled by monitor after capture)

Same transaction type is used everywhere — sequence, driver, monitor, scoreboard. No separate types.

convert2string should print both hex and binary so it is easy to match against wave log.

---

## Driver

- takes items from sequencer
- drives start bit, data bits, stop bit in correct order
- timing comes from config object
- keeps line high when idle
- also sets parallel debug signals on the interface before driving, so the byte shows up as a vector in wave

---

## Monitor

- watches the rx line
- detects falling edge as start of frame
- samples bits at mid-point of each bit time
- checks stop bit for framing
- checks parity if enabled
- writes completed transaction to analysis port
- updates live debug signals on interface while frame is coming in (shift register fills up bit by bit, visible in wave)

---

## Agent

- always creates monitor
- creates sequencer and driver only in active mode
- passes config to all subcomponents

---

## Sequence

At least one sequence that sends N random bytes. Sequence also puts expected items into scoreboard mailbox while sending, so scoreboard can compare.

---

## Scoreboard

- gets expected items from mailbox (sequence puts them there)
- gets actual items from monitor via analysis fifo
- compares in order
- reports framing errors, parity errors, data mismatches separately
- prints pass/fail summary at end

---

## Environment

- contains agent and scoreboard
- distributes config
- connects monitor analysis port to scoreboard fifo

---

## Test

At least one smoke test:
- sets up config (8N1, active mode)
- gets virtual interface from config_db
- waits a bit after reset before starting
- runs sequence
- waits for DUT echo to complete
- drops objection

---

## What is NOT needed in first version

- functional coverage
- protocol assertions
- error injection
- separate TX/RX agents
- baud mismatch testing
- anything beyond 8N1

These can be added later. Architecture should not block it.

---

## File organization

One file per class, grouped by folder:

```
if/         uart_if.sv
common/     uart_seq_item.sv, uart_cfg.sv
agent/      uart_sequencer.sv, uart_driver.sv, uart_monitor.sv, uart_agent.sv
seq/        uart_tx_seq.sv
env/        uart_scoreboard.sv, uart_env.sv
tests/      uart_test.sv
example_dut/uart_dut.sv
tb/         example_tb_top.sv
scripts/    run_questa.sh, run_xrun.sh, clean.sh, files.f, how_to_run.txt
uart_vip_pkg.sv  (root, includes everything)
```
