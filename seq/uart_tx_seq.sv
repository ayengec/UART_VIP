//==============================================================
// UART TX Sequence
// Made by : Alican Yengec
//
// Sends items from data_q, which is filled by the test before
// the sequence starts. n_trans is set automatically from queue size.
//==============================================================

class uart_tx_seq extends uvm_sequence #(uart_seq_item);
  `uvm_object_utils(uart_tx_seq)

  // Test fills this queue before calling seq.start()
  logic [7:0] data_q[$];

  function new(string name = "uart_tx_seq");
    super.new(name);
  endfunction

  task body();
    uart_seq_item tr;
    foreach (data_q[i]) begin
      tr           = uart_seq_item::type_id::create("tr");
      tr.data      = data_q[i];
      tr.parity_en = 1'b0;
      tr.stop_bits = 1;
      start_item(tr);
      finish_item(tr);
    end
  endtask

endclass : uart_tx_seq
