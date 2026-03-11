//==============================================================
// Simple UART sequence item
// Made by : Alican Yengec
// This class keeps uart transaction info.
// Some fields are random, some filled by monitor.
// String print is easy for match with wave/log.
//==============================================================

class uart_seq_item extends uvm_sequence_item;
  `uvm_object_utils(uart_seq_item)

  rand logic [7:0] data;
  rand logic       parity_en;
  rand logic       parity_odd;
  rand logic [1:0] stop_bits;

  bit parity_ok;
  bit framing_ok;

  function new(string name = "uart_seq_item");
    super.new(name);
  endfunction

  // Show both hex and binary.
  // It is more easy to compare with wave log directly.
  function string convert2string();
    return $sformatf(
      "data=8'h%02h (%08b)  parity_en=%0b parity_odd=%0b stop_bits=%0d  parity_ok=%0b framing_ok=%0b",
      data, data, parity_en, parity_odd, stop_bits, parity_ok, framing_ok);
  endfunction
endclass : uart_seq_item
