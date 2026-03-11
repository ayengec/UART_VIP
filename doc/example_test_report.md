# UART VIP Test Report

## Info

| | |
|---|---|
| Project | UART VIP |
| Author | |
| Date | |
| Version | |
| Simulator | |
| UVM Version | |

---

## What was tested

Basic UART VIP functionality — driving frames, monitoring them, scoreboard comparison. First version targets 8N1 only.

---

## Environment

- uart_if (with parallel debug signals)
- uart_agent (active mode)
- uart_sequencer
- uart_driver
- uart_monitor
- uart_scoreboard
- uart_env
- uart_test
- uart_dut (echo DUT, ECHO_DELAY=10)
- example_tb_top

**UART config used:**

| Field | Value |
|-------|-------|
| Mode | active |
| Data bits | 8 |
| Parity | disabled |
| Stop bits | 1 |
| Clocks per bit | 16 |
| Echo delay | 10 clocks |

---

## Test Results

| Test | Result | Notes |
|------|--------|-------|
| smoke_8n1_single_byte | | |
| smoke_8n1_multi_byte | | |
| random_8n1_data | | |
| framing_error_test | | |
| reset_behavior_test | | |

---

## Detailed Results

### smoke_8n1_single_byte
- **What:** single byte sent, echo captured, scoreboard compared
- **Stimulus:** 
- **Expected:** 
- **Actual:** 
- **Scoreboard:** 
- **Status:** 

---

### smoke_8n1_multi_byte
- **What:** multiple bytes sent back to back, all echoes captured in order
- **Stimulus:** 
- **Expected:** 
- **Actual:** 
- **Scoreboard:** 
- **Status:** 

---

### random_8n1_data
- **What:** randomized byte values, checked that all matched
- **Seed used:** 
- **Stimulus:** 
- **Expected:** 
- **Actual:** 
- **Scoreboard:** 
- **Status:** 

---

### framing_error_test
- **What:** bad stop bit injected, checked monitor detects it
- **How error injected:** 
- **Monitor response:** 
- **Scoreboard response:** 
- **Status:** 

---

### reset_behavior_test
- **What:** reset asserted mid-frame, then clean frame sent after reset
- **Reset timing:** 
- **Post-reset behavior:** 
- **Status:** 

---

## Error Summary

**Scoreboard mismatches:** 
**Framing errors:** 
**Parity errors:** 
**Simulation timeouts:** 
**UVM fatals:** 

---

## Coverage

Functional coverage is not implemented in this version.

---

## Debug Notes

Put anything weird here — unexpected wave behavior, timing issues, things that needed a second look.

---

## Open Issues

| ID | Description | Severity | Status |
|----|-------------|----------|--------|
| 1 | | | |
| 2 | | | |

---

## Conclusion

*(fill after running tests)*

---

## Sign-Off

| | |
|---|---|
| Prepared by | |
| Reviewed by | |
| Date | |
