// =============================================================================
// uart_error_seq_item.sv
// Made by : Alican Yengec
//
// Extends uart_seq_item with error injection control fields.
// The error driver reads these fields to corrupt the frame at pin level.
//
// Error types:
//   inject_bad_stop    : drives stop bit as 0 → framing error at DUT
//   inject_bad_parity  : flips the computed parity bit → parity error at DUT
//   inject_glitch      : pulls TX low for 1 cycle then back high (false start)
//   inject_break       : holds TX low for 2 full frame durations (UART break)
//
// Usage: let the test randomize with constraints, or set fields directly.
// =============================================================================

class uart_error_seq_item extends uart_seq_item;
    `uvm_object_utils(uart_error_seq_item)

    // Error injection controls
    rand bit inject_bad_stop;    // make stop bit 0 instead of 1
    rand bit inject_bad_parity;  // flip computed parity bit
    rand bit inject_glitch;      // 1-cycle low pulse before frame (false start)
    rand bit inject_break;       // drive TX low for 2x frame length

    // Default: no errors (keeps existing tests clean when type overridden)
    constraint c_no_error_default {
        inject_bad_stop   == 1'b0;
        inject_bad_parity == 1'b0;
        inject_glitch     == 1'b0;
        inject_break      == 1'b0;
    }

    // Convenience constraint: exactly one error per item
    // Activate this with item.c_no_error_default.constraint_mode(0)
    constraint c_one_error_only {
        $onehot({inject_bad_stop, inject_bad_parity, inject_glitch, inject_break});
    }

    function new(string name = "uart_error_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        string base = super.convert2string();
        return $sformatf(
            "%s  [ERR inj: bad_stop=%0b bad_parity=%0b glitch=%0b break=%0b]",
            base,
            inject_bad_stop, inject_bad_parity, inject_glitch, inject_break
        );
    endfunction

endclass : uart_error_seq_item
