#!/bin/bash
# PTF Test Runner
# Runs dataplane validation tests using PTF framework

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
echo ""

# Copy test files to ptfhost
echo "Copying PTF tests to ptfhost..."
docker cp "${PROJECT_DIR}/tests/ptf/." clab-sonic-lab-ptfhost:/ptf_tests/

# Configure ACL rule for deny test using ebtables (L2 filtering)
echo ""
echo "Configuring ACL rules on sonic1 using ebtables..."

docker exec clab-sonic-lab-sonic1 bash -c '
    # Use ebtables to filter at L2 level on the bridge
    # Drop TCP dport 9999 packets on bridge
    ebtables -L FORWARD 2>/dev/null | grep -q "9999" || \
    ebtables -A FORWARD -p IPv4 --ip-proto tcp --ip-dport 9999 -j DROP
'
echo "  - ebtables DROP rule for TCP:9999 on FORWARD chain"

# Show ebtables rules
echo ""
echo "Current ebtables FORWARD rules:"
docker exec clab-sonic-lab-sonic1 ebtables -L FORWARD --Lc 2>/dev/null || echo "(ebtables not available)"

# Run PTF tests
echo ""
echo "Running PTF tests..."
echo "------------------------------------------------"

# Test 1: VLAN Forwarding
echo ""
echo "[1/2] Running L2 Forwarding Tests..."
docker exec -w /ptf_tests clab-sonic-lab-ptfhost ptf \
    --test-dir /ptf_tests \
    test_vlan_forwarding \
    --interface 0@eth1 \
    --interface 1@eth2 \
    2>&1 | tee "${ARTIFACT_DIR}/ptf_vlan_test.log"

VLAN_RESULT=${PIPESTATUS[0]}

# Test 2: ACL
echo ""
echo "[2/2] Running ACL Tests..."
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
docker exec clab-sonic-lab-sonic1 ebtables -D FORWARD -p IPv4 --ip-proto tcp --ip-dport 9999 -j DROP 2>/dev/null || true

# Collect artifacts
echo "Collecting artifacts..."
docker exec clab-sonic-lab-sonic1 bridge fdb show > "${ARTIFACT_DIR}/sonic1_fdb.txt" 2>&1 || true
docker exec clab-sonic-lab-sonic1 ebtables -L --Lc > "${ARTIFACT_DIR}/sonic1_ebtables.txt" 2>&1 || true

# Generate report
{
    echo "# PTF Test Report"
    echo "Date: $(date)"
    echo ""
    echo "## Results"
    echo ""
    if [ $VLAN_RESULT -eq 0 ]; then
        echo "- ✅ L2 Forwarding Tests: PASSED"
    else
        echo "- ❌ L2 Forwarding Tests: FAILED"
    fi
    if [ $ACL_RESULT -eq 0 ]; then
        echo "- ✅ ACL Tests: PASSED"
    else
        echo "- ❌ ACL Tests: FAILED"
    fi
    echo ""
    echo "## Test Details"
    echo ""
    echo "### L2 Forwarding Tests"
    echo "- BroadcastForwardingTest: verify_packet on broadcast flood"
    echo "- UnicastForwardingTest: MAC learning + verify_packet on unicast"
    echo "- NoFloodingToSourceTest: verify_no_packet on source port"
    echo ""
    echo "### ACL Tests"
    echo "- AclAllowIcmpTest: ICMP forwarded (verify_packet)"
    echo "- AclDenyTcpTest: TCP:9999 dropped via ebtables (verify_no_packet)"
    echo "- AclAllowUdpTest: UDP forwarded (verify_packet)"
    echo ""
    echo "## Artifacts"
    echo "- Logs: artifacts/${TIMESTAMP}/"
} > "${REPORT_DIR}/ptf_report_${TIMESTAMP}.md"

echo ""
echo "================================================"
echo "Test Summary"
echo "================================================"
echo "L2 Forwarding: $([ $VLAN_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo "ACL Tests:     $([ $ACL_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo ""
echo "Report: ${REPORT_DIR}/ptf_report_${TIMESTAMP}.md"
echo "Logs:   ${ARTIFACT_DIR}/"
echo "================================================"

# Exit with failure if any test failed
if [ $VLAN_RESULT -ne 0 ] || [ $ACL_RESULT -ne 0 ]; then
    exit 1
fi
