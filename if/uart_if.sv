//==============================================================
// Simple UART interface
// Made by : Alican Yengec
// This interface connects VIP and DUT.
// Also has debug signals for easy wave check.
//==============================================================
interface uart_if (
  input logic clk,
  input logic rst_n
);

  // Serial lines
  logic tx;    // driven by VIP driver, goes to DUT rxd
  logic rx;    // comes from DUT txd, VIP monitor watches this

  // Driver side parallel debug
  // Before sending each byte, driver sets these signals.
  // In wave, by looking drv_tx_data, you can see
  // which byte is sent, no need count serial bits.
  logic [7:0] drv_tx_data;    // byte to send in parallel
  logic       drv_tx_valid;   // 1-cycle pulse, byte started

  // Monitor side parallel debug
  // While monitor samples bits, mon_rx_shift updates.
  // When full byte is done, mon_rx_data and mon_rx_valid come.
  logic [7:0] mon_rx_data;    // fully captured byte in parallel
  logic       mon_rx_valid;   // 1-cycle pulse, byte captured

  logic [7:0] mon_rx_shift;   // live shift reg while frame is coming
  logic [3:0] mon_rx_bit_cnt; // how many bits sampled until now

endinterface : uart_if
