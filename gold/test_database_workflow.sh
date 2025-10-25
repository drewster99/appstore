#!/bin/bash

# Test script for database-first workflow
# This verifies all components are working correctly

set -e

echo "========================================"
echo "Database Workflow Test Suite"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

test_info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

echo "Test 1: Database Schema"
echo "----------------------------------------"

# Check if tables exist
TABLES=$(sqlite3 ~/.appstore/analytics.db ".tables" 2>/dev/null || echo "")

if echo "$TABLES" | grep -q "apple_reports"; then
    test_pass "apple_reports table exists"
else
    test_fail "apple_reports table missing"
fi

if echo "$TABLES" | grep -q "apple_keywords"; then
    test_pass "apple_keywords table exists"
else
    test_fail "apple_keywords table missing"
fi

if echo "$TABLES" | grep -q "keyword_batches"; then
    test_pass "keyword_batches table exists"
else
    test_fail "keyword_batches table missing"
fi

if echo "$TABLES" | grep -q "batch_keywords"; then
    test_pass "batch_keywords table exists"
else
    test_fail "batch_keywords table missing"
fi

echo ""
echo "Test 2: Imported Data"
echo "----------------------------------------"

# Check if data is imported
REPORT_COUNT=$(sqlite3 ~/.appstore/analytics.db "SELECT COUNT(*) FROM apple_reports" 2>/dev/null || echo "0")
KEYWORD_COUNT=$(sqlite3 ~/.appstore/analytics.db "SELECT COUNT(*) FROM apple_keywords" 2>/dev/null || echo "0")

if [ "$REPORT_COUNT" -gt 0 ]; then
    test_pass "Reports imported: $REPORT_COUNT report(s)"
else
    test_fail "No reports found in database"
fi

if [ "$KEYWORD_COUNT" -gt 0 ]; then
    test_pass "Keywords imported: $KEYWORD_COUNT keyword(s)"
else
    test_fail "No keywords found in database"
fi

# Show report details
if [ "$REPORT_COUNT" -gt 0 ]; then
    test_info "Report details:"
    sqlite3 ~/.appstore/analytics.db \
        "SELECT '  ID: ' || id || ', Month: ' || data_month || ', Locale: ' || user_locale || ', Keywords: ' || total_keywords FROM apple_reports" \
        2>/dev/null || true
fi

echo ""
echo "Test 3: Process Keywords from Database"
echo "----------------------------------------"

# Test process_keywords.py
if python3 process_keywords.py --country "United States" > /tmp/test_keywords.json 2>/tmp/test_keywords.err; then
    KEYWORD_JSON_COUNT=$(python3 -c "import json; data=json.load(open('/tmp/test_keywords.json')); print(data['total_keywords'])" 2>/dev/null || echo "0")

    if [ "$KEYWORD_JSON_COUNT" -gt 0 ]; then
        test_pass "process_keywords.py generated JSON with $KEYWORD_JSON_COUNT keywords"
    else
        test_fail "process_keywords.py generated empty JSON"
        cat /tmp/test_keywords.err
    fi
else
    test_fail "process_keywords.py failed"
    cat /tmp/test_keywords.err
fi

echo ""
echo "Test 4: Generate HTML from Database"
echo "----------------------------------------"

# Test generate_html.py
if python3 generate_html.py --country "United States" -o /tmp/test_report.html 2>/tmp/test_html.err; then
    if [ -f /tmp/test_report.html ] && [ -s /tmp/test_report.html ]; then
        HTML_SIZE=$(ls -lh /tmp/test_report.html | awk '{print $5}')
        test_pass "generate_html.py created HTML report ($HTML_SIZE)"
    else
        test_fail "generate_html.py created empty file"
        cat /tmp/test_html.err
    fi
else
    test_fail "generate_html.py failed"
    cat /tmp/test_html.err
fi

echo ""
echo "Test 5: Batch System"
echo "----------------------------------------"

# Check if we have the test batch
BATCH_COUNT=$(sqlite3 ~/.appstore/analytics.db "SELECT COUNT(*) FROM keyword_batches" 2>/dev/null || echo "0")

if [ "$BATCH_COUNT" -gt 0 ]; then
    test_pass "Batches exist: $BATCH_COUNT batch(es)"

    # Test batch listing
    if python3 commands/batch.py list > /tmp/test_batch_list.txt 2>&1; then
        if grep -q "batch(es)" /tmp/test_batch_list.txt; then
            test_pass "batch.py list command works"
        else
            test_fail "batch.py list produced unexpected output"
        fi
    else
        test_fail "batch.py list command failed"
    fi

    # Test batch status
    if python3 commands/batch.py status 1 > /tmp/test_batch_status.txt 2>&1; then
        if grep -q "Batch #1" /tmp/test_batch_status.txt; then
            test_pass "batch.py status command works"
        else
            test_fail "batch.py status produced unexpected output"
        fi
    else
        test_fail "batch.py status command failed"
    fi
else
    test_info "No batches in database (this is OK for fresh import)"
fi

echo ""
echo "Test 6: Database Integrity"
echo "----------------------------------------"

# Check foreign key constraints
PRAGMA_CHECK=$(sqlite3 ~/.appstore/analytics.db "PRAGMA foreign_key_check" 2>/dev/null || echo "")

if [ -z "$PRAGMA_CHECK" ]; then
    test_pass "Foreign key constraints valid"
else
    test_fail "Foreign key constraint violations found"
    echo "$PRAGMA_CHECK"
fi

# Check for orphaned keywords
ORPHANED=$(sqlite3 ~/.appstore/analytics.db \
    "SELECT COUNT(*) FROM apple_keywords WHERE report_id NOT IN (SELECT id FROM apple_reports)" \
    2>/dev/null || echo "0")

if [ "$ORPHANED" -eq 0 ]; then
    test_pass "No orphaned keywords"
else
    test_fail "Found $ORPHANED orphaned keywords"
fi

echo ""
echo "Test 7: Query Performance"
echo "----------------------------------------"

# Test a few queries
START=$(date +%s%N)
sqlite3 ~/.appstore/analytics.db "SELECT COUNT(*) FROM apple_keywords WHERE total_score >= 8" > /dev/null 2>&1
END=$(date +%s%N)
DURATION=$(( (END - START) / 1000000 ))

if [ "$DURATION" -lt 1000 ]; then
    test_pass "Query performance OK (${DURATION}ms)"
else
    test_info "Query took ${DURATION}ms (consider adding indexes if slow)"
fi

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
else
    echo -e "${GREEN}Failed: 0${NC}"
fi
echo "========================================"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Database workflow is ready to use.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Check output above for details.${NC}"
    exit 1
fi
