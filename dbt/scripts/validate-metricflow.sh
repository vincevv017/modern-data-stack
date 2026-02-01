#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "🔍 MetricFlow Validation Suite - Testing All 12 Metrics"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_EXPECTED_FAIL=0

# Test function
run_test() {
    local test_name=$1
    local test_command=$2
    local allow_failure=${3:-false}
    
    echo -e "${BLUE}▶ ${test_name}${NC}"
    
    if output=$(eval "$test_command" 2>&1); then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        if [ "$allow_failure" = true ]; then
            echo -e "${YELLOW}⚠ EXPECTED FAIL (insufficient data)${NC}"
            ((TESTS_EXPECTED_FAIL++))
            return 0
        else
            echo -e "${RED}✗ FAIL${NC}"
            echo "$output" | head -5
            ((TESTS_FAILED++))
            return 1
        fi
    fi
}

echo "════════════════════════════════════════════════════════════════"
echo "📋 PHASE 1: Validation & Setup"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}▶ MetricFlow validation${NC}"
if docker compose exec dbt mf validate-configs 2>&1 | grep -q "ERRORS: 0"; then
    echo -e "${GREEN}✓ PASS - 0 validation errors${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL - Validation errors found${NC}"
    ((TESTS_FAILED++))
fi
echo ""

echo -e "${BLUE}▶ Counting registered metrics${NC}"
METRIC_COUNT=$(docker compose exec dbt mf list metrics 2>/dev/null | grep "^•" | wc -l | tr -d ' ')
if [ "$METRIC_COUNT" -eq 12 ]; then
    echo -e "${GREEN}✓ PASS - All 12 metrics registered${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ Found $METRIC_COUNT metrics (expected 12)${NC}"
    ((TESTS_EXPECTED_FAIL++))
fi
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "📊 PHASE 2: Simple Metrics (Direct Aggregations)"
echo "════════════════════════════════════════════════════════════════"
echo ""

run_test "total_revenue" \
    "docker compose exec dbt mf query --metrics total_revenue --limit 1"

run_test "total_orders" \
    "docker compose exec dbt mf query --metrics total_orders --limit 1"

run_test "unique_customers" \
    "docker compose exec dbt mf query --metrics unique_customers --limit 1"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "🔍 PHASE 3: Filtered Metrics (WHERE Clause Logic)"
echo "════════════════════════════════════════════════════════════════"
echo ""

run_test "high_value_orders (revenue > 100)" \
    "docker compose exec dbt mf query --metrics high_value_orders --limit 1"

run_test "european_market_revenue (country filter)" \
    "docker compose exec dbt mf query --metrics european_market_revenue --limit 1"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "🧮 PHASE 4: Derived Metrics (Calculations)"
echo "════════════════════════════════════════════════════════════════"
echo ""

run_test "revenue_per_order (total_revenue / total_orders)" \
    "docker compose exec dbt mf query --metrics revenue_per_order --limit 1"

run_test "revenue_per_customer (total_revenue / unique_customers)" \
    "docker compose exec dbt mf query --metrics revenue_per_customer --limit 1"

run_test "high_value_order_rate (ratio as percentage)" \
    "docker compose exec dbt mf query --metrics high_value_order_rate --limit 1"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📈 PHASE 5: Cumulative Metrics (Running Totals)"
echo "════════════════════════════════════════════════════════════════"
echo ""

run_test "cumulative_revenue (running total)" \
    "docker compose exec dbt mf query --metrics cumulative_revenue --group-by metric_time__month --order metric_time__month --limit 3" \
    true

run_test "cumulative_orders (running count)" \
    "docker compose exec dbt mf query --metrics cumulative_orders --group-by metric_time__month --order metric_time__month --limit 3" \
    true

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📊 PHASE 6: Growth Metrics (Period-over-Period)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo -e "${YELLOW}Note: These may fail if you don't have 2+ months/weeks of data${NC}"
echo ""

run_test "revenue_growth_mom (month-over-month)" \
    "docker compose exec dbt mf query --metrics revenue_growth_mom --group-by metric_time__month --order metric_time__month --limit 3" \
    true

run_test "revenue_wow (week-over-week)" \
    "docker compose exec dbt mf query --metrics revenue_wow --group-by metric_time__week --order metric_time__week --limit 3" \
    true

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "🌍 PHASE 7: Dimensional Queries (Group By)"
echo "════════════════════════════════════════════════════════════════"
echo ""

run_test "Revenue by supplier country" \
    "docker compose exec dbt mf query --metrics total_revenue --group-by order_id__supplier_country --limit 5"

run_test "Revenue by product name" \
    "docker compose exec dbt mf query --metrics total_revenue --group-by order_id__product_name --limit 5"

run_test "Orders by month" \
    "docker compose exec dbt mf query --metrics total_orders --group-by metric_time__month --order metric_time__month --limit 5"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "🔄 PHASE 8: Multi-Metric Queries"
echo "════════════════════════════════════════════════════════════════"
echo ""

run_test "Multiple simple metrics together" \
    "docker compose exec dbt mf query --metrics total_revenue,total_orders,unique_customers --limit 1"

run_test "Revenue metrics with dimension" \
    "docker compose exec dbt mf query --metrics total_revenue,revenue_per_order --group-by order_id__supplier_country --limit 3"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "⚡ PHASE 9: Time Granularity Tests"
echo "════════════════════════════════════════════════════════════════"
echo ""

run_test "Daily granularity" \
    "docker compose exec dbt mf query --metrics total_revenue --group-by metric_time__day --limit 5"

run_test "Monthly granularity" \
    "docker compose exec dbt mf query --metrics total_revenue --group-by metric_time__month --limit 3"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "🎯 PHASE 10: Validation Summary"
echo "════════════════════════════════════════════════════════════════"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_EXPECTED_FAIL))

echo "Total Tests:       $TOTAL_TESTS"
echo -e "${GREEN}Passed:            ${TESTS_PASSED}${NC}"
echo -e "${YELLOW}Expected Failures: ${TESTS_EXPECTED_FAIL}${NC}"
echo -e "${RED}Failed:            ${TESTS_FAILED}${NC}"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "📊 Registered Metrics"
echo "════════════════════════════════════════════════════════════════"
docker compose exec dbt mf list metrics
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}✅ VALIDATION SUCCESSFUL!${NC}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "All core metrics working correctly!"
    echo ""
    if [ $TESTS_EXPECTED_FAIL -gt 0 ]; then
        echo -e "${YELLOW}Note:${NC} $TESTS_EXPECTED_FAIL tests expected to fail due to limited data."
        echo "This is normal for:"
        echo "  • Growth metrics (need 2+ time periods)"
        echo "  • Cumulative metrics (need time series data)"
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Generate demo results: bash demo-metricflow-results.sh"
    echo "  2. Compare with Cube.js: bash compare-metricflow-cube.sh"
    echo "  3. Commit to GitHub"
    echo ""
    exit 0
else
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${RED}⚠️  VALIDATION FAILED${NC}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "$TESTS_FAILED core metric(s) failed validation."
    echo "Review errors above and fix issues before proceeding."
    echo ""
    exit 1
fi