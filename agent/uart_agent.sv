//==============================================================
// Simple UART agent
// Made by : Alican Yengec
// This agent creates monitor always.
// If mode is active, it also creates sequencer and driver.
//==============================================================

class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uart_cfg       cfg;
  uart_sequencer seqr;
  uart_driver    drv;
  uart_monitor   mon;

  function new(string name = "uart_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(uart_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "uart_cfg not found in config_db")

    mon = uart_monitor::type_id::create("mon", this);

    if (cfg.mode == UART_ACTIVE) begin
      seqr = uart_sequencer::type_id::create("seqr", this);
      drv  = uart_driver   ::type_id::create("drv",  this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.mode == UART_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass : uart_agent
