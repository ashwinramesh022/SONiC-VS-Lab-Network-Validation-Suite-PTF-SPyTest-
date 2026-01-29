# Virtual Switch Network Validation Lab

A containerlab-based network testbed demonstrating L2/L3 forwarding validation using PTF (Packet Test Framework). This project mirrors the validation patterns used in SONiC network testing.

![Platform](https://img.shields.io/badge/platform-Linux%20ARM64%2Fx86__64-lightgrey.svg)
![Docker](https://img.shields.io/badge/docker-required-blue.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## Overview

This project demonstrates network validation skills relevant to switch/router testing:

- **Virtual Testbed**: 2 Linux switches + 1 PTF traffic generator using containerlab
- **L2 Validation**: VLAN bridge forwarding, MAC learning, broadcast flooding
- **L3 Validation**: Static routing, inter-switch connectivity
- **ACL Testing**: L2 filtering with ebtables (permit/deny validation)
- **Dataplane Testing**: PTF tests with `verify_packet` and `verify_no_packet` assertions
- **Control-Plane Checks**: Python scripts validating route installation and connectivity

## Architecture
                ┌─────────────────────┐
                │      ptfhost        │
                │   (PTF + Scapy)     │
                │                     │
                │ eth1 eth2 eth3 eth4 │
                └──┬────┬────┬────┬───┘
                   │    │    │    │
     ┌─────────────┘    │    │    └─────────────┐
     │                  │    │                  │
     ▼                  ▼    ▼                  ▼
┌─────────┐        ┌─────────┐            ┌─────────┐
│ sonic1  │        │ sonic1  │            │ sonic2  │
│  eth2   │        │  eth3   │            │eth2 eth3│
│         │        │         │            │         │
│    br-vlan100    │         │            │ br-vlan100
│   (L2 bridge)    │         │            │(L2 bridge)
│         │        │         │            │         │
│  eth1   ├────────┴─────────┴────────────┤  eth1   │
└─────────┘     10.0.0.1 <-> 10.0.0.2     └─────────┘
                (L3 routed link)
### Port Mappings

| PTF Port | ptfhost Interface | Connected To | Purpose |
|----------|-------------------|--------------|---------|
| 0 | eth1 | sonic1:eth2 | L2 test ingress |
| 1 | eth2 | sonic1:eth3 | L2 test egress |
| 2 | eth3 | sonic2:eth2 | L2 test (sonic2) |
| 3 | eth4 | sonic2:eth3 | L2 test (sonic2) |

## Requirements

- **OS**: Linux (Ubuntu 22.04 recommended)
- **Docker**: 20.10+
- **containerlab**: 0.40+
- **Python**: 3.9+
- **Memory**: 2GB+ available
- **Architecture**: ARM64 or x86_64

### Apple Silicon Mac Users

This lab runs inside an Ubuntu ARM64 VM. Use UTM to create an Ubuntu 22.04 VM, then install Docker and containerlab inside the VM.

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/yourusername/sonic-vs-lab.git
cd sonic-vs-lab

# 2. Build Docker images (first time only)
make build

# 3. Start the lab
make up

# 4. Configure L2/L3 networking
make config

# 5. Run all tests
make test

# 6. View results
cat reports/ptf_report_*.md
cat reports/ctrlplane_report_*.md

# 7. Stop lab when done
make down EOF
