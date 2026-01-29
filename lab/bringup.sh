#!/bin/bash
# Network Configuration Script
# Configures L2 bridges and L3 routing on virtual switches
#
# L2: Each switch has br-vlan100 with two access ports
# L3: Inter-switch routed link with static routes

set -e

echo "================================================"
echo "Network Bringup Script"
echo "================================================"

echo ""
echo "=== Configuring sonic1 ==="

docker exec clab-sonic-lab-sonic1 bash -c '
    # Enable IP forwarding (use /proc directly if sysctl not available)
    echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

    # Bring up interfaces
    ip link set eth1 up
    ip link set eth2 up
    ip link set eth3 up

    # Create L2 bridge for VLAN 100
    ip link add br-vlan100 type bridge 2>/dev/null || true
    ip link set br-vlan100 up

    # Add access ports to bridge
    ip link set eth2 master br-vlan100 2>/dev/null || true
    ip link set eth3 master br-vlan100 2>/dev/null || true

    # Assign IP to bridge (L3 gateway for this VLAN segment)
    ip addr show br-vlan100 | grep -q "10.100.1.1/24" || ip addr add 10.100.1.1/24 dev br-vlan100

    # Configure inter-switch L3 link
    ip addr show eth1 | grep -q "10.0.0.1/30" || ip addr add 10.0.0.1/30 dev eth1

    # Static route to sonic2 VLAN segment
    ip route show | grep -q "10.100.2.0/24" || ip route add 10.100.2.0/24 via 10.0.0.2
'

echo "=== Configuring sonic2 ==="

docker exec clab-sonic-lab-sonic2 bash -c '
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

    # Bring up interfaces
    ip link set eth1 up
    ip link set eth2 up
    ip link set eth3 up

    # Create L2 bridge for VLAN 100
    ip link add br-vlan100 type bridge 2>/dev/null || true
    ip link set br-vlan100 up

    # Add access ports to bridge
    ip link set eth2 master br-vlan100 2>/dev/null || true
    ip link set eth3 master br-vlan100 2>/dev/null || true

    # Assign IP to bridge (L3 gateway for this VLAN segment)
    ip addr show br-vlan100 | grep -q "10.100.2.1/24" || ip addr add 10.100.2.1/24 dev br-vlan100

    # Configure inter-switch L3 link
    ip addr show eth1 | grep -q "10.0.0.2/30" || ip addr add 10.0.0.2/30 dev eth1

    # Static route to sonic1 VLAN segment
    ip route show | grep -q "10.100.1.0/24" || ip route add 10.100.1.0/24 via 10.0.0.1
'

echo "=== Configuring ptfhost ==="

docker exec clab-sonic-lab-ptfhost bash -c '
    # Bring up all test interfaces
    ip link set eth1 up
    ip link set eth2 up
    ip link set eth3 up
    ip link set eth4 up

    # Assign IPs for L3 reachability tests
    ip addr show eth1 | grep -q "10.100.1.10/24" || ip addr add 10.100.1.10/24 dev eth1
    ip addr show eth3 | grep -q "10.100.2.10/24" || ip addr add 10.100.2.10/24 dev eth3
'

echo ""
echo "================================================"
echo "Configuration Complete"
echo "================================================"
echo ""
echo "Topology:"
echo "  ptfhost:eth1 <-> sonic1:eth2 (br-vlan100)"
echo "  ptfhost:eth2 <-> sonic1:eth3 (br-vlan100)"
echo "  ptfhost:eth3 <-> sonic2:eth2 (br-vlan100)"
echo "  ptfhost:eth4 <-> sonic2:eth3 (br-vlan100)"
echo "  sonic1:eth1 (10.0.0.1) <-> sonic2:eth1 (10.0.0.2)"
echo ""
echo "L2 Bridges:"
echo "  sonic1:br-vlan100 = eth2 + eth3 (10.100.1.1/24)"
echo "  sonic2:br-vlan100 = eth2 + eth3 (10.100.2.1/24)"
echo ""
echo "Run 'make verify-l2' to check bridge state"
