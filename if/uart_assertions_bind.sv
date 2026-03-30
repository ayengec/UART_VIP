// =============================================================================
// uart_assertions_bind.sv
// Made by : Alican Yengec
//
// Bind file — attaches uart_assertions to every instance of uart_if.
// Add this file to your compile list AFTER uart_if.sv.
// No changes needed to the interface or testbench top.
// =============================================================================

bind uart_if uart_assertions #(
    .CLKS_PER_BIT (16),
    .DATA_BITS    (8)
) u_assertions (
    .clk          (clk),
    .rst_n        (rst_n),
    .tx           (tx),
    .rx           (rx),
    .drv_tx_valid (drv_tx_valid),
    .mon_rx_valid (mon_rx_valid),
    .mon_rx_data  (mon_rx_data)
);
