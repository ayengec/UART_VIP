// =============================================================================
// uart_error_test.sv
// Made by : Alican Yengec
//
// Test that exercises error injection scenarios.
// Uses factory override to swap in uart_error_driver transparently.
//
// What this test checks:
//   - Bad stop bit  → scoreboard must log FRAMING ERROR
//   - Bad parity    → scoreboard must log PARITY ERROR (parity_en=1 required)
//   - Glitch        → assertion AST_START_BIT_WIDTH fires
//   - Break         → DUT must recover and echo the clean frame after break
//
// The error driver is registered via factory override so uart_agent
// does not need to know about it.
// =============================================================================

class uart_error_test extends uvm_test;
    `uvm_component_utils(uart_error_test)

    uart_cfg cfg;
    uart_env env;

    function new(string name = "uart_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual uart_if vif_h;
        super.build_phase(phase);

        // ---------------------------------------------------------------
        // Factory override: swap base driver for error-injecting driver.
        // All other components stay the same.
        // ---------------------------------------------------------------
        uart_driver::type_id::set_type_override(
            uart_error_driver::get_type());

        if (!uvm_config_db #(virtual uart_if)::get(this, "", "vif", vif_h))
            `uvm_fatal(get_type_name(), "virtual uart_if not found in config_db")

        cfg                = uart_cfg::type_id::create("cfg");
        cfg.vif            = vif_h;
        cfg.mode           = UART_ACTIVE;
        cfg.clocks_per_bit = 16;
        cfg.data_bits      = 8;
        cfg.parity_en      = 1'b0;   // default off; bad_parity_seq enables it
        cfg.stop_bits      = 1;

        uvm_config_db #(uart_cfg)::set(this, "env", "cfg", cfg);
        env = uart_env::type_id::create("env", this);
    endfunction

    // -----------------------------------------------------------------------
    // Load expected items.
    // Error frames are NOT expected to match data — they trigger error paths.
    // Only clean frames (before/after errors) need expected items.
    //
    // Sequence order from uart_error_mix_seq:
    //   clean(AA) → bad_stop(DE) → clean(55) → bad_parity(BE) →
    //   clean(CC) → glitch+clean(AB) → clean(12) → break → clean(FF)
    //
    // The scoreboard will raise UVM_ERROR for error frames — that is expected
    // and correct behaviour.  We do NOT load expected items for error frames
    // because the DUT echo for those is undefined / garbled.
    // -----------------------------------------------------------------------
    function void load_expected();
        // Helper lambda
        uart_seq_item exp;

        // Frame 1: clean 0xAA
        exp = uart_seq_item::type_id::create("exp");
        exp.data = 8'hAA; exp.parity_en = 0; exp.stop_bits = 1;
        env.sb.write_expected(exp);

        // Frame 3: clean 0x55 (recovery after bad stop)
        exp = uart_seq_item::type_id::create("exp");
        exp.data = 8'h55; exp.parity_en = 0; exp.stop_bits = 1;
        env.sb.write_expected(exp);

        // Frame 5: clean 0xCC (recovery after bad parity)
        exp = uart_seq_item::type_id::create("exp");
        exp.data = 8'hCC; exp.parity_en = 0; exp.stop_bits = 1;
        env.sb.write_expected(exp);

        // Frame 7: clean 0xAB (valid frame that follows glitch)
        exp = uart_seq_item::type_id::create("exp");
        exp.data = 8'hAB; exp.parity_en = 0; exp.stop_bits = 1;
        env.sb.write_expected(exp);

        // Frame 8: clean 0x12 (after glitch sequence)
        exp = uart_seq_item::type_id::create("exp");
        exp.data = 8'h12; exp.parity_en = 0; exp.stop_bits = 1;
        env.sb.write_expected(exp);

        // Frame 10: clean 0xFF (recovery after break)
        exp = uart_seq_item::type_id::create("exp");
        exp.data = 8'hFF; exp.parity_en = 0; exp.stop_bits = 1;
        env.sb.write_expected(exp);
    endfunction

    task run_phase(uvm_phase phase);
        uart_error_mix_seq seq;
        int unsigned frame_ns;
        int unsigned total_frames = 10;
        int unsigned margin       = 6;

        phase.raise_objection(this);

        load_expected();

        seq = uart_error_mix_seq::type_id::create("seq");

        `uvm_info(get_type_name(),
            "uart_error_test starting — expect UVM_ERROR messages for injected faults",
            UVM_NONE)

        repeat (50) @(posedge cfg.vif.clk);
        seq.start(env.agent.seqr);

        // Wait for all echoes + DUT recovery time after break
        frame_ns = (1 + cfg.data_bits + cfg.stop_bits) * cfg.clocks_per_bit * 10;
        #((total_frames + margin) * frame_ns * 4);

        `uvm_info(get_type_name(), "uart_error_test done.", UVM_NONE)
        phase.drop_objection(this);
    endtask

endclass : uart_error_test
