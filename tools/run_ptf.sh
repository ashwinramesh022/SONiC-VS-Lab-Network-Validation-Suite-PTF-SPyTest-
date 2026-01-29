#!/bin/bash
# PTF Test Runner Script
# Runs PTF tests inside the ptfhost container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="${PROJECT_DIR}/reports"
ARTIFACT_DIR="${PROJECT_DIR}/artifacts/${TIMESTAMP}"

mkdir -p "$REPORT_DIR"
mkdir -p "$ARTIFACT_DIR"

echo "================================================"
echo "PTF Test Runner"
echo "================================================"
echo "Timestamp: $TIMESTAMP"
echo "Report Dir: $REPORT_DIR"
echo ""

# Copy test files to ptfhost
echo "Copying PTF tests to ptfhost..."
docker cp "${PROJECT_DIR}/tests/ptf/." clab-sonic-lab-ptfhost:/ptf_tests/

# Configure ACL rules for testing
echo ""
echo "Configuring ACL rules on sonic1..."
docker exec clab-sonic-lab-sonic1 iptables -C INPUT -p tcp --dport 9999 -j DROP 2>/dev/null || \
    docker exec clab-sonic-lab-sonic1 iptables -A INPUT -p tcp --dport 9999 -j DROP
echo "  - Added DROP rule for TCP port 9999"

# Show current iptables rules
echo ""
echo "Current iptables rules on sonic1:"
docker exec clab-sonic-lab-sonic1 iptables -L INPUT -n -v --line-numbers

# Run PTF tests
echo ""
echo "Running PTF tests..."
echo "------------------------------------------------"

# Test 1: VLAN Forwarding
echo ""
echo "[1/2] Running VLAN Forwarding Tests..."
docker exec -w /ptf_tests clab-sonic-lab-ptfhost ptf \
    --test-dir /ptf_tests \
    test_vlan_forwarding \
    --interface 0@eth1 \
    --interface 1@eth2 \
    2>&1 | tee "${ARTIFACT_DIR}/ptf_vlan_test.log"

VLAN_RESULT=${PIPESTATUS[0]}

# Test 2: ACL Smoke
echo ""
echo "[2/2] Running ACL Smoke Tests..."
docker exec -w /ptf_tests clab-sonic-lab-ptfhost ptf \
    --test-dir /ptf_tests \
    test_acl_smoke \
    --interface 0@eth1 \
    --interface 1@eth2 \
    2>&1 | tee "${ARTIFACT_DIR}/ptf_acl_test.log"

ACL_RESULT=${PIPESTATUS[0]}

# Cleanup ACL rules
echo ""
echo "Cleaning up ACL rules..."
docker exec clab-sonic-lab-sonic1 iptables -D INPUT -p tcp --dport 9999 -j DROP 2>/dev/null || true

# Collect additional artifacts
echo ""
echo "Collecting artifacts..."
docker exec clab-sonic-lab-sonic1 bridge fdb show > "${ARTIFACT_DIR}/sonic1_fdb.txt" 2>&1 || true
docker exec clab-sonic-lab-sonic1 ip route > "${ARTIFACT_DIR}/sonic1_routes.txt" 2>&1 || true
docker exec clab-sonic-lab-sonic1 iptables -L -n -v > "${ARTIFACT_DIR}/sonic1_iptables.txt" 2>&1 || true

# Generate summary report
echo ""
echo "================================================"
echo "Test Summary"
echo "================================================"

{
    echo "# PTF Test Report"
    echo "Date: $(date)"
    echo ""
    echo "## Results"
    echo ""
    if [ $VLAN_RESULT -eq 0 ]; then
        echo "- ✅ VLAN Forwarding Tests: PASSED"
    else
        echo "- ❌ VLAN Forwarding Tests: FAILED (exit code: $VLAN_RESULT)"
    fi
    if [ $ACL_RESULT -eq 0 ]; then
        echo "- ✅ ACL Smoke Tests: PASSED"
    else
        echo "- ❌ ACL Smoke Tests: FAILED (exit code: $ACL_RESULT)"
    fi
    echo ""
    echo "## Test Details"
    echo ""
    echo "### VLAN Forwarding Tests"
    echo "- VlanForwardingTest: L2 broadcast and unicast forwarding"
    echo "- MacLearningTest: Bridge MAC address learning"
    echo ""
    echo "### ACL Smoke Tests"
    echo "- AclAllowTest: ICMP traffic permitted"
    echo "- AclDenyTest: TCP port 9999 blocked via iptables"
    echo "- AclPermitUdpTest: UDP traffic permitted"
    echo ""
    echo "## Artifacts"
    echo "- Logs: artifacts/${TIMESTAMP}/"
    echo "- FDB table: sonic1_fdb.txt"
    echo "- Routes: sonic1_routes.txt"
    echo "- iptables: sonic1_iptables.txt"
} > "${REPORT_DIR}/ptf_report_${TIMESTAMP}.md"

echo "VLAN Tests: $([ $VLAN_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo "ACL Tests:  $([ $ACL_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo ""
echo "Report: ${REPORT_DIR}/ptf_report_${TIMESTAMP}.md"
echo "Logs:   ${ARTIFACT_DIR}/"
echo "================================================"

# Exit with failure if any test failed
if [ $VLAN_RESULT -ne 0 ] || [ $ACL_RESULT -ne 0 ]; then
    exit 1
fi
