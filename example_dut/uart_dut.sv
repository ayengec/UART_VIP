//==============================================================
// Simple UART Delayed Echo DUT
// Made by : Alican Yengec
// basically receives a byte and sends it back, thats it
// RX grabs the incoming serial data, puts it in a small buffer,
// then TX picks it up and shoots it back out
// added a delay parameter so TX doesnt fire immediately after RX done
//==============================================================

module uart_dut #(
  parameter int CLKS_PER_BIT = 16,   // how many clocks per one uart bit
  parameter int DATA_BITS    = 8,    // data width, probably always 8 but just in case
  parameter int ECHO_DELAY   = 10    // wait this many clocks before echoing back
)(
  input  logic clk,
  input  logic rst_n,

  // serial lines
  input  logic rxd,   // comes from VIP driver (uart_if.tx)
  output logic txd,   // goes back to VIP monitor (uart_if.rx)

  // these are debug outputs so you can see whats happening in the wave
  // without having to decode the serial line manually
  output logic [DATA_BITS-1:0] dbg_rx_shift,    // shift reg filling up as bits come in
  output logic                 dbg_rx_valid,    // pulses high when a full byte is done
  output logic [3:0]           dbg_rx_bit_idx,  // which bit we are sampling right now
  output logic [1:0]           dbg_rx_state,    // rx fsm state, 0=idle 1=start 2=data 3=stop

  output logic [DATA_BITS-1:0] dbg_tx_shift,    // the byte we are currently sending
  output logic                 dbg_tx_active,   // tx is busy sending something
  output logic [3:0]           dbg_tx_bit_idx,  // which bit tx is on right now
  output logic [1:0]           dbg_tx_state     // tx fsm state, same encoding as rx
);

  // -------------------------------------------------------
  // signal declarations, all in one place to avoid mess
  // -------------------------------------------------------

  // rx fsm stuff
  typedef enum logic [1:0] {
    RX_IDLE  = 2'd0,
    RX_START = 2'd1,
    RX_DATA  = 2'd2,
    RX_STOP  = 2'd3
  } rx_state_e;

  rx_state_e                           rx_state;
  logic [DATA_BITS-1:0]                rx_shift;       // building the byte here bit by bit
  logic [3:0]                          rx_bit_cnt;     // counts up to DATA_BITS-1
  logic [$clog2(CLKS_PER_BIT+1)-1:0]  rx_clk_cnt;     // clock divider counter
  logic                                rx_done;        // 1 cycle pulse when byte is complete
  logic [DATA_BITS-1:0]                rx_data_latch;  // holds the byte until fifo takes it

  // fifo and delay counter
  logic                                tx_fifo_valid;  // there is something waiting to be sent
  logic [DATA_BITS-1:0]                tx_fifo_data;   // the actual data waiting
  logic                                tx_load_ack;    // tx fsm says "i took it"
  logic [$clog2(ECHO_DELAY+1)-1:0]     delay_cnt;      // counts down before enabling fifo
  logic                                delay_active;   // delay is still counting down

  // tx fsm stuff
  typedef enum logic [1:0] {
    TX_IDLE  = 2'd0,
    TX_START = 2'd1,
    TX_DATA  = 2'd2,
    TX_STOP  = 2'd3
  } tx_state_e;

  tx_state_e                           tx_state;
  logic [DATA_BITS-1:0]                tx_shift;    // byte being shifted out right now
  logic [3:0]                          tx_bit_cnt;  // which bit we are on
  logic [$clog2(CLKS_PER_BIT+1)-1:0]  tx_clk_cnt;  // baud rate divider for tx

  // -------------------------------------------------------
  // RX FSM
  // waits for start bit, samples each data bit at mid-point,
  // checks stop bit, then fires rx_done for one clock
  // -------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_state      <= RX_IDLE;
      rx_shift      <= '0;
      rx_bit_cnt    <= '0;
      rx_clk_cnt    <= '0;
      rx_done       <= 1'b0;
      rx_data_latch <= '0;
    end else begin
      rx_done <= 1'b0;  // default, only high for one clock when byte finishes

      case (rx_state)

        // sit here until line goes low (start bit)
        RX_IDLE: begin
          if (rxd == 1'b0) begin
            rx_clk_cnt <= CLKS_PER_BIT[$clog2(CLKS_PER_BIT+1)-1:0] / 2;  // jump to middle of start bit
            rx_state   <= RX_START;
          end
        end

        // make sure the start bit is still low at mid-point
        // if it went high already it was probably noise, go back to idle
        RX_START: begin
          if (rx_clk_cnt == '0) begin
            if (rxd == 1'b0) begin
              rx_clk_cnt <= CLKS_PER_BIT[$clog2(CLKS_PER_BIT+1)-1:0] - 1'b1;
              rx_bit_cnt <= '0;
              rx_shift   <= '0;
              rx_state   <= RX_DATA;
            end else begin
              rx_state   <= RX_IDLE;  // false start, bail out
            end
          end else begin
            rx_clk_cnt <= rx_clk_cnt - 1'b1;
          end
        end

        // sample each bit at the middle, lsb first
        RX_DATA: begin
          if (rx_clk_cnt == '0) begin
            rx_clk_cnt           <= CLKS_PER_BIT[$clog2(CLKS_PER_BIT+1)-1:0] - 1'b1;
            rx_shift[rx_bit_cnt] <= rxd;  // grab the bit
            if (rx_bit_cnt == DATA_BITS[3:0] - 1'b1) begin
              rx_state <= RX_STOP;  // got all bits, now check stop
            end else begin
              rx_bit_cnt <= rx_bit_cnt + 1'b1;
            end
          end else begin
            rx_clk_cnt <= rx_clk_cnt - 1'b1;
          end
        end

        // stop bit should be high, if it is we latch the data and pulse rx_done
        // if its low something went wrong with framing but we just go back to idle anyway
        RX_STOP: begin
          if (rx_clk_cnt == '0) begin
            if (rxd == 1'b1) begin
              rx_data_latch <= rx_shift;
              rx_done       <= 1'b1;  // tell the fifo a byte is ready
            end
            rx_state <= RX_IDLE;
          end else begin
            rx_clk_cnt <= rx_clk_cnt - 1'b1;
          end
        end

        default: rx_state <= RX_IDLE;
      endcase
    end
  end

  // -------------------------------------------------------
  // Echo delay + 1-deep FIFO
  // when rx_done comes in we start a countdown, once it hits
  // zero we tell the tx fsm there is data to send
  // only holds one byte at a time, if another comes in before
  // tx is done it will get dropped (not ideal but fine for testing)
  // -------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_fifo_valid <= 1'b0;
      tx_fifo_data  <= '0;
      delay_cnt     <= '0;
      delay_active  <= 1'b0;
    end else begin

      // new byte arrived, store it and start the delay counter
      if (rx_done && !delay_active) begin
        tx_fifo_data <= rx_data_latch;
        delay_cnt    <= ECHO_DELAY[$clog2(ECHO_DELAY+1)-1:0];
        delay_active <= 1'b1;
      end

      // counting down, when we hit zero release the data to tx
      if (delay_active) begin
        if (delay_cnt == '0) begin
          tx_fifo_valid <= 1'b1;   // ok tx, you can go now
          delay_active  <= 1'b0;
        end else begin
          delay_cnt <= delay_cnt - 1'b1;
        end
      end

      // tx fsm grabbed the data, clear the valid flag
      if (tx_load_ack) begin
        tx_fifo_valid <= 1'b0;
      end

    end
  end

  // -------------------------------------------------------
  // TX FSM
  // pretty much the mirror of RX
  // idles until fifo has something, then sends start + data + stop
  // -------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state    <= TX_IDLE;
      tx_shift    <= '0;
      tx_bit_cnt  <= '0;
      tx_clk_cnt  <= '0;
      tx_load_ack <= 1'b0;
      txd         <= 1'b1;  // line high when idle, this is uart default
    end else begin
      tx_load_ack <= 1'b0;  // only high for one clock when we grab from fifo

      case (tx_state)

        // nothing to send, keep line high
        // when fifo becomes valid, grab the byte and pull line low (start bit)
        TX_IDLE: begin
          txd <= 1'b1;
          if (tx_fifo_valid) begin
            tx_shift    <= tx_fifo_data;
            tx_load_ack <= 1'b1;  // tell fifo we took it
            tx_clk_cnt  <= CLKS_PER_BIT[$clog2(CLKS_PER_BIT+1)-1:0] - 1'b1;
            txd         <= 1'b0;  // start bit
            tx_state    <= TX_START;
          end
        end

        // just waiting out the start bit duration
        TX_START: begin
          if (tx_clk_cnt == '0) begin
            tx_clk_cnt <= CLKS_PER_BIT[$clog2(CLKS_PER_BIT+1)-1:0] - 1'b1;
            tx_bit_cnt <= '0;
            txd        <= tx_shift[0];  // first data bit, lsb first
            tx_state   <= TX_DATA;
          end else begin
            tx_clk_cnt <= tx_clk_cnt - 1'b1;
          end
        end

        // shift out each bit one by one
        TX_DATA: begin
          if (tx_clk_cnt == '0) begin
            tx_clk_cnt <= CLKS_PER_BIT[$clog2(CLKS_PER_BIT+1)-1:0] - 1'b1;
            if (tx_bit_cnt == DATA_BITS[3:0] - 1'b1) begin
              txd      <= 1'b1;   // all bits done, send stop bit
              tx_state <= TX_STOP;
            end else begin
              tx_bit_cnt <= tx_bit_cnt + 1'b1;
              txd        <= tx_shift[tx_bit_cnt + 1'b1];
            end
          end else begin
            tx_clk_cnt <= tx_clk_cnt - 1'b1;
          end
        end

        // hold the stop bit for one bit period then go back to idle
        TX_STOP: begin
          if (tx_clk_cnt == '0) begin
            tx_state <= TX_IDLE;
          end else begin
            tx_clk_cnt <= tx_clk_cnt - 1'b1;
          end
        end

        default: tx_state <= TX_IDLE;
      endcase
    end
  end

  // -------------------------------------------------------
  // wire up the debug outputs
  // just direct connections to internal signals, no logic here
  // -------------------------------------------------------
  assign dbg_rx_shift    = rx_shift;
  assign dbg_rx_valid    = rx_done;
  assign dbg_rx_bit_idx  = rx_bit_cnt;
  assign dbg_rx_state    = rx_state;

  assign dbg_tx_shift    = tx_shift;
  assign dbg_tx_active   = (tx_state != TX_IDLE);
  assign dbg_tx_bit_idx  = tx_bit_cnt;
  assign dbg_tx_state    = tx_state;

endmodule : uart_dut
