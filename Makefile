.PHONY: all up down config test test-ptf test-spytest collect clean help status ping build reset verify-l2

all: help

up:
	@echo "Starting lab..."
	cd lab && sudo containerlab deploy -t topo.yml
	@echo "Lab is up. Run make config to configure networking."

down:
	@echo "Stopping lab..."
	cd lab && sudo containerlab destroy -t topo.yml || true
	@echo "Lab is down."

config:
	@echo "Configuring network..."
	./lab/bringup.sh
	@echo "Network configured. Run make test to run all tests."

test: test-ptf test-spytest
	@echo "All tests completed!"

test-ptf:
	@echo "Running PTF tests..."
	./tools/run_ptf.sh

test-spytest:
	@echo "Running control-plane validation..."
	./tools/run_spytest.sh

collect:
	@echo "Collecting artifacts..."
	./lab/collect_artifacts.sh

status:
	@docker ps --filter "name=clab-sonic-lab" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "No containers running"

ping:
	@echo "Connectivity Check:"
	@docker exec clab-sonic-lab-sonic1 ping -c 1 -W 1 10.0.0.2 >/dev/null 2>&1 && echo "sonic1 -> sonic2: OK" || echo "sonic1 -> sonic2: FAIL"
	@docker exec clab-sonic-lab-ptfhost ping -c 1 -W 1 10.100.1.1 >/dev/null 2>&1 && echo "ptfhost -> sonic1: OK" || echo "ptfhost -> sonic1: FAIL"
	@docker exec clab-sonic-lab-ptfhost ping -c 1 -W 1 10.100.2.1 >/dev/null 2>&1 && echo "ptfhost -> sonic2: OK" || echo "ptfhost -> sonic2: FAIL"

verify-l2:
	@echo "=== sonic1 bridge state ==="
	@docker exec clab-sonic-lab-sonic1 bridge link show
	@echo ""
	@echo "=== sonic1 FDB (learned MACs) ==="
	@docker exec clab-sonic-lab-sonic1 bridge fdb show | grep -v permanent || true
	@echo ""
	@echo "=== sonic1 IP addresses ==="
	@docker exec clab-sonic-lab-sonic1 ip -4 addr show | grep -E "inet |^[0-9]"
	@echo ""
	@echo "=== sonic1 routes ==="
	@docker exec clab-sonic-lab-sonic1 ip route
	@echo ""
	@echo "=== sonic2 bridge state ==="
	@docker exec clab-sonic-lab-sonic2 bridge link show
	@echo ""
	@echo "=== sonic2 FDB (learned MACs) ==="
	@docker exec clab-sonic-lab-sonic2 bridge fdb show | grep -v permanent || true
	@echo ""
	@echo "=== sonic2 IP addresses ==="
	@docker exec clab-sonic-lab-sonic2 ip -4 addr show | grep -E "inet |^[0-9]"
	@echo ""
	@echo "=== sonic2 routes ==="
	@docker exec clab-sonic-lab-sonic2 ip route

clean:
	rm -rf artifacts/2*
	rm -rf reports/ptf_report_2*.md reports/spytest_report_2*.md
	@echo "Cleaned."

reset: down clean
	@echo "Full reset complete."

build:
	@echo "Building Docker images..."
	cd docker && docker build -t sonic-lab-switch:latest -f Dockerfile.switch .
	cd docker && docker build -t sonic-lab-ptfhost:latest -f Dockerfile.ptfhost .
	@echo "Images built."

help:
	@echo "Virtual Switch Network Validation Lab"
	@echo "Targets: build up down config test test-ptf test-spytest verify-l2 collect status ping clean reset"
	@echo "Quick Start: make build && make up && make config && make test"
