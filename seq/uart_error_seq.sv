// =============================================================================
// uart_error_seq.sv
// Made by : Alican Yengec
//
// A library of targeted error injection sequences.
// Each sequence extends uvm_sequence and sends one or more error frames.
//
// Sequences:
//   uart_bad_stop_seq     — single frame with bad stop bit
//   uart_bad_parity_seq   — single frame with flipped parity
//   uart_glitch_seq       — glitch on TX before a valid frame
//   uart_break_seq        — UART break condition (TX held low)
//   uart_error_mix_seq    — sends all error types in order, with clean
//                           frames in between to let DUT recover
// =============================================================================

// -----------------------------------------------------------------------------
// 1. Bad Stop Bit
// -----------------------------------------------------------------------------
class uart_bad_stop_seq extends uvm_sequence #(uart_seq_item);
    `uvm_object_utils(uart_bad_stop_seq)

    logic [7:0] data = 8'hDE;   // changeable by test

    function new(string name = "uart_bad_stop_seq");
        super.new(name);
    endfunction

    task body();
        uart_error_seq_item tr;
        tr = uart_error_seq_item::type_id::create("tr");
        tr.c_no_error_default.constraint_mode(0);   // lift no-error default
        tr.data             = data;
        tr.parity_en        = 1'b0;
        tr.stop_bits        = 2'd1;
        tr.inject_bad_stop  = 1'b1;
        start_item(tr);
        finish_item(tr);
        `uvm_info(get_type_name(),
            $sformatf("Injected bad stop bit — %s", tr.convert2string()), UVM_LOW)
    endtask

endclass : uart_bad_stop_seq

// -----------------------------------------------------------------------------
// 2. Bad Parity
// -----------------------------------------------------------------------------
class uart_bad_parity_seq extends uvm_sequence #(uart_seq_item);
    `uvm_object_utils(uart_bad_parity_seq)

    logic [7:0] data = 8'hBE;

    function new(string name = "uart_bad_parity_seq");
        super.new(name);
    endfunction

    task body();
        uart_error_seq_item tr;
        tr = uart_error_seq_item::type_id::create("tr");
        tr.c_no_error_default.constraint_mode(0);
        tr.data               = data;
        tr.parity_en          = 1'b1;   // parity must be on for this to matter
        tr.parity_odd         = 1'b0;
        tr.stop_bits          = 2'd1;
        tr.inject_bad_parity  = 1'b1;
        start_item(tr);
        finish_item(tr);
        `uvm_info(get_type_name(),
            $sformatf("Injected bad parity — %s", tr.convert2string()), UVM_LOW)
    endtask

endclass : uart_bad_parity_seq

// -----------------------------------------------------------------------------
// 3. Glitch (false start)
// -----------------------------------------------------------------------------
class uart_glitch_seq extends uvm_sequence #(uart_seq_item);
    `uvm_object_utils(uart_glitch_seq)

    logic [7:0] data = 8'hAB;

    function new(string name = "uart_glitch_seq");
        super.new(name);
    endfunction

    task body();
        uart_error_seq_item tr;
        tr = uart_error_seq_item::type_id::create("tr");
        tr.c_no_error_default.constraint_mode(0);
        tr.data           = data;
        tr.parity_en      = 1'b0;
        tr.stop_bits      = 2'd1;
        tr.inject_glitch  = 1'b1;
        start_item(tr);
        finish_item(tr);
        `uvm_info(get_type_name(),
            $sformatf("Injected glitch + valid frame — %s", tr.convert2string()), UVM_LOW)
    endtask

endclass : uart_glitch_seq

// -----------------------------------------------------------------------------
// 4. Break Condition
// -----------------------------------------------------------------------------
class uart_break_seq extends uvm_sequence #(uart_seq_item);
    `uvm_object_utils(uart_break_seq)

    function new(string name = "uart_break_seq");
        super.new(name);
    endfunction

    task body();
        uart_error_seq_item tr;
        tr = uart_error_seq_item::type_id::create("tr");
        tr.c_no_error_default.constraint_mode(0);
        tr.inject_break = 1'b1;
        start_item(tr);
        finish_item(tr);
        `uvm_info(get_type_name(), "Injected UART break condition", UVM_LOW)
    endtask

endclass : uart_break_seq

// -----------------------------------------------------------------------------
// 5. Mixed Error Sequence
// Sends: clean → bad_stop → clean → bad_parity → clean → glitch → clean → break
// The clean frames between errors allow the DUT to return to idle.
// -----------------------------------------------------------------------------
class uart_error_mix_seq extends uvm_sequence #(uart_seq_item);
    `uvm_object_utils(uart_error_mix_seq)

    function new(string name = "uart_error_mix_seq");
        super.new(name);
    endfunction

    // Helper: send one clean frame with given data
    task send_clean(logic [7:0] d);
        uart_error_seq_item tr;
        tr = uart_error_seq_item::type_id::create("clean_tr");
        // c_no_error_default is on by default — no error fields needed
        tr.data      = d;
        tr.parity_en = 1'b0;
        tr.stop_bits = 2'd1;
        start_item(tr);
        finish_item(tr);
    endtask

    task body();
        uart_bad_stop_seq   bad_stop_s;
        uart_bad_parity_seq bad_par_s;
        uart_glitch_seq     glitch_s;
        uart_break_seq      break_s;

        // --- Clean frame before any errors ---
        send_clean(8'hAA);

        // --- Bad stop ---
        bad_stop_s       = uart_bad_stop_seq::type_id::create("bad_stop_s");
        bad_stop_s.data  = 8'hDE;
        bad_stop_s.start(null, this);
        send_clean(8'h55);   // recovery frame

        // --- Bad parity ---
        bad_par_s       = uart_bad_parity_seq::type_id::create("bad_par_s");
        bad_par_s.data  = 8'hBE;
        bad_par_s.start(null, this);
        send_clean(8'hCC);

        // --- Glitch ---
        glitch_s       = uart_glitch_seq::type_id::create("glitch_s");
        glitch_s.data  = 8'hAB;
        glitch_s.start(null, this);
        send_clean(8'h12);

        // --- Break ---
        break_s = uart_break_seq::type_id::create("break_s");
        break_s.start(null, this);
        send_clean(8'hFF);   // final clean frame after break

        `uvm_info(get_type_name(), "uart_error_mix_seq done", UVM_LOW)
    endtask

endclass : uart_error_mix_seq
