#!/bin/bash
# SPyTest Runner Script
# Runs SPyTest-style control plane validation tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="${PROJECT_DIR}/reports"
ARTIFACT_DIR="${PROJECT_DIR}/artifacts/${TIMESTAMP}_spytest"

mkdir -p "$REPORT_DIR"
mkdir -p "$ARTIFACT_DIR"

echo "================================================"
echo "SPyTest Runner - Static Routing Validation"
echo "================================================"
echo "Timestamp: $TIMESTAMP"
echo ""

# Run the SPyTest
python3 "${PROJECT_DIR}/tests/spytest/test_static_routing.py" 2>&1 | tee "${ARTIFACT_DIR}/spytest_output.log"
SPYTEST_RESULT=${PIPESTATUS[0]}

# Collect artifacts
echo ""
echo "Collecting artifacts..."
docker exec clab-sonic-lab-sonic1 ip route > "${ARTIFACT_DIR}/sonic1_routes.txt" 2>&1 || true
docker exec clab-sonic-lab-sonic2 ip route > "${ARTIFACT_DIR}/sonic2_routes.txt" 2>&1 || true
docker exec clab-sonic-lab-sonic1 ip addr > "${ARTIFACT_DIR}/sonic1_interfaces.txt" 2>&1 || true
docker exec clab-sonic-lab-sonic2 ip addr > "${ARTIFACT_DIR}/sonic2_interfaces.txt" 2>&1 || true

# Generate report
{
    echo "# SPyTest Report - Static Routing Validation"
    echo "Date: $(date)"
    echo ""
    echo "## Test Result"
    if [ $SPYTEST_RESULT -eq 0 ]; then
        echo "**Status: ✅ ALL TESTS PASSED**"
    else
        echo "**Status: ❌ SOME TESTS FAILED**"
    fi
    echo ""
    echo "## Test Cases"
    echo "- TC01: Verify static routes on sonic1"
    echo "- TC02: Verify static routes on sonic2"
    echo "- TC03: Verify inter-switch connectivity"
    echo "- TC04: Verify end-to-end reachability"
    echo "- TC05: Verify route symmetry"
    echo ""
    echo "## Artifacts"
    echo "- Full output: ${ARTIFACT_DIR}/spytest_output.log"
    echo "- Route tables: sonic1_routes.txt, sonic2_routes.txt"
    echo "- Interfaces: sonic1_interfaces.txt, sonic2_interfaces.txt"
} > "${REPORT_DIR}/spytest_report_${TIMESTAMP}.md"

echo ""
echo "================================================"
echo "SPyTest Complete"
echo "================================================"
echo "Result: $([ $SPYTEST_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo "Report: ${REPORT_DIR}/spytest_report_${TIMESTAMP}.md"
echo "Logs:   ${ARTIFACT_DIR}/"
echo "================================================"

exit $SPYTEST_RESULT
