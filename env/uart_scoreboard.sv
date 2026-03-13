//==============================================================
// UART Scoreboard — subscriber pattern
// Made by : Alican Yengec
//
// [CHANGE] Replaced mailbox + tlm_analysis_fifo with two
//   uvm_analysis_imp ports (actual_export, expected_export).
//   Both are driven by write() calls from outside components:
//     actual_export   <- monitor (what DUT produced)
//     expected_export <- ref_model (what we predicted)
//
//   Items are queued internally and matched in arrival order.
//   No more direct coupling to sequence or test layer.
//
// Connection in env:
//   agent.mon.ap    .connect(sb.actual_export)
//   ref_model.ap    .connect(sb.expected_export)
//==============================================================

// Macro required for multiple uvm_analysis_imp in one class
`uvm_analysis_imp_decl(_actual)
`uvm_analysis_imp_decl(_expected)

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  // Two separate analysis import ports
  uvm_analysis_imp_actual   #(uart_seq_item, uart_scoreboard) actual_export;
  uvm_analysis_imp_expected #(uart_seq_item, uart_scoreboard) expected_export;

  // Internal queues — items stored until the other side arrives
  uart_seq_item actual_q[$];
  uart_seq_item expected_q[$];

  int pass_cnt, fail_cnt;

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    actual_export   = new("actual_export",   this);
    expected_export = new("expected_export", this);
  endfunction

  // Called when monitor writes an actual item
  function void write_actual(uart_seq_item tr);
    actual_q.push_back(tr);
    try_compare();
  endfunction

  // Called when ref_model writes an expected item
  function void write_expected(uart_seq_item tr);
    expected_q.push_back(tr);
    try_compare();
  endfunction

  // Compare if both queues have at least one item
  function void try_compare();
    uart_seq_item act, exp;
    while (actual_q.size() > 0 && expected_q.size() > 0) begin
      act = actual_q.pop_front();
      exp = expected_q.pop_front();
      compare(exp, act);
    end
  endfunction

  function void compare(uart_seq_item exp, uart_seq_item act);
    if (!act.framing_ok) begin
      fail_cnt++;
      `uvm_error(get_type_name(),
        $sformatf("FRAMING ERROR  act=%s", act.convert2string()))

    end else if (!act.parity_ok) begin
      fail_cnt++;
      `uvm_error(get_type_name(),
        $sformatf("PARITY ERROR   act=%s", act.convert2string()))

    end else if (act.data !== exp.data) begin
      fail_cnt++;
      `uvm_error(get_type_name(),
        $sformatf("DATA MISMATCH  expected=8'h%02h(%08b)  actual=8'h%02h(%08b)",
                  exp.data, exp.data, act.data, act.data))
    end else begin
      pass_cnt++;
      `uvm_info(get_type_name(),
        $sformatf("PASS [%0d]  data=8'h%02h (%08b)",
                  pass_cnt, act.data, act.data), UVM_LOW)
    end
  endfunction

  function void check_phase(uvm_phase phase);
    if (actual_q.size() > 0)
      `uvm_error(get_type_name(),
        $sformatf("%0d actual item(s) left unmatched in queue", actual_q.size()))
    if (expected_q.size() > 0)
      `uvm_error(get_type_name(),
        $sformatf("%0d expected item(s) left unmatched in queue", expected_q.size()))
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("---- Scoreboard Summary: PASS=%0d  FAIL=%0d ----",
                pass_cnt, fail_cnt), UVM_NONE)
  endfunction

endclass : uart_scoreboard
