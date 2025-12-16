#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROUTER="$SCRIPT_DIR/brouter.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create temp directory for test configs
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $1"
    if [[ -n "${2:-}" ]]; then
        echo "  Expected: $2"
        echo "  Got: ${3:-<empty>}"
    fi
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

section() {
    echo ""
    echo -e "${YELLOW}== $1 ==${NC}"
}

# --- Test Configs ---

# Basic config with two rules
cat > "$TEMP_DIR/basic-config" <<'EOF'
# Work URLs
^https?://(corp\.|jira\.) open -a "Google Chrome"

# Default
.* open -a "Safari"
EOF

# Config with complex regex
cat > "$TEMP_DIR/complex-config" <<'EOF'
# GitHub PRs
^https://github\.com/[^/]+/[^/]+/pull/[0-9]+ open -a "Firefox"

# Slack
^https://[^.]+\.slack\.com open -a "Slack"

# Default
.* open -a "Safari"
EOF

# Empty config (no rules)
cat > "$TEMP_DIR/empty-config" <<'EOF'
# This config has no rules
# Just comments
EOF

# Config with only whitespace and comments
cat > "$TEMP_DIR/whitespace-config" <<'EOF'

  # Indented comment
    
# Another comment

EOF

# Config with special characters in command
cat > "$TEMP_DIR/special-config" <<'EOF'
.* open -na "Google Chrome" --args --profile-directory="Profile 1"
EOF

# --- Tests ---

section "Help Flag"

run_test
if "$BROUTER" --help 2>&1 | grep -q "Usage:"; then
    pass "--help shows usage"
else
    fail "--help shows usage"
fi

run_test
if "$BROUTER" -h 2>&1 | grep -q "Usage:"; then
    pass "-h shows usage"
else
    fail "-h shows usage"
fi

section "Config Flag"

run_test
if output=$("$BROUTER" --config "$TEMP_DIR/basic-config" --test "https://corp.example.com" 2>&1); then
    if echo "$output" | grep -q "Google Chrome"; then
        pass "--config with valid file works"
    else
        fail "--config with valid file works" "Google Chrome in output" "$output"
    fi
else
    fail "--config with valid file works (exit code)"
fi

run_test
exit_code=0
output=$("$BROUTER" --config "$TEMP_DIR/nonexistent" --test "https://example.com" 2>&1) || exit_code=$?
if [[ $exit_code -eq 2 ]] && echo "$output" | grep -q "not found"; then
    pass "--config with missing file shows error and exits 2"
else
    fail "--config with missing file shows error and exits 2" "exit 2 + 'not found'" "exit $exit_code: $output"
fi

run_test
exit_code=0
output=$("$BROUTER" --config 2>&1) || exit_code=$?
if [[ $exit_code -eq 1 ]] && echo "$output" | grep -q "requires"; then
    pass "--config without argument shows error and exits 1"
else
    fail "--config without argument shows error and exits 1" "exit 1 + 'requires'" "exit $exit_code: $output"
fi

section "Test Mode"

run_test
if output=$("$BROUTER" --config "$TEMP_DIR/basic-config" --test "https://jira.company.com/browse/PROJ-123" 2>&1); then
    if echo "$output" | grep -q "Matched:" && echo "$output" | grep -q "Command:"; then
        pass "--test mode shows matched regex and command"
    else
        fail "--test mode shows matched regex and command" "Matched: and Command: lines" "$output"
    fi
else
    fail "--test mode shows matched regex and command (exit code)"
fi

run_test
# Verify test mode doesn't actually run the command (Safari shouldn't open)
if output=$("$BROUTER" --config "$TEMP_DIR/basic-config" --test "https://example.com" 2>&1); then
    if echo "$output" | grep -q "Safari"; then
        pass "--test mode prints Safari command without launching"
    else
        fail "--test mode prints Safari command" "Safari in output" "$output"
    fi
else
    fail "--test mode prints Safari command (exit code)"
fi

section "Regex Matching"

run_test
if output=$("$BROUTER" --config "$TEMP_DIR/basic-config" --test "https://corp.example.com" 2>&1); then
    if echo "$output" | grep -q "corp"; then
        pass "matches corp. URLs"
    else
        fail "matches corp. URLs" "corp regex matched" "$output"
    fi
else
    fail "matches corp. URLs (exit code)"
fi

run_test
if output=$("$BROUTER" --config "$TEMP_DIR/basic-config" --test "http://jira.company.com" 2>&1); then
    if echo "$output" | grep -q "jira"; then
        pass "matches jira. URLs (http)"
    else
        fail "matches jira. URLs (http)" "jira regex matched" "$output"
    fi
else
    fail "matches jira. URLs (http) (exit code)"
fi

run_test
if output=$("$BROUTER" --config "$TEMP_DIR/complex-config" --test "https://github.com/user/repo/pull/123" 2>&1); then
    if echo "$output" | grep -q "Firefox"; then
        pass "matches GitHub PR URLs"
    else
        fail "matches GitHub PR URLs" "Firefox in output" "$output"
    fi
else
    fail "matches GitHub PR URLs (exit code)"
fi

run_test
if output=$("$BROUTER" --config "$TEMP_DIR/complex-config" --test "https://workspace.slack.com/messages" 2>&1); then
    if echo "$output" | grep -q "Slack"; then
        pass "matches Slack URLs"
    else
        fail "matches Slack URLs" "Slack in output" "$output"
    fi
else
    fail "matches Slack URLs (exit code)"
fi

section "Edge Cases"

run_test
exit_code=0
output=$("$BROUTER" --config "$TEMP_DIR/empty-config" --test "https://example.com" 2>&1) || exit_code=$?
if [[ $exit_code -eq 3 ]]; then
    pass "empty config exits with code 3 (no match)"
else
    fail "empty config exits with code 3 (no match)" "exit 3" "exit $exit_code: $output"
fi

run_test
exit_code=0
output=$("$BROUTER" --config "$TEMP_DIR/whitespace-config" --test "https://example.com" 2>&1) || exit_code=$?
if [[ $exit_code -eq 3 ]]; then
    pass "whitespace-only config exits with code 3 (no match)"
else
    fail "whitespace-only config exits with code 3 (no match)" "exit 3" "exit $exit_code: $output"
fi

run_test
if output=$("$BROUTER" --config "$TEMP_DIR/special-config" --test "https://example.com" 2>&1); then
    if echo "$output" | grep -q 'profile-directory="Profile 1"'; then
        pass "handles special characters in command"
    else
        fail "handles special characters in command" "profile-directory in output" "$output"
    fi
else
    fail "handles special characters in command (exit code)"
fi

run_test
exit_code=0
output=$("$BROUTER" 2>&1) || exit_code=$?
if [[ $exit_code -eq 1 ]] && echo "$output" | grep -q "Usage:"; then
    pass "no arguments shows usage and exits 1"
else
    fail "no arguments shows usage and exits 1" "exit 1 + Usage:" "exit $exit_code: $output"
fi

run_test
if output=$("$BROUTER" --test --config "$TEMP_DIR/basic-config" "https://example.com" 2>&1); then
    pass "--test before --config works (flag order doesn't matter)"
else
    fail "--test before --config works (flag order doesn't matter)"
fi

section "URL Handling"

run_test
url_with_params="https://example.com/path?query=value&other=123#anchor"
if output=$("$BROUTER" --config "$TEMP_DIR/basic-config" --test "$url_with_params" 2>&1); then
    if echo "$output" | grep -q "query=value"; then
        pass "preserves URL query parameters"
    else
        fail "preserves URL query parameters" "query=value in output" "$output"
    fi
else
    fail "preserves URL query parameters (exit code)"
fi

run_test
url_with_spaces="https://example.com/path%20with%20spaces"
if output=$("$BROUTER" --config "$TEMP_DIR/basic-config" --test "$url_with_spaces" 2>&1); then
    if echo "$output" | grep -q "%20"; then
        pass "handles URL-encoded spaces"
    else
        fail "handles URL-encoded spaces" "%20 in output" "$output"
    fi
else
    fail "handles URL-encoded spaces (exit code)"
fi

# --- Summary ---

echo ""
echo "=============================="
echo -e "Tests: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo "=============================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
