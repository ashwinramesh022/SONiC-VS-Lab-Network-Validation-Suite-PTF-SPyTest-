"""
PTF Test: ACL Allow/Deny Validation

Tests forwarding-path filtering using iptables on the bridge.

Topology (on sonic1):
    ptfhost:eth1 (port 0) <-> sonic1:eth2 (br-vlan100)
    ptfhost:eth2 (port 1) <-> sonic1:eth3 (br-vlan100)

Tests:
    1. AclAllowTest: ICMP traffic is forwarded (allowed by default)
    2. AclDenyTest: TCP port 9999 is dropped (blocked by iptables)
"""

import ptf
import ptf.testutils as testutils
from ptf.base_tests import BaseTest
from scapy.all import Ether, IP, TCP, UDP, ICMP, Raw
import time


class AclAllowIcmpTest(BaseTest):
    """
    Test: ICMP traffic should be forwarded through the bridge.
    """

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        print("\n=== Test: ACL Allow ICMP ===")
        
        # Broadcast ICMP (will flood to port 1)
        pkt = Ether(src="00:11:22:33:44:55", dst="ff:ff:ff:ff:ff:ff") / \
              IP(src="10.100.1.100", dst="10.100.1.255") / \
              ICMP(type=8, code=0) / \
              Raw(load="ICMP_ALLOWED")
        
        print("Sending ICMP packet on port 0...")
        testutils.send_packet(self, 0, pkt)
        
        print("Verifying ICMP packet received on port 1...")
        testutils.verify_packet(self, pkt, port_id=1)
        
        print("=== ACL Allow ICMP Test PASSED ===\n")


class AclDenyTcpTest(BaseTest):
    """
    Test: TCP port 9999 should be dropped by iptables rule.
    
    Prerequisites: 
        tools/run_ptf.sh configures iptables FORWARD rule to drop TCP:9999
    """

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        print("\n=== Test: ACL Deny TCP 9999 ===")
        
        # TCP to blocked port (broadcast so it would flood if not blocked)
        pkt = Ether(src="00:11:22:33:44:55", dst="ff:ff:ff:ff:ff:ff") / \
              IP(src="10.100.1.100", dst="10.100.1.101") / \
              TCP(sport=12345, dport=9999) / \
              Raw(load="TCP_BLOCKED")
        
        print("Sending TCP:9999 packet on port 0...")
        testutils.send_packet(self, 0, pkt)
        
        print("Verifying TCP:9999 packet is NOT received on port 1 (dropped by ACL)...")
        testutils.verify_no_packet(self, pkt, port_id=1)
        
        print("=== ACL Deny TCP 9999 Test PASSED ===\n")


class AclAllowUdpTest(BaseTest):
    """
    Test: UDP traffic (not blocked) should be forwarded.
    """

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        print("\n=== Test: ACL Allow UDP ===")
        
        pkt = Ether(src="00:11:22:33:44:55", dst="ff:ff:ff:ff:ff:ff") / \
              IP(src="10.100.1.100", dst="10.100.1.255") / \
              UDP(sport=5000, dport=5001) / \
              Raw(load="UDP_ALLOWED")
        
        print("Sending UDP packet on port 0...")
        testutils.send_packet(self, 0, pkt)
        
        print("Verifying UDP packet received on port 1...")
        testutils.verify_packet(self, pkt, port_id=1)
        
        print("=== ACL Allow UDP Test PASSED ===\n")
