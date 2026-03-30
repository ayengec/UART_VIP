//==============================================================
// UART Environment
// Made by : Alican Yengec
//
// Subscriber pattern — no ref_model.
//
// connect_phase:
//   agent.mon.ap --> sb.actual_export   (monitor captures RX = actual)
//
// Expected items are loaded manually via sb.write_expected()
// in the test before the sequence starts.
//==============================================================

class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_cfg        cfg;
  uart_agent      agent;
  uart_scoreboard sb;
  uart_coverage   coverage;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(uart_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "uart_cfg not found in config_db")

    uvm_config_db #(uart_cfg)::set(this, "agent*", "cfg", cfg);

    agent    = uart_agent     ::type_id::create("agent",    this);
    sb       = uart_scoreboard::type_id::create("sb",       this);
    coverage = uart_coverage  ::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(sb.actual_export);         // monitor -> scoreboard
    agent.mon.ap.connect(coverage.analysis_export); // monitor -> coverage
    // expected: loaded manually in test via sb.write_expected()
  endfunction

endclass : uart_env
