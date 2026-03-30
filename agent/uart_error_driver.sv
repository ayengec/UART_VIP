// =============================================================================
// uart_error_driver.sv
// Made by : Alican Yengec
//
// Extends uart_driver to handle uart_error_seq_item fields.
// For items that carry no error flags this class behaves identically to
// the base driver, so all existing tests continue to pass without change.
//
// Enable via factory override in your error test:
//   uart_driver::type_id::set_type_override(uart_error_driver::get_type());
// =============================================================================

class uart_error_driver extends uart_driver;
    `uvm_component_utils(uart_error_driver)

    function new(string name = "uart_error_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // -------------------------------------------------------------------------
    // Override drive_item to handle error injection fields.
    // -------------------------------------------------------------------------
    task drive_item(uart_seq_item tr);
        uart_error_seq_item err_tr;

        // If the item is not an error item, fall through to base class.
        if (!$cast(err_tr, tr)) begin
            super.drive_item(tr);
            return;
        end

        // -----------------------------------------------------------------
        // INJECT: Glitch — single-cycle low pulse before the real frame.
        // Looks like a false start bit to the DUT receiver.
        // The assertion AST_START_BIT_WIDTH should catch this because the
        // line returns high after only 1 cycle instead of CLKS_PER_BIT.
        // -----------------------------------------------------------------
        if (err_tr.inject_glitch) begin
            @(negedge vif.clk);
            vif.tx <= 1'b0;          // glitch low
            @(posedge vif.clk);
            vif.tx <= 1'b1;          // back to idle
            repeat (cfg.clocks_per_bit) @(posedge vif.clk);  // recovery gap
        end

        // -----------------------------------------------------------------
        // INJECT: Break — hold TX low for 2 full frame durations.
        // Any byte value in the item is discarded; only the break is sent.
        // -----------------------------------------------------------------
        if (err_tr.inject_break) begin
            @(negedge vif.clk);
            vif.drv_tx_data  <= 8'hBB;   // 0xBB = "break" marker in wave
            vif.drv_tx_valid <= 1'b1;
            @(posedge vif.clk);
            vif.drv_tx_valid <= 1'b0;

            vif.tx <= 1'b0;
            // Hold low for 2 full frame periods (start+data+stop) * 2
            repeat (2 * (1 + cfg.data_bits + cfg.stop_bits) * cfg.clocks_per_bit)
                @(posedge vif.clk);
            vif.tx <= 1'b1;    // release
            repeat (cfg.clocks_per_bit) @(posedge vif.clk);  // idle recovery
            return;
        end

        // -----------------------------------------------------------------
        // Normal frame preamble (debug signals, same as base driver)
        // -----------------------------------------------------------------
        @(negedge vif.clk);
        vif.drv_tx_data  <= err_tr.data;
        vif.drv_tx_valid <= 1'b1;
        @(posedge vif.clk);
        vif.drv_tx_valid <= 1'b0;

        // Start bit
        vif.tx <= 1'b0;
        wait_bit();

        // Data bits LSB first
        for (int i = 0; i < cfg.data_bits; i++) begin
            vif.tx <= err_tr.data[i];
            wait_bit();
        end

        // -----------------------------------------------------------------
        // Parity bit (with optional flip)
        // -----------------------------------------------------------------
        if (cfg.parity_en) begin
            bit p;
            p = calc_parity(err_tr.data);
            if (!cfg.parity_odd) p = ~p;
            if (err_tr.inject_bad_parity) p = ~p;  // <-- flip here
            vif.tx <= p;
            wait_bit();
        end

        // -----------------------------------------------------------------
        // Stop bit(s) — drive 0 instead of 1 when inject_bad_stop is set
        // -----------------------------------------------------------------
        if (err_tr.inject_bad_stop)
            vif.tx <= 1'b0;   // framing error: stop bit is 0
        else
            vif.tx <= 1'b1;   // normal stop bit

        repeat (cfg.stop_bits) wait_bit();

        // Return to idle even after a bad stop (DUT needs to recover)
        vif.tx <= 1'b1;
        repeat (cfg.clocks_per_bit) @(posedge vif.clk);
    endtask

endclass : uart_error_driver
