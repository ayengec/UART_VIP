//==============================================================
// Simple UART testbench top
// Made by : Alican Yengec
// All TB is in one file here.
// File has interface, package and top module together.
// Also many debug signals added for easy wave check.
//==============================================================

// Compile order in this one file, from top to down:
//   1. interface  uart_if      - with parallel debug signals too
//   2. package    uart_vip_pkg - all UVM classes are here
//   3. module     example_tb_top  - clk/rst, DUT, VIP config, dumpvars

// Parallel vectors you can see in wave:
//   uart_if.drv_tx_data    : byte driven by driver in parallel
//   uart_if.drv_tx_valid   : 1-cycle pulse, new byte sending started
//   uart_if.mon_rx_data    : byte captured by monitor in parallel
//   uart_if.mon_rx_valid   : 1-cycle pulse, full byte captured
//   uart_if.mon_rx_shift   : live shift register while frame is coming
//   uart_if.mon_rx_bit_cnt : which bit sampled now, count goes one by one
//   dut_* signals          : DUT inside FSM states also shown as logic in tb_top

// VIP connection:
//   uart_if.tx  -> DUT rxd    (what VIP sends, DUT receives)
//   DUT txd     -> uart_if.rx (DUT echo, VIP monitor watches)
//==============================================================

module example_tb_top;

  import uvm_pkg::*;
  import uart_vip_pkg::*;
  `include "uvm_macros.svh"

  // Clock and reset
  // 100 MHz clock, 10 ns period
  // clocks_per_bit=16 -> baud is about 100M/16 = 6.25 Mbaud
  localparam int CLK_PERIOD_NS = 10;

  logic clk  = 1'b0;
  logic rst_n;

  always #(CLK_PERIOD_NS / 2) clk = ~clk;

  initial begin
    rst_n = 1'b0;
    repeat (8) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    `uvm_info("TB_TOP", "Reset deasserted", UVM_NONE)
  end

  // Interface
  uart_if u_if (.clk(clk), .rst_n(rst_n));

  // DUT debug signals, also visible in wave
  // These signals show DUT internal state as vector.
  // When checking VCD/WLF:
  //   dut_rx_shift -> byte filling one bit more when each bit comes
  //   dut_rx_state -> 0=IDLE 1=START 2=DATA 3=STOP
  //   dut_tx_shift -> parallel value while echo is sending
  logic [7:0] dut_rx_shift;
  logic       dut_rx_valid;
  logic [3:0] dut_rx_bit_idx;
  logic [1:0] dut_rx_state;

  logic [7:0] dut_tx_shift;
  logic       dut_tx_active;
  logic [3:0] dut_tx_bit_idx;
  logic [1:0] dut_tx_state;

  // DUT: UART Echo
  //   u_if.tx  -> DUT rxd : DUT gets what VIP driver sends
  //   DUT txd  -> u_if.rx : VIP monitor watches DUT echo
  uart_dut #(
   .CLKS_PER_BIT (16),
   .DATA_BITS    (8),
   .ECHO_DELAY   (10)   // delay 10 clocks
  ) u_dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .rxd            (u_if.tx),         // VIP -> DUT
    .txd            (u_if.rx),         // DUT -> VIP monitor
    // Parallel debug
    .dbg_rx_shift   (dut_rx_shift),
    .dbg_rx_valid   (dut_rx_valid),
    .dbg_rx_bit_idx (dut_rx_bit_idx),
    .dbg_rx_state   (dut_rx_state),
    .dbg_tx_shift   (dut_tx_shift),
    .dbg_tx_active  (dut_tx_active),
    .dbg_tx_bit_idx (dut_tx_bit_idx),
    .dbg_tx_state   (dut_tx_state)
  );

  // UVM start
  // Put virtual interface to place where test will read it
  initial begin
    uvm_config_db #(virtual uart_if)::set(
      null,               // any component
      "uvm_test_top",     // UVM hierarchy name of test
      "vif",              // parameter name
      u_if                // interface instance
    );
    run_test("uart_test");
  end

  // Wave dump, VCD
  // All signals are dumped:
  //   example_tb_top.u_if.*        -> serial and parallel debug vectors
  //   example_tb_top.dut_rx_*/tx_* -> DUT internal FSM parallel signals
  //   example_tb_top.u_dut.*       -> every signal inside DUT module
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, example_tb_top);
  end

  // Timeout, for protect from infinite loop
  initial begin
    #10_000_000;  // 10 ms
    `uvm_fatal("TIMEOUT", "Simulation got timeout!")
  end

endmodule : example_tb_top
