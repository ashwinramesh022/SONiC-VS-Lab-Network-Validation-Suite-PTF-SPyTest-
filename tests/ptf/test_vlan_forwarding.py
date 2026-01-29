"""
PTF Test: L2 Forwarding and MAC Learning Validation

Topology (on sonic1):
    ptfhost:eth1 (port 0) <-> sonic1:eth2 (br-vlan100)
    ptfhost:eth2 (port 1) <-> sonic1:eth3 (br-vlan100)

Tests:
    1. BroadcastForwardingTest: Send broadcast, verify it floods to other port
    2. MacLearningTest: Learn MAC, then verify unicast goes to correct port
"""

import ptf
import ptf.testutils as testutils
from ptf.base_tests import BaseTest
from ptf import config
from scapy.all import Ether, IP, ICMP, Raw
import time


class BroadcastForwardingTest(BaseTest):
    """
    Test: Broadcast frames should flood to all ports in the bridge.
    
    Send broadcast on port 0 (sonic1:eth2), expect to receive on port 1 (sonic1:eth3).
    """

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        print("\n=== Test: Broadcast Forwarding ===")
        
        # Create broadcast frame
        src_mac = "00:11:22:33:44:55"
        dst_mac = "ff:ff:ff:ff:ff:ff"  # Broadcast
        
        pkt = Ether(src=src_mac, dst=dst_mac) / \
              IP(src="10.100.1.100", dst="10.100.1.255") / \
              ICMP() / \
              Raw(load="BROADCAST_TEST")
        
        print(f"Sending broadcast frame on port 0")
        print(f"  src_mac={src_mac}, dst_mac={dst_mac}")
        
        # Send on port 0, expect on port 1 (bridge floods broadcast)
        testutils.send_packet(self, 0, pkt)
        
        # Verify packet arrives on port 1
        print("Verifying packet received on port 1...")
        testutils.verify_packet(self, pkt, port_id=1)
        
        print("=== Broadcast Forwarding Test PASSED ===\n")


class UnicastForwardingTest(BaseTest):
    """
    Test: After MAC learning, unicast frames go to the correct port.
    
    Step 1: Send frame from port 1 to learn its MAC on sonic1
    Step 2: Send unicast to that MAC from port 0
    Step 3: Verify it arrives on port 1 (not flooded everywhere)
    """

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        print("\n=== Test: Unicast Forwarding with MAC Learning ===")
        
        # MAC addresses
        mac_port0 = "00:aa:bb:cc:dd:01"  # Will send from port 0
        mac_port1 = "00:aa:bb:cc:dd:02"  # Will send from port 1 to learn it
        
        # Step 1: Learn mac_port1 by sending from port 1
        print(f"Step 1: Learning MAC {mac_port1} on port 1")
        learn_pkt = Ether(src=mac_port1, dst="ff:ff:ff:ff:ff:ff") / \
                    IP(src="10.100.1.101", dst="10.100.1.255") / \
                    ICMP() / \
                    Raw(load="LEARN")
        
        testutils.send_packet(self, 1, learn_pkt)
        time.sleep(0.5)  # Allow FDB to update
        
        # Flush receive buffers
        self.dataplane.flush()
        
        # Step 2: Send unicast from port 0 to mac_port1
        print(f"Step 2: Sending unicast from port 0 to {mac_port1}")
        unicast_pkt = Ether(src=mac_port0, dst=mac_port1) / \
                      IP(src="10.100.1.100", dst="10.100.1.101") / \
                      ICMP() / \
                      Raw(load="UNICAST_TEST")
        
        testutils.send_packet(self, 0, unicast_pkt)
        
        # Step 3: Verify packet arrives on port 1
        print("Step 3: Verifying unicast arrives on port 1...")
        testutils.verify_packet(self, unicast_pkt, port_id=1)
        
        print("=== Unicast Forwarding Test PASSED ===\n")


class NoFloodingToSourceTest(BaseTest):
    """
    Test: Frames should NOT be sent back to the source port.
    
    Send from port 0, verify it does NOT come back on port 0.
    """

    def setUp(self):
        BaseTest.setUp(self)
        self.dataplane = ptf.dataplane_instance
        self.dataplane.flush()
        
    def tearDown(self):
        BaseTest.tearDown(self)

    def runTest(self):
        print("\n=== Test: No Flooding to Source Port ===")
        
        pkt = Ether(src="00:11:22:33:44:55", dst="ff:ff:ff:ff:ff:ff") / \
              IP(src="10.100.1.100", dst="10.100.1.255") / \
              ICMP() / \
              Raw(load="NO_FLOOD_BACK")
        
        print("Sending broadcast on port 0, verifying no return on port 0")
        testutils.send_packet(self, 0, pkt)
        
        # Should NOT receive on port 0 (source port)
        testutils.verify_no_packet(self, pkt, port_id=0)
        
        print("=== No Flooding to Source Test PASSED ===\n")
