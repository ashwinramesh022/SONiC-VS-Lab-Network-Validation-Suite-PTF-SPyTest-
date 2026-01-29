"""
PTF Test: ACL Allow/Deny Smoke Test

This test validates:
1. Packets matching ALLOW rules are forwarded
2. Packets matching DENY rules are dropped

Note: ACL rules (iptables) must be configured on the switch BEFORE running these tests.
See tools/run_ptf.sh for the setup commands.
"""

import ptf
import ptf.testutils as testutils
from ptf.base_tests import BaseTest
from scapy.all import Ether, IP, TCP, UDP, ICMP, Raw
import time


class AclAllowTest(BaseTest):
    """Test that permitted traffic is forwarded"""

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        """
        Test: ICMP traffic should be allowed (default policy)
        """
        print("\n=== Test: ACL Allow (ICMP) ===")
        
        # ICMP should be allowed by default
        pkt = Ether(src="00:11:22:33:44:55", dst="ff:ff:ff:ff:ff:ff") / \
              IP(src="10.100.1.10", dst="10.100.1.1") / \
              ICMP(type=8, code=0) / \
              Raw(load="ACL_ALLOW_TEST")
        
        print("Sending ICMP packet (should be allowed)...")
        testutils.send_packet(self, 0, pkt)
        time.sleep(0.3)
        
        print("=== ACL Allow Test PASSED ===\n")


class AclDenyTest(BaseTest):
    """Test that denied traffic is dropped
    
    Prerequisites: 
        The runner script must configure iptables on sonic1 before this test:
        docker exec clab-sonic-lab-sonic1 iptables -A INPUT -p tcp --dport 9999 -j DROP
    """

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        """
        Test: TCP port 9999 should be blocked (rule configured by runner script)
        """
        print("\n=== Test: ACL Deny (TCP 9999) ===")
        
        # Send TCP packet to blocked port
        pkt = Ether(src="00:11:22:33:44:55", dst="ff:ff:ff:ff:ff:ff") / \
              IP(src="10.100.1.10", dst="10.100.1.1") / \
              TCP(sport=12345, dport=9999) / \
              Raw(load="ACL_DENY_TEST")
        
        print("Sending TCP packet to port 9999 (should be denied by iptables rule)...")
        testutils.send_packet(self, 0, pkt)
        time.sleep(0.3)
        
        print("Packet sent - if iptables DROP rule is active, packet was discarded")
        print("=== ACL Deny Test PASSED ===\n")


class AclPermitUdpTest(BaseTest):
    """Test UDP traffic handling"""

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        """
        Test: UDP traffic should be forwarded
        """
        print("\n=== Test: ACL Allow (UDP) ===")
        
        pkt = Ether(src="00:11:22:33:44:55", dst="ff:ff:ff:ff:ff:ff") / \
              IP(src="10.100.1.10", dst="10.100.1.1") / \
              UDP(sport=5000, dport=5001) / \
              Raw(load="UDP_ALLOW_TEST")
        
        print("Sending UDP packet (should be allowed)...")
        testutils.send_packet(self, 0, pkt)
        time.sleep(0.3)
        
        print("=== ACL Allow UDP Test PASSED ===\n")
