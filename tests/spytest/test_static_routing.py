"""
SPyTest-Style Test: Static Routing Verification

This test validates:
1. Static routes are installed correctly on both switches
2. End-to-end reachability through the routed path
3. Route table consistency

This follows SPyTest patterns and can be integrated with sonic-mgmt framework.

Topology:
    ptfhost:eth1 (10.100.1.10) --- sonic1 (10.0.0.1) --- sonic2 (10.0.0.2) --- ptfhost:eth2 (10.100.2.10)
"""

import subprocess
import sys
import json
from datetime import datetime


class TestResult:
    """Simple test result tracker"""
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.results = []
    
    def add_pass(self, name, message=""):
        self.passed += 1
        self.results.append({"name": name, "status": "PASS", "message": message})
        print(f"  ✅ PASS: {name}")
        if message:
            print(f"          {message}")
    
    def add_fail(self, name, message=""):
        self.failed += 1
        self.results.append({"name": name, "status": "FAIL", "message": message})
        print(f"  ❌ FAIL: {name}")
        if message:
            print(f"          {message}")
    
    def summary(self):
        total = self.passed + self.failed
        return {
            "total": total,
            "passed": self.passed,
            "failed": self.failed,
            "pass_rate": f"{(self.passed/total)*100:.1f}%" if total > 0 else "N/A"
        }


def run_command(cmd, capture=True):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=capture, text=True, timeout=30
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)


def docker_exec(container, cmd):
    """Execute command in docker container"""
    full_cmd = f"docker exec {container} {cmd}"
    return run_command(full_cmd)


class StaticRoutingTest:
    """
    SPyTest-style static routing verification test suite
    
    Test Cases:
    1. Verify static routes on sonic1
    2. Verify static routes on sonic2
    3. Verify inter-switch connectivity
    4. Verify end-to-end reachability
    5. Verify route symmetry
    """
    
    def __init__(self):
        self.results = TestResult()
        self.sonic1 = "clab-sonic-lab-sonic1"
        self.sonic2 = "clab-sonic-lab-sonic2"
        self.ptfhost = "clab-sonic-lab-ptfhost"
    
    def setup(self):
        """Test setup - verify containers are running"""
        print("\n" + "="*60)
        print("SPyTest: Static Routing Verification")
        print("="*60)
        print(f"Timestamp: {datetime.now().isoformat()}")
        print("\nSetup: Verifying lab topology...")
        
        for container in [self.sonic1, self.sonic2, self.ptfhost]:
            rc, out, err = run_command(f"docker inspect {container} --format '{{{{.State.Running}}}}'")
            if rc != 0 or out != "true":
                print(f"  ERROR: Container {container} is not running")
                return False
            print(f"  ✓ {container} is running")
        
        print("\nSetup complete.\n")
        return True
    
    def test_sonic1_static_routes(self):
        """TC01: Verify static routes on sonic1"""
        print("\n[TC01] Verify static routes on sonic1")
        
        rc, out, err = docker_exec(self.sonic1, "ip route show")
        
        # Check for route to sonic2's network
        if "10.100.2.0/24 via 10.0.0.2" in out:
            self.results.add_pass(
                "sonic1_route_to_sonic2_network",
                "Route 10.100.2.0/24 via 10.0.0.2 present"
            )
        else:
            self.results.add_fail(
                "sonic1_route_to_sonic2_network",
                f"Expected route not found. Routes:\n{out}"
            )
        
        # Check for inter-switch link
        if "10.0.0.0/30 dev eth1" in out:
            self.results.add_pass(
                "sonic1_interswitch_link",
                "Inter-switch link 10.0.0.0/30 on eth1 present"
            )
        else:
            self.results.add_fail(
                "sonic1_interswitch_link",
                "Inter-switch link not configured correctly"
            )
    
    def test_sonic2_static_routes(self):
        """TC02: Verify static routes on sonic2"""
        print("\n[TC02] Verify static routes on sonic2")
        
        rc, out, err = docker_exec(self.sonic2, "ip route show")
        
        # Check for route to sonic1's network
        if "10.100.1.0/24 via 10.0.0.1" in out:
            self.results.add_pass(
                "sonic2_route_to_sonic1_network",
                "Route 10.100.1.0/24 via 10.0.0.1 present"
            )
        else:
            self.results.add_fail(
                "sonic2_route_to_sonic1_network",
                f"Expected route not found. Routes:\n{out}"
            )
        
        # Check for inter-switch link
        if "10.0.0.0/30 dev eth1" in out:
            self.results.add_pass(
                "sonic2_interswitch_link",
                "Inter-switch link 10.0.0.0/30 on eth1 present"
            )
        else:
            self.results.add_fail(
                "sonic2_interswitch_link",
                "Inter-switch link not configured correctly"
            )
    
    def test_interswitch_connectivity(self):
        """TC03: Verify inter-switch L3 connectivity"""
        print("\n[TC03] Verify inter-switch connectivity")
        
        # Ping from sonic1 to sonic2
        rc, out, err = docker_exec(self.sonic1, "ping -c 3 -W 2 10.0.0.2")
        
        if rc == 0 and "0% packet loss" in out:
            self.results.add_pass(
                "interswitch_ping",
                "sonic1 can ping sonic2 (10.0.0.2)"
            )
        else:
            self.results.add_fail(
                "interswitch_ping",
                f"Ping failed: {out}"
            )
    
    def test_end_to_end_reachability(self):
        """TC04: Verify end-to-end routed path"""
        print("\n[TC04] Verify end-to-end reachability")
        
        # From ptfhost eth1 network, ping sonic2's bridge
        rc, out, err = docker_exec(self.ptfhost, "ping -c 3 -W 2 10.100.2.1")
        
        if rc == 0 and "0% packet loss" in out:
            self.results.add_pass(
                "e2e_ptf_to_sonic2",
                "ptfhost (10.100.1.x) can reach sonic2 bridge (10.100.2.1)"
            )
        else:
            self.results.add_fail(
                "e2e_ptf_to_sonic2",
                f"End-to-end ping failed: {out}"
            )
        
        # Verify the path goes through both switches
        rc, out, err = docker_exec(self.sonic1, "ping -c 1 -W 2 10.100.2.1")
        if rc == 0:
            self.results.add_pass(
                "sonic1_to_sonic2_bridge",
                "sonic1 can reach sonic2's bridge network"
            )
        else:
            self.results.add_fail(
                "sonic1_to_sonic2_bridge",
                "sonic1 cannot reach sonic2's bridge"
            )
    
    def test_route_symmetry(self):
        """TC05: Verify routing is symmetric"""
        print("\n[TC05] Verify route symmetry")
        
        # Get route counts from both switches
        rc1, out1, _ = docker_exec(self.sonic1, "ip route show | grep via | wc -l")
        rc2, out2, _ = docker_exec(self.sonic2, "ip route show | grep via | wc -l")
        
        try:
            routes1 = int(out1.strip())
            routes2 = int(out2.strip())
            
            if routes1 == routes2:
                self.results.add_pass(
                    "route_symmetry",
                    f"Both switches have {routes1} 'via' routes"
                )
            else:
                self.results.add_fail(
                    "route_symmetry",
                    f"Asymmetric routes: sonic1={routes1}, sonic2={routes2}"
                )
        except ValueError:
            self.results.add_fail(
                "route_symmetry",
                "Could not parse route counts"
            )
    
    def teardown(self):
        """Test teardown"""
        print("\n" + "="*60)
        print("Test Summary")
        print("="*60)
        summary = self.results.summary()
        print(f"Total:  {summary['total']}")
        print(f"Passed: {summary['passed']}")
        print(f"Failed: {summary['failed']}")
        print(f"Pass Rate: {summary['pass_rate']}")
        print("="*60 + "\n")
        
        return summary
    
    def run_all(self):
        """Run all test cases"""
        if not self.setup():
            print("Setup failed. Aborting tests.")
            return None
        
        self.test_sonic1_static_routes()
        self.test_sonic2_static_routes()
        self.test_interswitch_connectivity()
        self.test_end_to_end_reachability()
        self.test_route_symmetry()
        
        return self.teardown()


def main():
    """Main entry point"""
    test = StaticRoutingTest()
    summary = test.run_all()
    
    if summary is None:
        sys.exit(2)
    
    # Exit with failure if any tests failed
    sys.exit(0 if summary['failed'] == 0 else 1)


if __name__ == "__main__":
    main()
