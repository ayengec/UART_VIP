//==============================================================
// Simple UART driver
// Made by : Alican Yengec
//
// Gets item from sequencer and drives the UART TX line.
// No analysis port — expected items are managed by the test.
//==============================================================

class uart_driver extends uvm_driver #(uart_seq_item);
  `uvm_component_utils(uart_driver)

  uart_cfg        cfg;
  virtual uart_if vif;

  function new(string name = "uart_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(uart_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "uart_cfg not found in config_db")
    vif = cfg.vif;
    if (vif == null)
      `uvm_fatal(get_type_name(), "virtual interface handle is null")
  endfunction

  task automatic wait_bit();
    repeat (cfg.clocks_per_bit) @(posedge vif.clk);
  endtask

  function automatic bit calc_parity(bit [7:0] d);
    return ^d;
  endfunction

  task drive_item(uart_seq_item tr);
    @(negedge vif.clk);
    vif.drv_tx_data  <= tr.data;
    vif.drv_tx_valid <= 1'b1;
    @(posedge vif.clk);
    vif.drv_tx_valid <= 1'b0;

    // Start bit
    vif.tx <= 1'b0;
    wait_bit();

    // Data bits, LSB first
    for (int i = 0; i < cfg.data_bits; i++) begin
      vif.tx <= tr.data[i];
      wait_bit();
    end

    // Parity bit (if enabled)
    if (cfg.parity_en) begin
      automatic bit p;
      p = calc_parity(tr.data);
      if (!cfg.parity_odd) p = ~p;
      vif.tx <= p;
      wait_bit();
    end

    // Stop bit(s)
    vif.tx <= 1'b1;
    repeat (cfg.stop_bits) wait_bit();
  endtask

  task run_phase(uvm_phase phase);
    uart_seq_item tr;
    vif.tx           <= 1'b1;
    vif.drv_tx_data  <= 8'h00;
    vif.drv_tx_valid <= 1'b0;

    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info(get_type_name(),
                $sformatf("Driving -> %s", tr.convert2string()), UVM_HIGH)
      drive_item(tr);
      seq_item_port.item_done();
    end
  endtask

endclass : uart_driver
