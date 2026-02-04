#!/bin/bash

# ============================================
# ADD SCHEDULED MAINTENANCE
# ============================================
# Uso: ./add-scheduled-maintenance.sh [ID] [Descrizione] [Tecnico]
# ============================================

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Vai a directory network
cd ~/fabric-projects/fabric-maintenance-network/network

# ============================================
# SETUP AMBIENTE
# ============================================
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# ============================================
# PARAMETRI INTERVENTO CONFIGURABILI
# ============================================
MACHINE_ID="${1:-MACH001}"
DESCRIPTION="${2:-Manutenzione ordinaria programmata}"
TECHNICIAN="${3:-Tecnico ServiceMSP - Mario Rossi}"
INTERVENTION_TYPE="ordinaria"

echo -e "${BLUE}Registrazione manutenzione ordinaria:${NC}"
echo "  Macchina:     $MACHINE_ID"
echo "  Descrizione:  $DESCRIPTION"
echo "  Tecnico:      $TECHNICIAN"
echo ""

# ============================================
# VERIFICA ESISTENZA MACCHINA
# ============================================
echo -e "${BLUE}Verifica esistenza macchina...${NC}"

MACHINE_DATA=$(peer chaincode query \
    -C maintenancech \
    -n maintenance \
    -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}" 2>&1 || true)

if echo "$MACHINE_DATA" | grep -q "non trovata"; then
    echo -e "${RED}[ERRORE] Macchina $MACHINE_ID non esiste${NC}"
    exit 1
fi

MACHINE_NAME=$(echo "$MACHINE_DATA" | jq -r '.name')
MACHINE_MODEL=$(echo "$MACHINE_DATA" | jq -r '.model')
CURRENT_STATUS=$(echo "$MACHINE_DATA" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
CURRENT_HOURS=$(echo "$MACHINE_DATA" | jq -r '.operatingHours')

echo -e "${GREEN}Macchina trovata${NC}"
echo "  Nome:          $MACHINE_NAME"
echo "  Modello:       $MACHINE_MODEL"
echo "  Stato attuale: $CURRENT_STATUS"
echo "  Ore operative: $CURRENT_HOURS"
echo ""

# ============================================
# REGISTRAZIONE INTERVENTO
# ============================================
echo -e "${BLUE}Registrazione intervento su blockchain...${NC}"
RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "$ORDERER_CA" \
    -C maintenancech \
    -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c "{\"function\":\"AddIntervention\",\"Args\":[\"$MACHINE_ID\",\"$INTERVENTION_TYPE\",\"$DESCRIPTION\",\"$TECHNICIAN\"]}" 2>&1)

INVOKE_STATUS=$?
if [ $INVOKE_STATUS -ne 0 ]; then
    echo -e "${RED}[ERRORE] Registrazione fallita${NC}"
    echo "$RESULT"
    exit 1
fi
echo ""
echo -e "${GREEN}Manutenzione ordinaria completata alle $(date '+%H:%M:%S')${NC}"
echo ""
