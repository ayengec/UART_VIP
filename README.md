# UART VIP

A UVM-based UART verification component, UART UVC. Drives UART frames onto a serial line, monitors what comes back, and checks the data in a scoreboard. First version is 8N1 only.

Comes with an example echo DUT so you can run it and see something working right away.

---

## How to run

```bash
cd scripts
chmod +x run_questa.sh run_xrun.sh clean.sh

# Questa:
./run_questa.sh

# Xcelium:
./run_xrun.sh

# Clean:
./clean.sh
```

Open EPWave or your simulator's wave viewer after running. Make sure "Open EPWave after run" is checked if you are on EDA Playground.

---

## Folder structure

```
uart_vip/
├── if/
│   └── uart_if.sv              interface, serial lines + parallel debug signals
│
├── common/
│   ├── uart_seq_item.sv        transaction class, one item = one UART frame
│   └── uart_cfg.sv             config class, baud rate / parity / mode etc.
│
├── agent/
│   ├── uart_sequencer.sv       standard UVM sequencer
│   ├── uart_driver.sv          converts items to pin-level waveform
│   ├── uart_monitor.sv         watches rx line, reconstructs frames
│   └── uart_agent.sv           puts sequencer+driver+monitor together
│
├── seq/
│   └── uart_tx_seq.sv          sends N random bytes, also feeds scoreboard mailbox
│
├── env/
│   ├── uart_scoreboard.sv      compares expected vs actual, reports pass/fail
│   └── uart_env.sv             agent + scoreboard, connects analysis ports
│
├── tests/
│   └── uart_test.sv            smoke test, 8N1, active mode
│
├── example_dut/
│   └── uart_dut.sv             simple echo DUT for trying out the VIP
│
├── tb/
│   └── example_tb_top.sv       testbench top, clk/rst/DUT/UVM start/wave dump
│
├── scripts/
│   ├── run_questa.sh           compile and run with Questa
│   ├── run_xrun.sh             compile and run with Xcelium
│   ├── clean.sh                remove all build artifacts
│   ├── files.f                 file list for compilation
│   └── how_to_run.txt          quick start instructions
│
├── doc/
│   ├── requirements.md         what the VIP needs to do
│   ├── test_procedure.md       how to run and check each test
│   └── test_report.md          template for filling in results
│
└── uart_vip_pkg.sv             package, includes all classes in correct order
```

---

## Compile order

```
1. uart_if.sv
2. uart_vip_pkg.sv
3. uart_dut.sv
4. example_tb_top.sv
```

`uart_if.sv` must come before the package because the package uses a virtual interface handle. Everything else is included inside the package in the right order already.

---

## Debug signals in wave

The interface has extra parallel signals so you do not have to decode the serial line manually.

| Signal | What it shows |
|--------|--------------|
| u_if.drv_tx_data | byte driver is currently sending, as a vector |
| u_if.drv_tx_valid | 1-cycle pulse when driver starts a new byte |
| u_if.mon_rx_shift | byte building up bit by bit as monitor samples |
| u_if.mon_rx_bit_cnt | which bit position the monitor is on right now |
| u_if.mon_rx_data | full captured byte as a vector |
| u_if.mon_rx_valid | 1-cycle pulse when monitor finishes a frame |
| dut_rx_state | DUT RX FSM — 0=idle 1=start 2=data 3=stop |
| dut_tx_state | DUT TX FSM — same encoding |
| dut_rx_shift | byte filling up inside DUT while receiving |
| dut_tx_shift | byte DUT is currently echoing back |

---

## What the echo DUT does

Receives a byte over UART, waits ECHO_DELAY clocks, sends it back. That is it. It is just there so the VIP has something to talk to. In a real project you would swap it out for your actual DUT.

Parameters:
- `DATA_BITS` — data width (default 8)
- `ECHO_DELAY` — clocks to wait before echoing (default 10)
- `CLKS_PER_BIT` — number of clock cycles per one UART bit period.
  This is how you set the baud rate. Formula is:
```
  baud rate = clock frequency / CLKS_PER_BIT
```

  Example: if your clock is 100 MHz and CLKS_PER_BIT is 16:
```
  100,000,000 / 16 = 6,250,000 baud  (6.25 Mbaud)
```

  If you want a standard baud rate like 115200 with a 100 MHz clock:
```
  100,000,000 / 115200 ≈ 868  →  set CLKS_PER_BIT = 868
```

  For simulation you usually keep it small (like 16) so the waveform
  is not stretched out and the sim runs faster. Does not matter what
  the actual baud rate is as long as DUT and VIP use the same value.
  (default 16)

---

## First version limitations

- 8N1 only (no parity, 1 stop bit, 8 data bits)
- no functional coverage
- no protocol assertions
- no error injection
- one agent, not separate TX/RX agents

All of these can be added later without restructuring anything.
