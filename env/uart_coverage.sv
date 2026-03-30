// =============================================================================
// uart_coverage.sv
// Made by : Alican Yengec
//
// UVM functional coverage subscriber.
// Receives uart_seq_item from the monitor's analysis port and samples
// all covergroups automatically.
//
// Wire it up in uart_env.sv connect_phase:
//   agent.mon.ap.connect(coverage.analysis_export);
// =============================================================================

class uart_coverage extends uvm_subscriber #(uart_seq_item);
    `uvm_component_utils(uart_coverage)

    // Internal handle — refreshed on every write()
    uart_seq_item m_item;

    // =========================================================================
    // CG 1 — Data Value
    // Corner values, walking patterns, and range quartiles.
    // =========================================================================
    covergroup cg_data_value;
        cp_data : coverpoint m_item.data {
            bins zero          = {8'h00};
            bins all_ones      = {8'hFF};
            bins alt_55        = {8'h55};
            bins alt_AA        = {8'hAA};
            bins walk_1[]      = {8'h01, 8'h02, 8'h04, 8'h08,
                                  8'h10, 8'h20, 8'h40, 8'h80};
            bins walk_0[]      = {8'hFE, 8'hFD, 8'hFB, 8'hF7,
                                  8'hEF, 8'hDF, 8'hBF, 8'h7F};
            bins range_low     = {[8'h01 : 8'h3F]};
            bins range_midlo   = {[8'h40 : 8'h7F]};
            bins range_midhi   = {[8'h80 : 8'hBF]};
            bins range_high    = {[8'hC0 : 8'hFE]};
        }
    endgroup : cg_data_value

    // =========================================================================
    // CG 2 — Frame Integrity
    // Both pass and fail outcomes must be exercised for framing and parity.
    // The cross ensures every combination is hit.
    // =========================================================================
    covergroup cg_frame_integrity;
        cp_framing : coverpoint m_item.framing_ok {
            bins framing_ok   = {1'b1};
            bins framing_err  = {1'b0};
        }
        cp_parity  : coverpoint m_item.parity_ok {
            bins parity_ok    = {1'b1};
            bins parity_err   = {1'b0};
        }
        cx_integrity : cross cp_framing, cp_parity;
    endgroup : cg_frame_integrity

    // =========================================================================
    // CG 3 — Parity Configuration
    // parity enabled/disabled × odd/even.  ignore_bins removes impossible
    // combinations (parity mode meaningless when parity is off).
    // =========================================================================
    covergroup cg_parity_cfg;
        cp_parity_en : coverpoint m_item.parity_en {
            bins disabled = {1'b0};
            bins enabled  = {1'b1};
        }
        cp_parity_odd : coverpoint m_item.parity_odd {
            bins even_parity = {1'b0};
            bins odd_parity  = {1'b1};
        }
        cx_parity_mode : cross cp_parity_en, cp_parity_odd {
            ignore_bins parity_off_x =
                binsof(cp_parity_en.disabled);
        }
    endgroup : cg_parity_cfg

    // =========================================================================
    // CG 4 — Stop Bit Count
    // =========================================================================
    covergroup cg_stop_bits;
        cp_stop : coverpoint m_item.stop_bits {
            bins one_stop  = {2'd1};
            bins two_stops = {2'd2};
        }
    endgroup : cg_stop_bits

    // =========================================================================
    // CG 5 — Data Transitions
    // Back-to-back byte patterns that stress the line encoder.
    // =========================================================================
    covergroup cg_data_transitions;
        cp_trans : coverpoint m_item.data {
            bins same_byte[]  = (8'h00 => 8'h00),
                                (8'hFF => 8'hFF);
            bins zero_to_max  = (8'h00 => 8'hFF);
            bins max_to_zero  = (8'hFF => 8'h00);
            bins lo_to_hi     = ([8'h00:8'h7F] => [8'h80:8'hFF]);
            bins hi_to_lo     = ([8'h80:8'hFF] => [8'h00:8'h7F]);
        }
    endgroup : cg_data_transitions

    // =========================================================================
    // CG 6 — Error Injection Types
    // Confirms that each error scenario is actually exercised.
    // =========================================================================
    covergroup cg_error_types;
        cp_framing_err : coverpoint m_item.framing_ok {
            bins ok  = {1'b1};
            bins err = {1'b0};
        }
        cp_parity_err  : coverpoint m_item.parity_ok {
            bins ok  = {1'b1};
            bins err = {1'b0};
        }
    endgroup : cg_error_types

    // =========================================================================
    // Constructor
    // =========================================================================
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_data_value      = new();
        cg_frame_integrity = new();
        cg_parity_cfg      = new();
        cg_stop_bits       = new();
        cg_data_transitions= new();
        cg_error_types     = new();
    endfunction : new

    // =========================================================================
    // write() — called by monitor's analysis port on every captured frame
    // =========================================================================
    function void write(uart_seq_item t);
        m_item = t;
        cg_data_value.sample();
        cg_frame_integrity.sample();
        cg_parity_cfg.sample();
        cg_stop_bits.sample();
        cg_data_transitions.sample();
        cg_error_types.sample();
    endfunction : write

    // =========================================================================
    // report_phase — print per-group and aggregate coverage
    // =========================================================================
    function void report_phase(uvm_phase phase);
        real total;
        total = ( cg_data_value.get_coverage()       +
                  cg_frame_integrity.get_coverage()  +
                  cg_parity_cfg.get_coverage()       +
                  cg_stop_bits.get_coverage()        +
                  cg_data_transitions.get_coverage() +
                  cg_error_types.get_coverage()      ) / 6.0;

        `uvm_info(get_type_name(), $sformatf(
            "\n========== UART Functional Coverage ==========\n  cg_data_value       : %5.1f%%\n  cg_frame_integrity  : %5.1f%%\n  cg_parity_cfg       : %5.1f%%\n  cg_stop_bits        : %5.1f%%\n  cg_data_transitions : %5.1f%%\n  cg_error_types      : %5.1f%%\n  -----------------------------------------------\n  TOTAL               : %5.1f%%\n===============================================",
            cg_data_value.get_coverage(),
            cg_frame_integrity.get_coverage(),
            cg_parity_cfg.get_coverage(),
            cg_stop_bits.get_coverage(),
            cg_data_transitions.get_coverage(),
            cg_error_types.get_coverage(),
            total
        ), UVM_NONE)
    endfunction : report_phase

endclass : uart_coverage
