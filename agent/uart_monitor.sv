//==============================================================
// Simple UART monitor
// Made by : Alican Yengec
// This monitor watches UART rx line and collects one frame.
// It also updates debug signals, so byte build can easy seen.
//==============================================================

class uart_monitor extends uvm_component;
  `uvm_component_utils(uart_monitor)

  uart_cfg        cfg;
  virtual uart_if vif;
  uvm_analysis_port #(uart_seq_item) ap;

  function new(string name = "uart_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(uart_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "uart_cfg not found in config_db")
    vif = cfg.vif;
    if (vif == null)
      `uvm_fatal(get_type_name(), "virtual interface handle is null")
  endfunction

  task automatic wait_clks(int unsigned n);
    repeat (n) @(posedge vif.clk);
  endtask

  function automatic bit calc_parity(bit [7:0] d);
    return ^d;
  endfunction

  // Sample one frame
  task sample_rx_frame();
    uart_seq_item tr;
    bit parity_bit, exp_parity;

    tr             = uart_seq_item::type_id::create("tr");
    tr.parity_en   = cfg.parity_en;
    tr.parity_odd  = cfg.parity_odd;
    tr.stop_bits   = cfg.stop_bits;
    tr.parity_ok   = 1'b1;
    tr.framing_ok  = 1'b1;

    // Clear debug signals, new frame is starting
    vif.mon_rx_shift   <= 8'h00;
    vif.mon_rx_bit_cnt <= 4'd0;

    // Go to middle of start bit
    wait_clks((cfg.clocks_per_bit + 1) / 2);
    if (vif.rx !== 1'b0) begin
      `uvm_warning(get_type_name(), "Fake start bit, ignore it")
      return;
    end

    // Sample data bits
    // After each bit, debug signals are updated.
    // So in wave, byte forming can be seen step by step.
    for (int i = 0; i < cfg.data_bits; i++) begin
      wait_clks(cfg.clocks_per_bit);
      tr.data[i]         = vif.rx;           // LSB first

      // Parallel debug, live shift register update
      vif.mon_rx_shift   <= tr.data;         // partial byte as vector
      vif.mon_rx_bit_cnt <= 4'(i + 1);       // how many bits done
    end

    // Parity part
    if (cfg.parity_en) begin
      wait_clks(cfg.clocks_per_bit);
      parity_bit = vif.rx;
      exp_parity = calc_parity(tr.data);
      if (!cfg.parity_odd) exp_parity = ~exp_parity;
      tr.parity_ok = (parity_bit == exp_parity);
    end

    // Stop bit or bits
    repeat (cfg.stop_bits) begin
      wait_clks(cfg.clocks_per_bit);
      if (vif.rx !== 1'b1)
        tr.framing_ok = 1'b0;
    end

    // Parallel debug for full byte pulse
    // mon_rx_valid goes high for 1 clock.
    // mon_rx_data is valid in this time.
    vif.mon_rx_data  <= tr.data;
    vif.mon_rx_valid <= 1'b1;
    @(posedge vif.clk);
    vif.mon_rx_valid <= 1'b0;

    // Write to analysis port for scoreboard or others
    ap.write(tr);
    `uvm_info(get_type_name(),
              $sformatf("Captured item <- %s", tr.convert2string()), UVM_MEDIUM)
  endtask

  task run_phase(uvm_phase phase);
    bit prev_rx;
    prev_rx = 1'b1;

    // Initial values for debug signals
    vif.mon_rx_data    <= 8'h00;
    vif.mon_rx_valid   <= 1'b0;
    vif.mon_rx_shift   <= 8'h00;
    vif.mon_rx_bit_cnt <= 4'd0;

    wait(vif.rst_n === 1'b1);

    forever begin
      @(posedge vif.clk);
      if (!vif.rst_n) begin
        prev_rx = 1'b1;
        continue;
      end

      // Falling edge means start bit begin
      if (prev_rx == 1'b1 && vif.rx == 1'b0)
        sample_rx_frame();

      prev_rx = vif.rx;
    end
  endtask
endclass : uart_monitor
