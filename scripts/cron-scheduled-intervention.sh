#!/bin/bash

# Setup PATH per cron - Fabric binaries
export PATH="/home/cantellos/fabric-projects/fabric-samples/bin:/usr/bin:/usr/local/bin:$PATH"

# Carica variabili ambiente Fabric
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

# Wrapper per esecuzione da cron

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Paths
BASE_DIR="$HOME/fabric-projects/fabric-maintenance-network"
NETWORK_DIR="$BASE_DIR/network"
SCRIPTS_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/scheduled-intervention.log"

# Crea directory log
mkdir -p "$LOG_DIR"

echo "========================================" >> "$LOG_FILE"
echo "[$TIMESTAMP] AVVIO MANUTENZIONE PROGRAMMATA" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Vai a network directory e setup ambiente (come query-machines.sh)
cd "$NETWORK_DIR"

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Query tutte le macchine (come in query-machines.sh)
echo "[$TIMESTAMP] Recupero lista macchine..." >> "$LOG_FILE"

MACHINES_JSON=$(peer chaincode query -C maintenancech -n maintenance \
    -c '{"function":"GetAllMachines","Args":[]}' 2>&1)

QUERY_STATUS=$?

if [ $QUERY_STATUS -ne 0 ]; then
    echo "[$TIMESTAMP] ERRORE query: $MACHINES_JSON" >> "$LOG_FILE"
    exit 1
fi

# Estrai ID macchine
MACHINE_IDS=$(echo "$MACHINES_JSON" | jq -r '.[].id' 2>&1)

if [ -z "$MACHINE_IDS" ]; then
    echo "[$TIMESTAMP] Nessuna macchina trovata" >> "$LOG_FILE"
    exit 0
fi

echo "[$TIMESTAMP] Macchine trovate: $MACHINE_IDS" >> "$LOG_FILE"

# Esegui manutenzione ordinaria su ogni macchina
cd "$SCRIPTS_DIR"

for MACHINE_ID in $MACHINE_IDS; do
    echo "[$TIMESTAMP] Elaborazione $MACHINE_ID..." >> "$LOG_FILE"
    
    ./add-ordinary-intervention.sh \
        "$MACHINE_ID" \
        "Manutenzione ordinaria programmata" \
        "Tecnico OrdinaryMSP - Team Manutenzione" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "[$TIMESTAMP] $MACHINE_ID: OK" >> "$LOG_FILE"
    else
        echo "[$TIMESTAMP] $MACHINE_ID: ERRORE" >> "$LOG_FILE"
    fi
    
    echo "" >> "$LOG_FILE"
done

echo "[$TIMESTAMP] MANUTENZIONE PROGRAMMATA COMPLETATA" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
