# Fabric Maintenance Network

A Hyperledger Fabric blockchain network for managing industrial machinery maintenance in Industry 4.0 contexts. The system provides transparent maintenance workflows, immutable audit trails, and multi-organizational coordination between machine owners and maintenance service providers.

## Overview

This project implements a blockchain-based maintenance management system using Hyperledger Fabric 2.5. The network consists of three organizations with distinct roles and access controls:

- **OwnerMSP**: Machine owners who register equipment, track operating hours, and monitor machine status
- **OrdinaryMSP**: Service providers handling routine scheduled maintenance
- **ExtraordinaryMSP**: Emergency maintenance providers responding to unexpected breakdowns

The architecture enforces strict access controls through MSP-based identity verification in the chaincode and flexible endorsement policies that allow autonomous owner operations while requiring bilateral consensus for maintenance activities.

## Architecture

### Network Components

- **1 Orderer**: Consensus service using Raft ordering
- **3 Peer Organizations**: Owner, Ordinary Service, Extraordinary Service
- **1 Channel**: `maintenancech` with shared ledger across all organizations
- **Go Chaincode**: Smart contract with role-based access controls
- **Node.js Web Application**: Query interface and transaction submission
- **Automated Monitoring**: Cron-based maintenance alerts with email notifications

### Endorsement Policy

The chaincode uses a sophisticated OR/AND endorsement policy:

```
OR('OwnerMSP.peer', 
   AND('OwnerMSP.peer', 'OrdinaryMSP.peer'), 
   AND('OwnerMSP.peer', 'ExtraordinaryMSP.peer'))
```

This allows:
- Owners to autonomously manage their machines (register, update hours, set status)
- Maintenance operations to require dual endorsement (owner + appropriate service provider)
- Privacy between competing maintenance providers (ordinary and extraordinary services)

## Prerequisites

This project requires specific versions for compatibility:

- **Hyperledger Fabric**: 2.5.14
- **Go**: 1.21.0
- **Node.js**: 24.13.0
- **npm**: 11.6.2
- **Docker Desktop**: 4.34.0
- **Docker Compose**: 2.29.2
- **Postfix**: 3.6.4 (for email alerts)
- **Bash**: 5.1.16
- **jq**: Latest version (auto-installed by setup script)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Cantellos/fabric-maintenance-network.git
cd fabric-maintenance-network
```

### 2. Run Complete Setup

The automated setup script handles the entire network deployment:

```bash
cd network
./setup-completo.sh
```

This script performs the following steps:
1. Cleans any existing network artifacts
2. Generates cryptographic materials for all organizations
3. Starts Docker containers (orderer + 3 peers)
4. Creates and joins channel `maintenancech`
5. Packages and installs chaincode on all peers
6. Approves and commits chaincode with endorsement policy
7. Initializes ledger with sample machines

Expected completion time: 2-3 minutes.

### 3. Verify Network Status

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

You should see 4 containers running:
- `orderer.example.com`
- `peer0.owner.example.com`
- `peer0.ordinary.example.com`
- `peer0.extraordinary.example.com`

## Testing

### Automated Test Suite

Run the complete access control test suite:

```bash
cd network
./test-completo.sh
```

This validates:
- Machine registration permissions (Owner-only)
- Status modification access controls
- Ordinary maintenance endorsement requirements
- Extraordinary maintenance authorization
- Endorsement policy enforcement

Expected output: 10/10 tests passed.

### Manual Testing

Individual test scenarios are available in `test-singoli.sh`. Each test can be run independently to verify specific access control rules.

## Project Structure

```
fabric-maintenance-network/
├── chaincode/
│   └── maintenance/
│       └── go/
│           ├── maintenance.go       # Smart contract implementation
│           ├── go.mod
│           └── go.sum
├── network/
│   ├── crypto-config.yaml          # Certificate generation config
│   ├── configtx.yaml               # Channel configuration
│   ├── docker-compose.yaml         # Container orchestration
│   ├── setup-completo.sh           # Automated network setup
│   ├── test-completo.sh            # Automated test suite
│   ├── test-singoli.sh             # Individual test scenarios
│   ├── organizations/              # Generated certificates (not in git)
│   └── channel-artifacts/          # Generated channel artifacts (not in git)
├── scripts/
│   └── lib/                        # Utility scripts
├── web-app/
│   ├── app.js                      # Express server
│   ├── package.json
│   └── public/                     # Frontend assets
├── logs/
│   └── maintenance-alerts.log      # Alert system logs
├── .gitignore
├── LICENSE
└── README.md
```

## Chaincode Functions

### Machine Management

- **RegisterMachine**: Register a new machine (Owner only)
  ```
  Args: [id, name, model, operatingHours, status, interventionsJSON]
  ```

- **UpdateOperatingHours**: Increment machine operating hours (Owner only)
  ```
  Args: [id, hours]
  ```

- **SetMachineStatus**: Update machine status (Owner only)
  ```
  Args: [id, status]  // status: "funzionante" or "guasto"
  ```

- **ReadMachine**: Query machine details (All organizations)
  ```
  Args: [id]
  ```

- **GetAllMachines**: List all registered machines (All organizations)
  ```
  Args: []
  ```

### Maintenance Operations

- **AddIntervention**: Record maintenance intervention (Service providers + Owner endorsement)
  ```
  Args: [id, type, description, technician]
  // type: "ordinaria" (OrdinaryMSP only) or "straordinaria" (ExtraordinaryMSP only)
  ```

### Alert Management

- **CreateAlert**: Generate maintenance alert (Owner or OrdinaryMSP)
  ```
  Args: [machineId, machineName, alertType, message]
  ```

- **GetAlertsByMachine**: Retrieve alerts for specific machine
  ```
  Args: [machineId]
  ```

## Key Features

### MSP-Based Access Controls

The chaincode implements fine-grained access controls using Membership Service Provider (MSP) identities:

- Machine registration, status updates, and operating hours are restricted to OwnerMSP
- Ordinary maintenance interventions require OrdinaryMSP identity
- Extraordinary maintenance interventions require ExtraordinaryMSP identity
- Owner cannot unilaterally validate maintenance (prevented by chaincode logic)

### Dual-Layer Security

The system employs two security layers:

1. **Chaincode Identity Verification**: Prevents unauthorized function execution
2. **Endorsement Policy Validation**: Requires appropriate peer signatures before commit

This prevents scenarios where an owner could submit and self-endorse maintenance records.

### Automated Monitoring

A cron-based system periodically checks machine operating hours and:
- Identifies machines requiring maintenance
- Writes alerts to blockchain
- Sends email notifications via Postfix
- Logs all activities

### Audit Trail

All transactions (machine registration, status changes, maintenance interventions, alerts) are permanently recorded on the blockchain, providing:
- Immutable maintenance history
- Timestamped intervention records
- Transparent multi-party workflows
- Regulatory compliance support

## Web Application

The Node.js web application provides:

- Machine query interface
- Operating hours updates
- Maintenance intervention registration
- Alert viewing
- REST API endpoints for external integration

Start the web application:

```bash
cd web-app
npm install
node app.js
```

Access at `http://localhost:3000`

## Development Notes

This project was developed as part of a blockchain laboratory course focusing on Industry 4.0 applications. The implementation demonstrates:

- Multi-organization Hyperledger Fabric network configuration
- Complex endorsement policies with OR/AND logic
- MSP-based identity and access management
- Chaincode development in Go with access controls
- Client application integration using fabric-network SDK
- Automated monitoring and alerting systems

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions or issues, please open an issue on the GitHub repository.
