//==============================================================
// Simple UART TX sequence
// Made by : Alican Yengec
// This sequence sends uart items from sequencer side.
// It also puts expected data to scoreboard mailbox.
//==============================================================

class uart_tx_seq extends uvm_sequence #(uart_seq_item);
  `uvm_object_utils(uart_tx_seq)

  rand int unsigned        n_trans = 5;
  mailbox #(uart_seq_item) exp_mbx;   // set by test side

  function new(string name = "uart_tx_seq");
    super.new(name);
  endfunction

  task body();
    uart_seq_item tr, exp_item;

    repeat (n_trans) begin
      tr = uart_seq_item::type_id::create("tr");
      start_item(tr);

      if (!tr.randomize() with { parity_en == 1'b0; stop_bits == 2'd1; })
        `uvm_fatal("uart_tx_seq", "Randomization failed")

      // Put same byte to expected mailbox for scoreboard
      if (exp_mbx != null) begin
        exp_item      = uart_seq_item::type_id::create("exp");
        exp_item.data = tr.data;
        exp_mbx.put(exp_item);
      end

      finish_item(tr);
    end
  endtask
endclass : uart_tx_seq
