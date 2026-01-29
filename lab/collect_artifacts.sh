#!/bin/bash
# Artifact Collection Script
# Gathers logs, configs, and state from all lab nodes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARTIFACT_DIR="${PROJECT_DIR}/artifacts/collection_${TIMESTAMP}"

mkdir -p "$ARTIFACT_DIR"

echo "================================================"
echo "SONiC Lab Artifact Collection"
echo "================================================"
echo "Timestamp: $TIMESTAMP"
echo "Output Dir: $ARTIFACT_DIR"
echo ""

# Check if lab is running
if ! docker ps | grep -q clab-sonic-lab; then
    echo "ERROR: Lab containers are not running"
    echo "Run 'make up' first"
    exit 1
fi

echo "Collecting topology information..."
sudo containerlab inspect -t "${SCRIPT_DIR}/topo.yml" > "${ARTIFACT_DIR}/topology.txt" 2>&1

echo "Collecting from sonic1..."
mkdir -p "${ARTIFACT_DIR}/sonic1"
docker exec clab-sonic-lab-sonic1 ip addr > "${ARTIFACT_DIR}/sonic1/ip_addr.txt" 2>&1
docker exec clab-sonic-lab-sonic1 ip route > "${ARTIFACT_DIR}/sonic1/ip_route.txt" 2>&1
docker exec clab-sonic-lab-sonic1 ip link > "${ARTIFACT_DIR}/sonic1/ip_link.txt" 2>&1
docker exec clab-sonic-lab-sonic1 bridge link show > "${ARTIFACT_DIR}/sonic1/bridge_link.txt" 2>&1
docker exec clab-sonic-lab-sonic1 bridge fdb show > "${ARTIFACT_DIR}/sonic1/bridge_fdb.txt" 2>&1
docker exec clab-sonic-lab-sonic1 iptables -L -n -v > "${ARTIFACT_DIR}/sonic1/iptables.txt" 2>&1
docker exec clab-sonic-lab-sonic1 cat /etc/resolv.conf > "${ARTIFACT_DIR}/sonic1/resolv.conf" 2>&1 || true

echo "Collecting from sonic2..."
mkdir -p "${ARTIFACT_DIR}/sonic2"
docker exec clab-sonic-lab-sonic2 ip addr > "${ARTIFACT_DIR}/sonic2/ip_addr.txt" 2>&1
docker exec clab-sonic-lab-sonic2 ip route > "${ARTIFACT_DIR}/sonic2/ip_route.txt" 2>&1
docker exec clab-sonic-lab-sonic2 ip link > "${ARTIFACT_DIR}/sonic2/ip_link.txt" 2>&1
docker exec clab-sonic-lab-sonic2 bridge link show > "${ARTIFACT_DIR}/sonic2/bridge_link.txt" 2>&1
docker exec clab-sonic-lab-sonic2 bridge fdb show > "${ARTIFACT_DIR}/sonic2/bridge_fdb.txt" 2>&1
docker exec clab-sonic-lab-sonic2 iptables -L -n -v > "${ARTIFACT_DIR}/sonic2/iptables.txt" 2>&1
docker exec clab-sonic-lab-sonic2 cat /etc/resolv.conf > "${ARTIFACT_DIR}/sonic2/resolv.conf" 2>&1 || true

echo "Collecting from ptfhost..."
mkdir -p "${ARTIFACT_DIR}/ptfhost"
docker exec clab-sonic-lab-ptfhost ip addr > "${ARTIFACT_DIR}/ptfhost/ip_addr.txt" 2>&1
docker exec clab-sonic-lab-ptfhost ip route > "${ARTIFACT_DIR}/ptfhost/ip_route.txt" 2>&1
docker exec clab-sonic-lab-ptfhost ip link > "${ARTIFACT_DIR}/ptfhost/ip_link.txt" 2>&1
docker exec clab-sonic-lab-ptfhost pip3 list > "${ARTIFACT_DIR}/ptfhost/pip_packages.txt" 2>&1 || true

echo "Collecting docker information..."
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" > "${ARTIFACT_DIR}/docker_ps.txt" 2>&1
docker network inspect clab > "${ARTIFACT_DIR}/docker_network.json" 2>&1 || true

echo "Running connectivity tests..."
{
    echo "=== Connectivity Test Results ==="
    echo ""
    echo "sonic1 -> sonic2 (inter-switch):"
    docker exec clab-sonic-lab-sonic1 ping -c 2 10.0.0.2 2>&1 || echo "FAILED"
    echo ""
    echo "ptfhost -> sonic1 (L2 bridge):"
    docker exec clab-sonic-lab-ptfhost ping -c 2 10.100.1.1 2>&1 || echo "FAILED"
    echo ""
    echo "ptfhost -> sonic2 (L2 bridge):"
    docker exec clab-sonic-lab-ptfhost ping -c 2 10.100.2.1 2>&1 || echo "FAILED"
} > "${ARTIFACT_DIR}/connectivity_tests.txt" 2>&1

# Generate summary
echo ""
echo "Generating summary..."
{
    echo "# Artifact Collection Summary"
    echo "Generated: $(date)"
    echo ""
    echo "## Topology"
    echo "\`\`\`"
    cat "${ARTIFACT_DIR}/topology.txt"
    echo "\`\`\`"
    echo ""
    echo "## Network Configuration"
    echo ""
    echo "### sonic1 Routes"
    echo "\`\`\`"
    cat "${ARTIFACT_DIR}/sonic1/ip_route.txt"
    echo "\`\`\`"
    echo ""
    echo "### sonic2 Routes"
    echo "\`\`\`"
    cat "${ARTIFACT_DIR}/sonic2/ip_route.txt"
    echo "\`\`\`"
    echo ""
    echo "## Files Collected"
    find "${ARTIFACT_DIR}" -type f -name "*.txt" -o -name "*.json" | sed "s|${ARTIFACT_DIR}/||" | sort
} > "${ARTIFACT_DIR}/SUMMARY.md"

echo ""
echo "================================================"
echo "Artifact Collection Complete"
echo "================================================"
echo "Location: $ARTIFACT_DIR"
echo "Files collected:"
find "${ARTIFACT_DIR}" -type f | wc -l | xargs echo "  "
echo ""
ls -la "${ARTIFACT_DIR}"
echo "================================================"
