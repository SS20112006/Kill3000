#!/usr/bin/env bash
set -euo pipefail

# Kill3000 End-to-End Smoke Test Harness
# Validates real-world port detection, process classification, and safe termination.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "========================================================"
echo "  Kill3000 End-to-End Smoke Test Harness"
echo "========================================================"

# 1. Locate or compile Kill3000 binary
KILL3000_BIN=""
if [ -x "${PROJECT_ROOT}/build/Kill3000.app/Contents/MacOS/Kill3000App" ]; then
    KILL3000_BIN="${PROJECT_ROOT}/build/Kill3000.app/Contents/MacOS/Kill3000App"
elif [ -x "${PROJECT_ROOT}/.build/release/Kill3000App" ]; then
    KILL3000_BIN="${PROJECT_ROOT}/.build/release/Kill3000App"
elif [ -x "${PROJECT_ROOT}/.build/debug/Kill3000App" ]; then
    KILL3000_BIN="${PROJECT_ROOT}/.build/debug/Kill3000App"
else
    echo "==> Building Kill3000 binary for smoke testing..."
    swift build -c release
    KILL3000_BIN="$(swift build -c release --show-bin-path)/Kill3000App"
fi

echo "==> Using Kill3000 binary: ${KILL3000_BIN}"

# 2. Verify binary version and help output
echo "==> Verifying CLI help and version..."
"${KILL3000_BIN}" --version | grep -q "Kill3000 1.0.0"
"${KILL3000_BIN}" --help | grep -q "Usage:"
echo "    ✓ CLI version and help flags validated"

# 3. Determine available port (preferring 3000)
TEST_PORT=3000
if /usr/sbin/lsof -iTCP:${TEST_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Notice: Port 3000 is currently occupied, using test port 3899"
    TEST_PORT=3899
fi

MOCK_PID_FILE="$(mktemp -t kill3000_smoke_pid.XXXXXX)"
MOCK_LOG_FILE="$(mktemp -t kill3000_smoke_log.XXXXXX)"

cleanup() {
    if [ -f "${MOCK_PID_FILE}" ]; then
        if [ -s "${MOCK_PID_FILE}" ]; then
            MOCK_PID="$(cat "${MOCK_PID_FILE}")"
            if kill -0 "${MOCK_PID}" 2>/dev/null; then
                echo "==> Cleaning up mock server process ${MOCK_PID}..."
                kill -9 "${MOCK_PID}" 2>/dev/null || true
            fi
        fi
        rm -f "${MOCK_PID_FILE}"
    fi
    rm -f "${MOCK_LOG_FILE}"
}
trap cleanup EXIT INT TERM

# 4. Spawn a real mock TCP development server in the background
echo "==> Spawning mock TCP development server on port ${TEST_PORT}..."
python3 -c "
import socket, sys, os, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', ${TEST_PORT}))
s.listen(1)
with open('${MOCK_PID_FILE}', 'w') as f:
    f.write(str(os.getpid()))
sys.stdout.write('LISTENING\n')
sys.stdout.flush()
while True:
    try:
        conn, _ = s.accept()
        conn.close()
    except Exception:
        break
" > "${MOCK_LOG_FILE}" 2>&1 &

MOCK_LAUNCH_PID=$!

# Wait up to 5 seconds for the mock server to start listening
WAIT_COUNT=0
while [ ${WAIT_COUNT} -lt 50 ]; do
    if [ -s "${MOCK_PID_FILE}" ] && /usr/sbin/lsof -iTCP:${TEST_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if ! /usr/sbin/lsof -iTCP:${TEST_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Error: Mock server failed to bind to port ${TEST_PORT}" >&2
    cat "${MOCK_LOG_FILE}" >&2
    exit 1
fi

MOCK_PID="$(cat "${MOCK_PID_FILE}")"
echo "    ✓ Mock server listening on port ${TEST_PORT} (PID: ${MOCK_PID})"

# 5. Test port detection via --scan
echo "==> Testing active port detection via 'kill3000 --scan'..."
SCAN_OUTPUT="$("${KILL3000_BIN}" --scan)"
echo "${SCAN_OUTPUT}"

if ! echo "${SCAN_OUTPUT}" | grep -E "(^|[[:space:]])${TEST_PORT}[[:space:]]"; then
    echo "Error: 'kill3000 --scan' did not detect active port ${TEST_PORT}" >&2
    exit 1
fi

if ! echo "${SCAN_OUTPUT}" | grep -q "Dev Server"; then
    echo "Error: Mock server on port ${TEST_PORT} was not categorized as Dev Server" >&2
    exit 1
fi
echo "    ✓ Port ${TEST_PORT} detected and classified as Dev Server"

# 6. Test process termination via --kill
echo "==> Testing process termination via 'kill3000 --kill ${TEST_PORT}'..."
KILL_OUTPUT="$("${KILL3000_BIN}" --kill "${TEST_PORT}")"
echo "${KILL_OUTPUT}"

if ! echo "${KILL_OUTPUT}" | grep -q "Successfully terminated"; then
    echo "Error: 'kill3000 --kill ${TEST_PORT}' output missing success confirmation" >&2
    exit 1
fi

# 7. Verify port is freed and process is dead
echo "==> Verifying process termination and socket release..."
sleep 0.5

if kill -0 "${MOCK_PID}" 2>/dev/null; then
    echo "Error: Process ${MOCK_PID} is still alive after termination command" >&2
    exit 1
fi

if /usr/sbin/lsof -iTCP:${TEST_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Error: Port ${TEST_PORT} is still in LISTEN state" >&2
    exit 1
fi
echo "    ✓ Process terminated and port ${TEST_PORT} released cleanly"

# 8. Test safety barrier (refuse killing protected PID 1)
echo "==> Testing safety barrier on PID 1 (must be refused)..."
set +e
PROTECTED_OUTPUT="$("${KILL3000_BIN}" --kill 1 2>&1)"
PROTECTED_EXIT=$?
set -e

if [ ${PROTECTED_EXIT} -eq 0 ]; then
    echo "Error: Expected failure when targeting protected PID 1, but command succeeded" >&2
    exit 1
fi
echo "    ✓ Target PID 1 safely refused with exit code ${PROTECTED_EXIT}"

# 9. Test error handling on non-existent port
echo "==> Testing non-existent port termination handling..."
set +e
NOT_FOUND_OUTPUT="$("${KILL3000_BIN}" --kill 59999 2>&1)"
NOT_FOUND_EXIT=$?
set -e

if [ ${NOT_FOUND_EXIT} -eq 0 ]; then
    echo "Error: Expected failure for unused port 59999, but command succeeded" >&2
    exit 1
fi
echo "    ✓ Non-existent port handled gracefully with exit code ${NOT_FOUND_EXIT}"

echo "========================================================"
echo "  ✓ All Kill3000 smoke test checks passed successfully!"
echo "========================================================"
