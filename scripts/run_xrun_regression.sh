#!/bin/bash
# run_xrun_regression.sh
# Made by : Alican Yengec
#
# Compiles once, then runs all tests back-to-back using the same snapshot.
#
# Test categories:
#   CLEAN  : must produce zero UVM_ERROR and zero UVM_FATAL
#             pass criteria is "TEST PASSED" from scoreboard
#   EXPECT : intentionally produce UVM_ERROR (error injection tests)
#             only UVM_FATAL counts as a real failure here

SNAPSHOT="uart_snap"

CLEAN_TESTS=(
  uart_test
)

EXPECT_TESTS=(
  uart_error_test
)

PASS=()
XFAIL=()
FAIL=()

SUMMARY_LOG="regression_summary.log"
COMPILE_LOG="regression_compile.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

log() { echo "$@" | tee -a "$SUMMARY_LOG"; }

> "$SUMMARY_LOG"

log "============================================"
log "  UART VIP - Full Regression (Xcelium)"
log "  Started : $TIMESTAMP"
log "  Clean   : ${#CLEAN_TESTS[@]} tests"
log "  Expect  : ${#EXPECT_TESTS[@]} tests (protocol errors expected)"
log "============================================"

# ---- Compile once -------------------------------------------
log ""
log "---- Compiling (once) ----"

xrun -f files.f \
  -sv -uvm -access +rwc \
  -timescale 1ns/1ps   \
  -elaborate           \
  -snapshot $SNAPSHOT  \
  > "$COMPILE_LOG" 2>&1

if [ $? -ne 0 ]; then
  log "  COMPILE : FAILED  (see $COMPILE_LOG)"
  exit 1
fi
log "  COMPILE : OK  (log -> $COMPILE_LOG)"

# ---- Run CLEAN tests ----------------------------------------
for TEST in "${CLEAN_TESTS[@]}"; do
  TEST_LOG="regression_${TEST}.log"
  log ""
  log "---- [CLEAN] $TEST ----"

  xrun -R -snapshot $SNAPSHOT \
    +UVM_TESTNAME=$TEST    \
    +UVM_VERBOSITY=UVM_LOW \
    > "$TEST_LOG" 2>&1

  ERR_CNT=$(grep -c "^UVM_ERROR \.\." "$TEST_LOG" 2>/dev/null || echo 0)
  FAT_CNT=$(grep -c "^UVM_FATAL \.\." "$TEST_LOG" 2>/dev/null || echo 0)

  if [ "$ERR_CNT" -eq 0 ] && [ "$FAT_CNT" -eq 0 ] && \
     grep -qE "PASS=[1-9]|PASS=[0-9]{2,}" "$TEST_LOG"; then
    PASS+=("$TEST")
    log "  RESULT : PASS"
  else
    FAIL+=("$TEST")
    log "  RESULT : FAIL  (log -> $TEST_LOG)"
    grep -E "UVM_ERROR|UVM_FATAL|FAIL=" "$TEST_LOG" | head -5 | sed 's/^/    /' | tee -a "$SUMMARY_LOG"
  fi
done

# ---- Run EXPECT tests ---------------------------------------
for TEST in "${EXPECT_TESTS[@]}"; do
  TEST_LOG="regression_${TEST}.log"
  log ""
  log "---- [EXPECT] $TEST ----"

  xrun -R -snapshot $SNAPSHOT \
    +UVM_TESTNAME=$TEST    \
    +UVM_VERBOSITY=UVM_LOW \
    > "$TEST_LOG" 2>&1

  if grep -qE "^UVM_FATAL \.\." "$TEST_LOG"; then
    FAIL+=("$TEST")
    log "  RESULT : FAIL  (unexpected UVM_FATAL — log -> $TEST_LOG)"
    grep -E "^UVM_FATAL \.\." "$TEST_LOG" | head -3 | sed 's/^/    /' | tee -a "$SUMMARY_LOG"
  else
    XFAIL+=("$TEST")
    ERR_CNT=$(grep -c "^UVM_ERROR \.\." "$TEST_LOG" 2>/dev/null || echo 0)
    log "  RESULT : XFAIL  ($ERR_CNT expected UVM_ERROR(s), no UVM_FATAL — OK)"
  fi
done

# ---- Summary ------------------------------------------------
FINISH=$(date "+%Y-%m-%d %H:%M:%S")
log ""
log "============================================"
log "  REGRESSION SUMMARY"
log "  Finished : $FINISH"
log "============================================"
log "  PASS  : ${#PASS[@]}"
for t in "${PASS[@]}";  do log "    [PASS]  $t"; done
log "  XFAIL : ${#XFAIL[@]}  (error injection — UVM_ERROR expected)"
for t in "${XFAIL[@]}"; do log "    [XFAIL] $t"; done
log "  FAIL  : ${#FAIL[@]}"
for t in "${FAIL[@]}";  do log "    [FAIL]  $t"; done
log "============================================"

if [ ${#FAIL[@]} -eq 0 ]; then
  log "  ALL TESTS PASSED"
  exit 0
else
  log "  SOME TESTS FAILED"
  exit 1
fi
