//==============================================================
// UART Test
// Made by : Alican Yengec
//
// Expected items are created manually and loaded into the
// scoreboard before the sequence starts.
// The sequence sends the same bytes in the same order.
// Monitor captures RX, scoreboard compares against expected.
//==============================================================

class uart_test extends uvm_test;
  `uvm_component_utils(uart_test)

  uart_cfg cfg;
  uart_env env;

  function new(string name = "uart_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual uart_if vif_h;
    super.build_phase(phase);

    if (!uvm_config_db #(virtual uart_if)::get(this, "", "vif", vif_h))
      `uvm_fatal(get_type_name(), "virtual uart_if not found in config_db")

    cfg                = uart_cfg::type_id::create("cfg");
    cfg.vif            = vif_h;
    cfg.mode           = UART_ACTIVE;
    cfg.clocks_per_bit = 16;
    cfg.data_bits      = 8;
    cfg.parity_en      = 1'b0;
    cfg.stop_bits      = 1;

    uvm_config_db #(uart_cfg)::set(this, "env", "cfg", cfg);
    env = uart_env::type_id::create("env", this);
  endfunction

  // Create expected items manually and push them into the scoreboard.
  // Order must match the order the sequence sends bytes.
  function void load_expected();
    uart_seq_item exp;

    exp           = uart_seq_item::type_id::create("exp");
    exp.data      = 8'hE6;
    exp.parity_en = 1'b0;
    exp.stop_bits = 1;
    env.sb.write_expected(exp);

    exp           = uart_seq_item::type_id::create("exp");
    exp.data      = 8'hA5;
    exp.parity_en = 1'b0;
    exp.stop_bits = 1;
    env.sb.write_expected(exp);

    exp           = uart_seq_item::type_id::create("exp");
    exp.data      = 8'h3C;
    exp.parity_en = 1'b0;
    exp.stop_bits = 1;
    env.sb.write_expected(exp);

    // Add more items here as needed...
  endfunction

  task run_phase(uvm_phase phase);
    uart_tx_seq  seq;
    int unsigned margin = 4;
    int unsigned frame_ns;
    phase.raise_objection(this);

    // Load expected items into scoreboard before sequence starts
    load_expected();

    seq = uart_tx_seq::type_id::create("seq");

    // Feed the same bytes to the sequence in the same order as load_expected()
    seq.data_q.push_back(8'hE6);
    seq.data_q.push_back(8'hA5);
    seq.data_q.push_back(8'h3C);

    `uvm_info(get_type_name(),
              $sformatf("Test starting, %0d bytes will be sent", seq.data_q.size()), UVM_NONE)

    repeat (50) @(posedge cfg.vif.clk);
    seq.start(env.agent.seqr);

    frame_ns = (1 + cfg.data_bits + cfg.stop_bits) * cfg.clocks_per_bit * 10;
    #((seq.data_q.size() + margin) * frame_ns * 2);

    `uvm_info(get_type_name(), "Test done.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : uart_test
