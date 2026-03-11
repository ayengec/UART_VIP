//==============================================================
// Simple UART test
// Made by : Alican Yengec
// This test creates config and environment.
// It gets virtual interface from tb_top.
// Then it starts TX sequence and waits DUT echo finish.
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

    // Get virtual interface from tb_top
    if (!uvm_config_db #(virtual uart_if)::get(this, "", "vif", vif_h))
      `uvm_fatal(get_type_name(), "virtual uart_if not found in config_db (tb_top should set it)")

    // Create cfg and pass VIF
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

  task run_phase(uvm_phase phase);
    uart_tx_seq seq;

    // 1 frame = (1 start + data_bits + stop_bits) * clocks_per_bit
    // For 8 byte echo, total time is around:
    // n_trans * frame_clks * 2 * clk_period
    int unsigned n      = 8;
    int unsigned margin = 4;    // extra frame margin
    int unsigned frame_ns;

    phase.raise_objection(this);

    seq         = uart_tx_seq::type_id::create("seq");
    seq.n_trans = n;
    seq.exp_mbx = env.sb.exp_mbx;   // connect expected mailbox

    `uvm_info(get_type_name(),
              $sformatf("Test is starting, %0d bytes will be sent", n), UVM_NONE)

    repeat (50) @(posedge cfg.vif.clk);
    seq.start(env.agent.seqr);

    // Wait for DUT echo
    // Each byte is sent one time and comes back one time as echo
    // frame_ns = (1+data_bits+stop_bits) * clocks_per_bit * clk_period_ns
    frame_ns = (1 + cfg.data_bits + cfg.stop_bits) * cfg.clocks_per_bit * 10;
    #((n + margin) * frame_ns * 2);

    `uvm_info(get_type_name(), "Test is done, dropping objection now", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass : uart_test
