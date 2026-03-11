//==============================================================
// Simple UART scoreboard
// Made by : Alican Yengec
// This scoreboard compares expected and actual uart items.
// Expected items come from sequence side.
// Actual items come from monitor side.
//==============================================================

class uart_scoreboard extends uvm_component;
  `uvm_component_utils(uart_scoreboard)

  uvm_tlm_analysis_fifo #(uart_seq_item) actual_fifo;
  mailbox #(uart_seq_item)               exp_mbx;

  int pass_cnt, fail_cnt;

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    actual_fifo = new("actual_fifo", this);
    exp_mbx     = new();
  endfunction

  task run_phase(uvm_phase phase);
    uart_seq_item exp_item, act_item;

    forever begin
      // Match expected and actual in same order
      exp_mbx.get(exp_item);
      actual_fifo.get(act_item);

      if (!act_item.framing_ok) begin
        fail_cnt++;
        `uvm_error(get_type_name(),
          $sformatf("FRAMING ERROR  act=%s", act_item.convert2string()))

      end else if (!act_item.parity_ok) begin
        fail_cnt++;
        `uvm_error(get_type_name(),
          $sformatf("PARITY ERROR   act=%s", act_item.convert2string()))

      end else if (act_item.data !== exp_item.data) begin
        fail_cnt++;
        `uvm_error(get_type_name(),
          $sformatf("DATA MISMATCH  expected=8'h%02h(%08b)  actual=8'h%02h(%08b)",
                    exp_item.data, exp_item.data, act_item.data, act_item.data))
      end else begin
        pass_cnt++;
        `uvm_info(get_type_name(),
          $sformatf("PASS [%0d]  data=8'h%02h (%08b)",
                    pass_cnt, act_item.data, act_item.data), UVM_LOW)
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("---- Scoreboard Summary: PASS=%0d  FAIL=%0d ----",
                pass_cnt, fail_cnt), UVM_NONE)
  endfunction
endclass : uart_scoreboard
