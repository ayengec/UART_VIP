//==============================================================
// Simple UART environment
// Made by : Alican Yengec
// This env creates uart agent and scoreboard.
// It also sends config to agent and connects monitor to scoreboard.
//==============================================================

class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_cfg        cfg;
  uart_agent      agent;
  uart_scoreboard sb;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(uart_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "uart_cfg not found in config_db")

    // Send cfg to agent
    uvm_config_db #(uart_cfg)::set(this, "agent*", "cfg", cfg);

    agent = uart_agent     ::type_id::create("agent", this);
    sb    = uart_scoreboard::type_id::create("sb",    this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(sb.actual_fifo.analysis_export);
  endfunction
endclass : uart_env
