//==============================================================
// Simple UART config class
// Made by : Alican Yengec
// This class keeps uart agent configuration.
// Virtual interface is set from tb_top.
//==============================================================

class uart_cfg extends uvm_object;
  `uvm_object_utils(uart_cfg)

  virtual uart_if vif;               // set from tb_top

  uart_agent_mode_e mode           = UART_PASSIVE;
  int unsigned      clocks_per_bit = 16;
  int unsigned      data_bits      = 8;
  logic             parity_en      = 1'b0;
  logic             parity_odd     = 1'b0;
  int unsigned      stop_bits      = 1;

  function new(string name = "uart_cfg");
    super.new(name);
  endfunction
endclass : uart_cfg
