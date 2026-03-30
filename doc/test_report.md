# UART VIP Test Report — v2

## Info

| | |
|---|---|
| Project | UART VIP v2 |
| Author | |
| Date | |
| Version | v2 |
| Simulator | |
| UVM Version | |
| Seed | |

---

## Environment

Components active in this run:

- `uart_if` (with parallel debug signals + assertion bind)
- `uart_agent` (active mode)
- `uart_sequencer`
- `uart_driver` / `uart_error_driver` (via factory override in error test)
- `uart_monitor`
- `uart_scoreboard`
- `uart_coverage`
- `uart_assertions` (bound to `uart_if`)
- `uart_env`
- `uart_test` / `uart_error_test`
- `uart_dut` (echo DUT)
- `example_tb_top`

**UART config:**

| Field | Value |
|-------|-------|
| Mode | active |
| Data bits | 8 |
| Parity | disabled (uart_test) / enabled for bad_parity frame (uart_error_test) |
| Stop bits | 1 |
| Clocks per bit | 16 |
| Echo delay | 10 clocks |

---

## Regression Results

| Test | Category | Result | UVM_ERROR | UVM_FATAL | Notes |
|------|----------|--------|-----------|-----------|-------|
| `uart_test` | CLEAN | | | | |
| `uart_error_test` | EXPECT | | | | UVM_ERROR expected |

---

## Detailed Results

### `uart_test`

- **Bytes sent:** 0xE6, 0xA5, 0x3C
- **Scoreboard:** PASS= FAIL=
- **Coverage summary:**

| Covergroup | % |
|------------|---|
| cg_data_value | |
| cg_frame_integrity | |
| cg_parity_cfg | |
| cg_stop_bits | |
| cg_data_transitions | |
| cg_error_types | |
| TOTAL | |

- **Assertions fired:** (none expected)
- **Status:**

---

### `uart_error_test`

Sequence: `clean(AA) → bad_stop(DE) → clean(55) → bad_parity(BE) → clean(CC) → glitch+clean(AB) → clean(12) → break → clean(FF)`

| Frame | Type | Expected scoreboard response | Actual |
|-------|------|------------------------------|--------|
| AA | clean | PASS | |
| DE | bad stop | FRAMING ERROR | |
| 55 | clean recovery | PASS | |
| BE | bad parity | PARITY ERROR | |
| CC | clean recovery | PASS | |
| glitch | glitch | AST_START_BIT_WIDTH fires | |
| AB | clean (after glitch) | PASS | |
| 12 | clean | PASS | |
| break | break | no echo expected | |
| FF | clean recovery | PASS | |

- **UVM_FATAL count:** (must be 0)
- **UVM_ERROR count:** (expected: ≥2 — framing + parity)
- **Coverage summary:**

| Covergroup | % |
|------------|---|
| cg_data_value | |
| cg_frame_integrity | |
| cg_parity_cfg | |
| cg_stop_bits | |
| cg_data_transitions | |
| cg_error_types | |
| TOTAL | |

- **Status:**

---

## Assertion Summary

| Assertion | `uart_test` | `uart_error_test` | Expected? |
|-----------|-------------|-------------------|-----------|
| AST_TX_IDLE_AFTER_RESET | | | no fire |
| AST_RX_IDLE_AFTER_RESET | | | no fire |
| AST_RX_NO_X | | | no fire |
| AST_START_BIT_WIDTH | | | fire on glitch |
| AST_TX_IDLE_BEFORE_START | | | no fire |
| AST_STOP_BIT_ARRIVES | | | fire on bad_stop |
| AST_STOP_BIT_MIN_WIDTH | | | no fire |
| AST_DRV_VALID_SINGLE_CYCLE | | | no fire |
| AST_MON_VALID_SINGLE_CYCLE | | | no fire |
| AST_ECHO_LATENCY_BOUND | | | no fire |
| AST_RX_DATA_NO_X_WHEN_VALID | | | no fire |

---

## Coverage Summary (combined both tests)

| Covergroup | Target | Actual |
|------------|--------|--------|
| cg_data_value | 70% | |
| cg_frame_integrity | 100% | |
| cg_parity_cfg | 50% | |
| cg_stop_bits | 50% | |
| cg_data_transitions | 30% | |
| cg_error_types | 100% | |

**Coverage gaps and plan to close them:**

| Gap | Plan |
|-----|------|
| | |

---

## Error Summary

| Category | Count |
|----------|-------|
| Scoreboard data mismatches (unexpected) | |
| Scoreboard framing errors (expected in error_test) | |
| Scoreboard parity errors (expected in error_test) | |
| Simulation timeouts | |
| Unexpected UVM_FATAL | |

---

## Debug Notes

*(unexpected wave behavior, timing oddities, things that needed a second look)*

---

## Open Issues

| ID | Description | Severity | Status |
|----|-------------|----------|--------|
| 1 | | | |

---

## Conclusion

*(fill after running)*

---

## Sign-Off

| | |
|---|---|
| Prepared by | |
| Reviewed by | |
| Date | |
