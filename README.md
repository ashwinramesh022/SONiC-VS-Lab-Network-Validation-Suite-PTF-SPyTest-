# SONiC VS Lab + Network Validation Suite

A reproducible virtual SONiC testbed with automated L2/L3 network validation using PTF and SPyTest-style testing frameworks.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20ARM64-lightgrey.svg)
![Docker](https://img.shields.io/badge/docker-required-blue.svg)

## Overview

This project demonstrates network validation skills relevant to SONiC NOS environments:

- **Virtual Testbed**: 2 virtual switches + 1 PTF traffic generator using containerlab
- **L2 Validation**: VLAN forwarding, MAC learning, bridge operations
- **L3 Validation**: Static routing, inter-switch connectivity
- **ACL Testing**: Permit/deny rules validation using iptables
- **Automated Testing**: PTF dataplane tests + SPyTest control plane tests
- **Artifact Collection**: Automated log/config gathering and reporting

## Architecture

                ┌─────────────┐
                │   ptfhost   │
                │  (PTF/Scapy)│
                │ eth1   eth2 │
                └──┬───────┬──┘
                   │       │
      10.100.1.x   │       │  10.100.2.x
      (VLAN 100)   │       │  (VLAN 100)
                   │       │
                ┌──┴──┐ ┌──┴──┐
                │sonic1│ │sonic2│
                │      │ │      │
                │ eth1 ├─┤ eth1 │
                └──────┘ └──────┘
                   10.0.0.1 ◄──► 10.0.0.2
                     (L3 routed link)
## Requirements

- **Host OS**: Ubuntu 22.04 (ARM64 or x86_64)
- **Docker Engine**: 20.10+
- **containerlab**: 0.40+
- **Python**: 3.10+
- **Memory**: 4GB+ recommended
- **Disk**: 10GB+ free space

### For Apple Silicon Mac Users

This lab runs inside an Ubuntu VM using UTM. See [docs/apple-silicon-setup.md](docs/apple-silicon-setup.md) for detailed instructions.

## Quick Start (10 minutes)

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/sonic-vs-lab.git
cd sonic-vs-lab

# 2. Build Docker images (first time only)
make build

# 3. Start the lab
make up

# 4. Configure networking
make config

# 5. Run all tests
make test

# 6. View results
cat reports/ptf_report_*.md
cat reports/spytest_report_*.md

# 7. Stop the lab when done
make down EOF
