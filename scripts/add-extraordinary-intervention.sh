#!/bin/bash

# ============================================
# ADD EXTRAORDINARY INTERVENTION
# ============================================
# Uso: ./add-extraordinary-intervention.sh [ID] [Descrizione] [Tecnico]
# ============================================

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Vai a directory network
cd ~/fabric-projects/fabric-maintenance-network/network

# ============================================
# SETUP AMBIENTE
# ============================================
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="ExtraordinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/extraordinary.example.com/users/Admin@extraordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# ============================================
# PARAMETRI INTERVENTO CONFIGURABILI
# ============================================
MACHINE_ID="${1:-MACH003}"
DESCRIPTION="${2:-Riparazione sistema idraulico}"
TECHNICIAN="${3:-Tecnico Marco Bianchi}"
INTERVENTION_TYPE="straordinaria"

echo -e "${BLUE}Registrazione manutenzione straordinaria${NC}"
echo "Macchina:     $MACHINE_ID"
echo "Descrizione:  $DESCRIPTION"
echo "Tecnico:      $TECHNICIAN"
echo ""

# ============================================
# VERIFICA ESISTENZA MACCHINA E STATO GUASTO
# ============================================
echo -e "${BLUE}Verifica esistenza e stato macchina...${NC}"

MACHINE_DATA=$(peer chaincode query \
    -C maintenancech \
    -n maintenance \
    -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}" 2>&1 || true)

if echo "$MACHINE_DATA" | grep -q "non trovata"; then
    echo -e "${RED}[ERRORE] Macchina $MACHINE_ID non esiste${NC}"
    echo -e ""
    exit 1
fi

CURRENT_STATUS=$(echo "$MACHINE_DATA" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ -z "$CURRENT_STATUS" ]; then
    echo -e "${RED}[ERRORE] Impossibile leggere stato macchina${NC}"
    exit 1
fi
if [ "$CURRENT_STATUS" != "guasto" ]; then
    echo -e "${RED}[ERRORE] Manutenzione straordinaria non necessaria${NC}"
    echo -e "${YELLOW}La macchina $MACHINE_ID non e in stato 'guasto' (stato attuale: $CURRENT_STATUS)"
    echo "La manutenzione straordinaria puo essere eseguita solo su macchine guaste"
    exit 1
fi
echo -e "${GREEN}Macchina esistente e in stato 'guasto'. Intervento autorizzato${NC}"
echo ""

# ============================================
# REGISTRAZIONE INTERVENTO
# ============================================
echo -e "${BLUE}Registrazione intervento su blockchain..."
RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "$ORDERER_CA" \
    -C maintenancech \
    -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:11051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt" \
    -c "{\"function\":\"AddIntervention\",\"Args\":[\"$MACHINE_ID\",\"$INTERVENTION_TYPE\",\"$DESCRIPTION\",\"$TECHNICIAN\"]}" 2>&1)
    
INVOKE_STATUS=$?
if [ $INVOKE_STATUS -ne 0 ]; then
    echo -e "${RED}[ERRORE] Registrazione fallita${NC}"
    echo "$RESULT"
    exit 1
fi
if [ $INVOKE_STATUS -eq 0 ]; then
    # Attesa propagazione blocco
    sleep 3
    
    UPDATED_DATA=$(peer chaincode query -C maintenancech -n maintenance \
        -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}")
    
    UPDATED_STATUS=$(echo "$UPDATED_DATA" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$UPDATED_STATUS" = "funzionante" ]; then
        echo -e "${GREEN}Intervento completato: macchina $MACHINE_ID ripristinata a stato 'funzionante'${NC}"
    else
        echo ""
        echo -e "${RED}[ERROR] Stato non aggiornato come previsto${NC}"
    fi
    echo ""
else
    echo -e "${RED}[ERRORE] Registrazione intervento fallita${NC}"
    exit 1
fi