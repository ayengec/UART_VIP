//==============================================================
// Simple UART sequencer
// Made by : Alican Yengec
// This sequencer controls uart sequence items.
// It works between sequence and driver.
//==============================================================

class uart_sequencer extends uvm_sequencer #(uart_seq_item);
  `uvm_component_utils(uart_sequencer)

  function new(string name = "uart_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass : uart_sequencer
