#!/bin/bash

# ============================================
# SET MACHINE STATUS
# ============================================
# Uso: ./set-machine-status.sh [ID] [Stato]
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

# Directory base
BASE_DIR="$HOME/fabric-projects/fabric-maintenance-network"
NETWORK_DIR="$BASE_DIR/network"
SCRIPTS_DIR="$BASE_DIR/scripts"

# ============================================
# CARICA HELPER ALERT
# ============================================
source "$SCRIPTS_DIR/lib/alert-helper.sh"

# Vai a directory network
cd "$NETWORK_DIR"

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
# PARAMETRI
# ============================================
MACHINE_ID="${1:-MACH003}"
NEW_STATUS="${2:-guasto}"

# Validazione stato
if [ "$NEW_STATUS" != "funzionante" ] && [ "$NEW_STATUS" != "guasto" ]; then
    echo -e "${RED}Status non valido: $NEW_STATUS${NC}"
    echo -e "${YELLOW}Usa: 'funzionante' o 'guasto'${NC}"
    exit 1
fi

# ============================================
# VERIFICA STATO ATTUALE
# ============================================
echo -e "${BLUE}Verifica stato attuale...${NC}"

CURRENT_DATA=$(peer chaincode query -C maintenancech -n maintenance \
    -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}" 2>&1)

if echo "$CURRENT_DATA" | grep -q "non trovata"; then
    echo -e "${RED}[ERRORE] Macchina $MACHINE_ID non trovata${NC}"
    exit 1
fi

CURRENT_STATUS=$(echo "$CURRENT_DATA" | jq -r '.status')
MACHINE_NAME=$(echo "$CURRENT_DATA" | jq -r '.name')

echo -e "  ${CYAN}Macchina:${NC} $MACHINE_NAME ($MACHINE_ID)"
echo -e "  ${CYAN}Stato attuale:${NC} ${MAGENTA}$CURRENT_STATUS${NC}"
echo -e "  ${CYAN}Nuovo stato:${NC}   ${MAGENTA}$NEW_STATUS${NC}"
echo ""

# ============================================
# CONTROLLA SE GIA' NELLO STATO RICHIESTO
# ============================================
if [ "$CURRENT_STATUS" = "$NEW_STATUS" ]; then
    echo -e "${YELLOW}Macchina gia' in stato '$NEW_STATUS'${NC}"
    echo ""
    echo -e "${GREEN}Nessuna modifica necessaria${NC}"
    echo ""
    exit 0
fi

# ============================================
# AGGIORNAMENTO STATO
# ============================================
echo -e "${BLUE}Aggiornamento stato...${NC}"

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "$ORDERER_CA" \
    -C maintenancech \
    -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt \
    -c "{\"function\":\"SetMachineStatus\",\"Args\":[\"$MACHINE_ID\",\"$NEW_STATUS\"]}" 2>&1 | grep -v "Chaincode invoke successful" || true
    
echo -e "${GREEN}Stato aggiornato correttamente${NC}"
echo ""

# ============================================
# CREA ALERT SE STATO = GUASTO
# ============================================
if [ "$NEW_STATUS" = "guasto" ]; then
    echo -e "${BLUE}Creazione segnalazione...${NC}"
    
    ALERT_MSG="Operatore ha segnalato guasto su macchina $MACHINE_NAME"
    
    create_alert "$MACHINE_ID" "$MACHINE_NAME" "guasto_segnalato" "$ALERT_MSG" > /dev/null
    
    echo -e "${GREEN}Segnalazione creata con successo${NC}"
    echo ""
fi