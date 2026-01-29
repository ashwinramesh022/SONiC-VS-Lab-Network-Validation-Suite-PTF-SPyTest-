#!/bin/bash
# Control-Plane Validation Runner
# Runs Python-based control-plane checks (SPyTest-inspired, not actual sonic-mgmt)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="${PROJECT_DIR}/reports"
ARTIFACT_DIR="${PROJECT_DIR}/artifacts/${TIMESTAMP}_ctrlplane"

mkdir -p "$REPORT_DIR"
mkdir -p "$ARTIFACT_DIR"

echo "================================================"
echo "Control-Plane Validation"
echo "================================================"
echo "Timestamp: $TIMESTAMP"
echo ""

# Run the validation script
python3 "${PROJECT_DIR}/tests/spytest/test_static_routing.py" 2>&1 | tee "${ARTIFACT_DIR}/ctrlplane_output.log"
RESULT=${PIPESTATUS[0]}

# Collect artifacts
echo ""
echo "Collecting artifacts..."
docker exec clab-sonic-lab-sonic1 ip route > "${ARTIFACT_DIR}/sonic1_routes.txt" 2>&1 || true
docker exec clab-sonic-lab-sonic2 ip route > "${ARTIFACT_DIR}/sonic2_routes.txt" 2>&1 || true

# Generate report
{
    echo "# Control-Plane Validation Report"
    echo "Date: $(date)"
    echo ""
    echo "## Result"
    if [ $RESULT -eq 0 ]; then
        echo "**Status: ✅ ALL CHECKS PASSED**"
    else
        echo "**Status: ❌ SOME CHECKS FAILED**"
    fi
    echo ""
    echo "## Checks Performed"
    echo "- Static route installation on sonic1"
    echo "- Static route installation on sonic2"  
    echo "- Inter-switch L3 connectivity"
    echo "- End-to-end reachability"
    echo "- Route table symmetry"
    echo ""
    echo "## Artifacts"
    echo "- Output: ${ARTIFACT_DIR}/ctrlplane_output.log"
} > "${REPORT_DIR}/ctrlplane_report_${TIMESTAMP}.md"

echo ""
echo "================================================"
echo "Control-Plane Validation Complete"
echo "================================================"
echo "Result: $([ $RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo "Report: ${REPORT_DIR}/ctrlplane_report_${TIMESTAMP}.md"
echo "================================================"

exit $RESULT
