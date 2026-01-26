#!/bin/bash

# ============================================
# UPDATE OPERATING HOURS
# ============================================
# Uso: ./update-operating-hours.sh [ID] [Ore]
# ============================================

set -e

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Vai a directory network
cd ~/fabric-projects/fabric-maintenance-network/network

# ============================================
# SETUP AMBIENTE
# ============================================
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# ============================================
# MACCHINA E NUMERO ORE CONFIGURABILI
# ============================================
MACHINE_ID="${1:-MACH003}"
HOURS="${2:-8}"

echo -e "${BLUE}Aggiornamento $MACHINE_ID: +$HOURS ore${NC}"

# ============================================
# VERIFICA ESISTENZA MACCHINA
# ============================================
echo -e "${YELLOW}Verifica esistenza macchina...${NC}"

MACHINE_DATA=$(peer chaincode query \
    -C maintenancech \
    -n maintenance \
    -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}" 2>&1 || true)

if echo "$MACHINE_DATA" | grep -q "non trovata"; then
    echo -e "${RED}[ERRORE] Macchina $MACHINE_ID non esiste${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Macchina trovata${NC}"

# ============================================
# STATO PRIMA
# ============================================
BEFORE=$(peer chaincode query -C maintenancech -n maintenance -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}")
HOURS_BEFORE=$(echo "$BEFORE" | jq -r '.operatingHours')

# ============================================
# AGGIORNAMENTO DELLE ORE
# ============================================
peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/service.example.com/peers/peer0.service.example.com/tls/ca.crt \
    -c "{\"function\":\"UpdateOperatingHours\",\"Args\":[\"$MACHINE_ID\",\"$HOURS\"]}" > /dev/null 2>&1
sleep 3

# ============================================
# STATO DOPO
# ============================================
AFTER=$(peer chaincode query -C maintenancech -n maintenance -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}")
HOURS_AFTER=$(echo "$AFTER" | jq -r '.operatingHours')

echo -e "${GREEN}Aggiornamento ore completato: da $HOURS_BEFORE a $HOURS_AFTER ore${NC}"