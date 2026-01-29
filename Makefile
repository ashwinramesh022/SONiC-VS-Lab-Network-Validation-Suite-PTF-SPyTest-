.PHONY: all up down config test test-ptf test-spytest collect clean help status ping build reset

all: help

up:
	@echo "Starting SONiC VS Lab..."
	cd lab && sudo containerlab deploy -t topo.yml
	@echo "Lab is up. Run make config to configure networking."

down:
	@echo "Stopping SONiC VS Lab..."
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
	@echo "Running SPyTest..."
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
	@echo "SONiC VS Lab - Network Validation Suite"
	@echo "Targets: up down config test test-ptf test-spytest collect status ping clean reset build help"
	@echo "Quick Start: make build && make up && make config && make test && make down"
