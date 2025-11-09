#!/bin/bash
# encoding: utf-8
# Test runner for 1C Notify Update API endpoint tests
# Comprehensive test suite execution with detailed reporting

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
LOG_DIR="$PROJECT_ROOT/log"
TEST_LOG="$LOG_DIR/1c_notify_update_tests.log"
TEST_RESULTS="$LOG_DIR/1c_notify_update_test_results.json"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Initialize test results
echo '{"timestamp": "'$(date -Iseconds)'", "tests": []}' > "$TEST_RESULTS"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  1C Notify Update API Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Test directory: $TEST_DIR"
echo "Project root: $PROJECT_ROOT"
echo "Log file: $TEST_LOG"
echo "Results file: $TEST_RESULTS"
echo ""

# Function to log test results
log_test_result() {
    local test_file="$1"
    local exit_code="$2"
    local duration="$3"
    local output="$4"
    
    # Create JSON entry for this test
    local result_entry
    if [ $exit_code -eq 0 ]; then
        result_entry='{"test": "'$test_file'", "status": "PASS", "duration": '$duration', "exit_code": '$exit_code'}'
    else
        result_entry='{"test": "'$test_file'", "status": "FAIL", "duration": '$duration', "exit_code": '$exit_code', "error": "'$(echo "$output" | tail -n 5 | tr '\n' ' ' | sed 's/"/\\"}/g')'"}'
    fi
    
    # Append to results file (this is a simplified approach, in practice you'd want proper JSON manipulation)
    echo "$result_entry" >> "${TEST_RESULTS}.tmp"
}

# Function to run a single test file
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .rb)
    
    echo -e "${YELLOW}Running: ${test_name}${NC}"
    echo "" | tee -a "$TEST_LOG"
    echo "================== $test_name ($(date)) ==================" | tee -a "$TEST_LOG"
    
    # Record start time
    local start_time=$(date +%s.%N)
    
    # Run the test and capture output
    local output
    local exit_code=0
    
    cd "$TEST_DIR"
    output=$(ruby "$test_file" 2>&1) || exit_code=$?
    
    # Calculate duration (using basic arithmetic since bc might not be available)
    local end_time=$(date +%s.%N)
    local duration=$(python3 -c "print(round(float('$end_time') - float('$start_time'), 3))" 2>/dev/null || echo "N/A")
    
    # Log the output
    echo "$output" | tee -a "$TEST_LOG"
    
    # Display and log result
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC} $test_name (${duration}s)"
        echo "✓ PASSED $test_name (${duration}s)" >> "$TEST_LOG"
    else
        echo -e "${RED}✗ FAILED${NC} $test_name (${duration}s) - Exit code: $exit_code"
        echo "✗ FAILED $test_name (${duration}s) - Exit code: $exit_code" >> "$TEST_LOG"
        echo -e "${RED}  Last few lines of output:${NC}"
        echo "$output" | tail -n 5 | sed 's/^/    /'
    fi
    
    # Log the result
    log_test_result "$test_name" "$exit_code" "$duration" "$output"
    
    echo ""
    
    return $exit_code
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    # Check if Ruby is available
    if ! command -v ruby &> /dev/null; then
        echo -e "${RED}Error: Ruby is not installed or not in PATH${NC}"
        exit 1
    fi
    
    echo "Ruby version: $(ruby --version)"
    
    # Check if required gems are available
    if ! ruby -e "require 'minitest/autorun'" 2>/dev/null; then
        echo -e "${YELLOW}Warning: minitest gem may not be available${NC}"
    fi
    
    # Check if test files exist
    local test_files_found=0
    for test_type in "unit" "integration" "utils"; do
        if ls "$TEST_DIR/$test_type/test_1c_notify_update_"*.rb 1> /dev/null 2>&1; then
            test_files_found=$((test_files_found + 1))
            echo "Found test files in $test_type directory"
        fi
    done
    
    if [ $test_files_found -eq 0 ]; then
        echo -e "${RED}Error: No 1C notify update test files found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Prerequisites check passed${NC}"
    echo ""
}

# Function to run unit tests
run_unit_tests() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Unit Tests (Validation Logic)${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local unit_test_files=($(find "$TEST_DIR/unit" -name "test_1c_notify_update_*.rb" 2>/dev/null || true))
    
    if [ ${#unit_test_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No unit tests found${NC}"
        return 0
    fi
    
    local unit_passed=0
    local unit_total=${#unit_test_files[@]}
    
    for test_file in "${unit_test_files[@]}"; do
        if run_test "$test_file"; then
            unit_passed=$((unit_passed + 1))
        fi
    done
    
    echo -e "${BLUE}Unit Tests Summary: ${unit_passed}/${unit_total} passed${NC}"
    echo ""
    
    return $([ $unit_passed -eq $unit_total ])
}

# Function to run integration tests
run_integration_tests() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Integration Tests (Full Workflow)${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local integration_test_files=($(find "$TEST_DIR/integration" -name "test_1c_notify_update_*.rb" 2>/dev/null || true))
    
    if [ ${#integration_test_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No integration tests found${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Note: Integration tests may take several minutes to complete${NC}"
    echo -e "${YELLOW}They test the actual API endpoint and may require external services${NC}"
    echo ""
    
    local integration_passed=0
    local integration_total=${#integration_test_files[@]}
    
    for test_file in "${integration_test_files[@]}"; do
        if run_test "$test_file"; then
            integration_passed=$((integration_passed + 1))
        fi
    done
    
    echo -e "${BLUE}Integration Tests Summary: ${integration_passed}/${integration_total} passed${NC}"
    echo ""
    
    return $([ $integration_passed -eq $integration_total ])
}

# Function to run mock tests
run_mock_tests() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Mock Tests (HTTP & Dependencies)${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local mock_test_files=($(find "$TEST_DIR/utils" -name "test_1c_notify_update_*.rb" 2>/dev/null || true))
    
    if [ ${#mock_test_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No mock tests found${NC}"
        return 0
    fi
    
    local mock_passed=0
    local mock_total=${#mock_test_files[@]}
    
    for test_file in "${mock_test_files[@]}"; do
        if run_test "$test_file"; then
            mock_passed=$((mock_passed + 1))
        fi
    done
    
    echo -e "${BLUE}Mock Tests Summary: ${mock_passed}/${mock_total} passed${NC}"
    echo ""
    
    return $([ $mock_passed -eq $mock_total ])
}

# Function to generate test report
generate_test_report() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Test Report Generation${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local report_file="$LOG_DIR/1c_notify_update_test_report.txt"
    local html_report="$LOG_DIR/1c_notify_update_test_report.html"
    
    # Create text report
    cat > "$report_file" << EOF
1C Notify Update API Test Suite Report
======================================

Test execution completed at: $(date)
Test directory: $TEST_DIR
Log file: $TEST_LOG

Test Results Summary:
EOF
    
    # Count results from log (simplified approach)
    local total_tests=$(grep -c "✓ PASSED\|✗ FAILED" "$TEST_LOG" 2>/dev/null || echo "0")
    local passed_tests=$(grep -c "✓ PASSED" "$TEST_LOG" 2>/dev/null || echo "0")
    local failed_tests=$(grep -c "✗ FAILED" "$TEST_LOG" 2>/dev/null || echo "0")
    
    # Clean up counts (remove any extra whitespace/newlines)
    total_tests=$(echo "$total_tests" | head -n 1 | tr -d ' \n\r')
    passed_tests=$(echo "$passed_tests" | head -n 1 | tr -d ' \n\r')
    failed_tests=$(echo "$failed_tests" | head -n 1 | tr -d ' \n\r')
    
    # Ensure we have numeric values
    total_tests=${total_tests:-0}
    passed_tests=${passed_tests:-0}
    failed_tests=${failed_tests:-0}
    
    cat >> "$report_file" << EOF
Total tests run: $total_tests
Passed: $passed_tests
Failed: $failed_tests
Success rate: $(python3 -c "print(round($passed_tests * 100.0 / max($total_tests, 1), 2))" 2>/dev/null || echo "N/A")%

Detailed Results:
EOF
    
    # Extract test results from log
    grep "✓ PASSED\|✗ FAILED" "$TEST_LOG" >> "$report_file" 2>/dev/null || true
    
    echo ""
    echo "Test report saved to: $report_file"
    
    # Create HTML report if possible
    if command -v pandoc &> /dev/null; then
        pandoc "$report_file" -o "$html_report" 2>/dev/null && \
        echo "HTML report saved to: $html_report"
    fi
    
    # Display summary
    echo ""
    echo -e "${BLUE}Final Summary:${NC}"
    echo "  Total tests: $total_tests"
    echo -e "  Passed: ${GREEN}$passed_tests${NC}"
    echo -e "  Failed: ${RED}$failed_tests${NC}"
    
    if [ "$failed_tests" -eq 0 ] && [ "$total_tests" -gt 0 ]; then
        echo -e "  ${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "  ${RED}⚠️  Some tests failed or no tests were run${NC}"
        return 1
    fi
}

# Function to clean up test artifacts
cleanup_test_artifacts() {
    echo -e "${BLUE}Cleaning up test artifacts...${NC}"
    
    # Remove temporary files
    rm -f "${TEST_RESULTS}.tmp" 2>/dev/null || true
    
    # Clean up any temporary test files created during testing
    find /tmp -name "test_*_${USER}_*" -type f -mmin +60 -delete 2>/dev/null || true
    
    # Clean up old log entries (keep last 100 lines)
    if [ -f "$TEST_LOG" ] && [ $(wc -l < "$TEST_LOG") -gt 500 ]; then
        tail -n 100 "$TEST_LOG" > "${TEST_LOG}.tmp" && mv "${TEST_LOG}.tmp" "$TEST_LOG"
    fi
    
    echo "Cleanup completed"
}

# Main execution
main() {
    # Parse command line arguments
    local run_unit=true
    local run_integration=true
    local run_mocks=true
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit-only)
                run_integration=false
                run_mocks=false
                shift
                ;;
            --integration-only)
                run_unit=false
                run_mocks=false
                shift
                ;;
            --mocks-only)
                run_unit=false
                run_integration=false
                shift
                ;;
            --no-integration)
                run_integration=false
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --unit-only        Run only unit tests"
                echo "  --integration-only Run only integration tests"
                echo "  --mocks-only       Run only mock tests"
                echo "  --no-integration   Skip integration tests (run unit and mock tests)"
                echo "  --verbose          Enable verbose output"
                echo "  --help             Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Start test execution
    local start_time=$(date +%s)
    local overall_success=true
    
    # Check prerequisites
    check_prerequisites
    
    # Run selected test suites
    if [ "$run_unit" = true ]; then
        if ! run_unit_tests; then
            overall_success=false
        fi
    fi
    
    if [ "$run_mocks" = true ]; then
        if ! run_mock_tests; then
            overall_success=false
        fi
    fi
    
    if [ "$run_integration" = true ]; then
        if ! run_integration_tests; then
            overall_success=false
        fi
    fi
    
    # Generate report
    local report_success=true
    if ! generate_test_report; then
        report_success=false
    fi
    
    # Cleanup
    cleanup_test_artifacts
    
    # Calculate total execution time
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Test Execution Complete${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "Total execution time: ${total_time}s"
    echo "Full logs available in: $TEST_LOG"
    
    # Final exit status
    if [ "$overall_success" = true ] && [ "$report_success" = true ]; then
        echo -e "${GREEN}All tests completed successfully! 🎉${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed or encountered errors ⚠️${NC}"
        echo "Please check the logs and test report for details."
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"
