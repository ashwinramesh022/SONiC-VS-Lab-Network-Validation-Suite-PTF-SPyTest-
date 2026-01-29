#!/bin/bash
# SONiC VS Lab - Network Configuration Script
# Configures L2 (VLAN) and L3 (Static Routing) paths

set -e

echo "=== Configuring sonic1 ==="

# L2: Create VLAN 100 on sonic1, add eth2 as access port
docker exec clab-sonic-lab-sonic1 bash -c "
    # Load 8021q module for VLAN support
    modprobe 8021q 2>/dev/null || true
    
    # Create bridge for VLAN 100
    ip link add br-vlan100 type bridge
    ip link set br-vlan100 up
    
    # Add eth2 to the bridge (connection to ptfhost:eth1)
    ip link set eth2 master br-vlan100
    
    # Assign IP to bridge for L3 routing from sonic1
    ip addr add 10.100.1.1/24 dev br-vlan100
    
    # L3: Configure inter-switch link (eth1)
    ip addr add 10.0.0.1/30 dev eth1
    
    # Static route to sonic2's network
    ip route add 10.100.2.0/24 via 10.0.0.2
"

echo "=== Configuring sonic2 ==="

# L2: Create VLAN 100 on sonic2, add eth2 as access port
docker exec clab-sonic-lab-sonic2 bash -c "
    # Load 8021q module for VLAN support
    modprobe 8021q 2>/dev/null || true
    
    # Create bridge for VLAN 100
    ip link add br-vlan100 type bridge
    ip link set br-vlan100 up
    
    # Add eth2 to the bridge (connection to ptfhost:eth2)
    ip link set eth2 master br-vlan100
    
    # Assign IP to bridge for L3 routing from sonic2
    ip addr add 10.100.2.1/24 dev br-vlan100
    
    # L3: Configure inter-switch link (eth1)
    ip addr add 10.0.0.2/30 dev eth1
    
    # Static route to sonic1's network
    ip route add 10.100.1.0/24 via 10.0.0.1
"

echo "=== Configuring ptfhost ==="

# Configure ptfhost interfaces
docker exec clab-sonic-lab-ptfhost bash -c "
    # eth1 connects to sonic1 (VLAN 100 network)
    ip addr add 10.100.1.10/24 dev eth1
    
    # eth2 connects to sonic2 (VLAN 100 network)
    ip addr add 10.100.2.10/24 dev eth2
    
    # Default routes through sonic1 and sonic2
    ip route add 10.0.0.0/30 via 10.100.1.1
"

echo "=== Configuration Complete ==="
echo ""
echo "Network Summary:"
echo "  sonic1 br-vlan100: 10.100.1.1/24 (connected to ptfhost:eth1)"
echo "  sonic2 br-vlan100: 10.100.2.1/24 (connected to ptfhost:eth2)"
echo "  sonic1 eth1: 10.0.0.1/30 <--> sonic2 eth1: 10.0.0.2/30"
echo "  ptfhost eth1: 10.100.1.10/24"
echo "  ptfhost eth2: 10.100.2.10/24"
