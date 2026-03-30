package uart_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum logic {
    UART_PASSIVE = 1'b0,
    UART_ACTIVE  = 1'b1
  } uart_agent_mode_e;

  // Common
  `include "../common/uart_seq_item.sv"
  `include "../common/uart_cfg.sv"
  `include "../common/uart_error_seq_item.sv"   // error injection fields

  // Agent
  `include "../agent/uart_sequencer.sv"
  `include "../agent/uart_driver.sv"
  `include "../agent/uart_error_driver.sv"      // extends uart_driver
  `include "../agent/uart_monitor.sv"
  `include "../agent/uart_agent.sv"

  // Sequences
  `include "../seq/uart_tx_seq.sv"
  `include "../seq/uart_error_seq.sv"           // error injection sequences

  // Environment
  `include "../env/uart_scoreboard.sv"
  `include "../env/uart_coverage.sv"            // functional coverage
  `include "../env/uart_env.sv"

  // Tests
  `include "../tests/uart_test.sv"
  `include "../tests/uart_error_test.sv"        // error injection test

endpackage : uart_vip_pkg
