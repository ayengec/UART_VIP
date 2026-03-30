// =============================================================================
// uart_assertions.sv
// Made by : Alican Yengec
//
// SVA protocol checker for the UART VIP.
// Bind this module to uart_if from the bind file (uart_assertions_bind.sv).
//
// Checks covered:
//   GROUP 1 — Reset / Idle          : TX/RX must be high after reset, no X/Z
//   GROUP 2 — Start Bit             : must be low for exactly CLKS_PER_BIT
//   GROUP 3 — Stop Bit              : must arrive in frame window, min width
//   GROUP 4 — Frame Timing          : drv/mon valid pulses, echo latency bound
//   GROUP 5 — Data Validity         : mon_rx_data not X/Z when valid pulses
//   GROUP 6 — Cover Properties      : back-to-back, corner bytes
// =============================================================================

module uart_assertions #(
    parameter int CLKS_PER_BIT = 16,
    parameter int DATA_BITS    = 8
)(
    input logic       clk,
    input logic       rst_n,
    input logic       tx,
    input logic       rx,
    input logic       drv_tx_valid,
    input logic       mon_rx_valid,
    input logic [7:0] mon_rx_data
);

    // -------------------------------------------------------------------------
    // Derived constants
    // -------------------------------------------------------------------------
    // Total clocks for one 8N1 frame: start(1) + data(8) + stop(1) = 10 bits
    localparam int FRAME_BITS = 1 + DATA_BITS + 1;
    localparam int FRAME_CLKS = FRAME_BITS * CLKS_PER_BIT;

    // -------------------------------------------------------------------------
    // Default clocking and disable
    // -------------------------------------------------------------------------
    default clocking cb @(posedge clk); endclocking
    default disable iff (!rst_n);

    // =========================================================================
    // GROUP 1 — Reset / Idle
    // =========================================================================

    // TX must be high (idle) within one cycle after reset deasserts.
    AST_TX_IDLE_AFTER_RESET : assert property (
        @(posedge clk) $rose(rst_n) |=> tx
    ) else `uvm_error("UART_AST", "TX not idle one cycle after reset deassert")

    // RX must be high (idle) within one cycle after reset deasserts.
    AST_RX_IDLE_AFTER_RESET : assert property (
        @(posedge clk) $rose(rst_n) |=> rx
    ) else `uvm_error("UART_AST", "RX not idle one cycle after reset deassert")

    // RX must never be X or Z while the design is active.
    AST_RX_NO_X : assert property (
        @(posedge clk) rst_n |-> !$isunknown(rx)
    ) else `uvm_error("UART_AST", "RX is X/Z during active operation")

    // =========================================================================
    // GROUP 2 — Start Bit (TX side)
    // =========================================================================

    // When TX falls (start bit begins), it must stay low for the full
    // CLKS_PER_BIT period before any transition.
    // [*N] means repeated N times — TX must be 0 on each of the next N cycles.
    AST_START_BIT_WIDTH : assert property (
        @(posedge clk)
        $fell(tx) |-> tx[*CLKS_PER_BIT]
    ) else `uvm_error("UART_AST", "Start bit too short — TX went high before bit period ended")

    // TX must have been idle (high) in the cycle before a falling edge.
    // Prevents false-start or glitch masquerading as a valid start bit.
    AST_TX_IDLE_BEFORE_START : assert property (
        @(posedge clk)
        $fell(tx) |-> $past(tx, 1)
    ) else `uvm_error("UART_AST", "TX fell without prior idle — possible glitch")

    // =========================================================================
    // GROUP 3 — Stop Bit (TX side)
    // =========================================================================

    // After the falling edge (start bit), TX must return high within the
    // legal stop-bit window.  For 8N1 the window is exactly FRAME_CLKS.
    // We allow a small tolerance of ±1 cycle for sampling alignment.
    AST_STOP_BIT_ARRIVES : assert property (
        @(posedge clk)
        $fell(tx) |->
            ##[FRAME_CLKS - 1 : FRAME_CLKS + 1] tx
    ) else `uvm_error("UART_AST", "Stop bit did not arrive within the expected frame window")

    // Once TX rises (stop bit), it must stay high for at least CLKS_PER_BIT
    // before another start bit can begin.
    AST_STOP_BIT_MIN_WIDTH : assert property (
        @(posedge clk)
        $rose(tx) |-> tx[*CLKS_PER_BIT]
    ) else `uvm_error("UART_AST", "Stop bit too short — next start bit came too early")

    // =========================================================================
    // GROUP 4 — Frame Timing (debug signal checks)
    // =========================================================================

    // drv_tx_valid must be a single-cycle pulse only.
    AST_DRV_VALID_SINGLE_CYCLE : assert property (
        @(posedge clk)
        $rose(drv_tx_valid) |=> !drv_tx_valid
    ) else `uvm_error("UART_AST", "drv_tx_valid stayed high for more than one cycle")

    // mon_rx_valid must be a single-cycle pulse only.
    AST_MON_VALID_SINGLE_CYCLE : assert property (
        @(posedge clk)
        $rose(mon_rx_valid) |=> !mon_rx_valid
    ) else `uvm_error("UART_AST", "mon_rx_valid stayed high for more than one cycle")

    // After the driver starts a frame (drv_tx_valid), the monitor must see
    // the echoed frame within a bounded latency window.
    // Minimum: TX_frame + ECHO_DELAY(10) + RX_frame = 160+10+160 = 330 cycles.
    // Maximum: give 2× headroom = 660 cycles.
    AST_ECHO_LATENCY_BOUND : assert property (
        @(posedge clk)
        $rose(drv_tx_valid) |->
            ##[FRAME_CLKS : 2*FRAME_CLKS + 20] mon_rx_valid
    ) else `uvm_error("UART_AST", "Echo did not arrive within latency window after drv_tx_valid")

    // =========================================================================
    // GROUP 5 — Data Validity
    // =========================================================================

    // mon_rx_data must be fully driven (no X/Z) when mon_rx_valid pulses.
    AST_RX_DATA_NO_X_WHEN_VALID : assert property (
        @(posedge clk)
        mon_rx_valid |-> !$isunknown(mon_rx_data)
    ) else `uvm_error("UART_AST", "mon_rx_data contains X/Z when mon_rx_valid is high")

    // =========================================================================
    // GROUP 6 — Cover Properties
    // (These never fire as failures; they measure stimulus richness.)
    // =========================================================================

    // At least one complete TX frame was observed.
    COV_TX_FRAME_COMPLETE : cover property (
        @(posedge clk)
        $fell(tx) ##[FRAME_CLKS-2 : FRAME_CLKS+2] $rose(tx)
    );

    // Two TX frames were sent back-to-back (stop bit of N, immediately
    // followed by start bit of N+1, within one stop-bit period).
    COV_BACK_TO_BACK_TX : cover property (
        @(posedge clk)
        $fell(tx) ##[FRAME_CLKS-1 : FRAME_CLKS+CLKS_PER_BIT] $fell(tx)
    );

    // Corner data values captured by monitor.
    COV_RX_ALLZERO : cover property (
        @(posedge clk) mon_rx_valid && (mon_rx_data == 8'h00));
    COV_RX_ALLONES : cover property (
        @(posedge clk) mon_rx_valid && (mon_rx_data == 8'hFF));
    COV_RX_55      : cover property (
        @(posedge clk) mon_rx_valid && (mon_rx_data == 8'h55));
    COV_RX_AA      : cover property (
        @(posedge clk) mon_rx_valid && (mon_rx_data == 8'hAA));

    // A framing error was injected (stop bit seen as 0 on RX side).
    COV_FRAMING_ERROR_INJECTED : cover property (
        @(posedge clk)
        // After full data period the line should be high; if it isn't,
        // a framing error was exercised.
        $fell(rx) ##[FRAME_CLKS-1 : FRAME_CLKS+1] !rx
    );

endmodule : uart_assertions
