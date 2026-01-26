!/bin/bash

# ============================================
# REGISTER MACHINE
# ============================================
# Uso: ./register-machine.sh [ID] [Nome] [Modello]
# ============================================

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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
# PARAMETRI MACCHINA CONFIGURABILI
# ============================================
MACHINE_ID="${1:-MACH003}"
MACHINE_NAME="${2:-Pressa Idraulica}"
MACHINE_MODEL="${3:-Schuler 1000T}"
OPERATING_HOURS="${4:-0}"
STATUS="${5:-funzionante}"
INTERVENTIONS_FILE="${6:-}"

echo -e "${BLUE}Registrazione nuova macchina...${NC}"
echo -e "${YELLOW}ID:       $MACHINE_ID${NC}"
echo -e "${YELLOW}Nome:     $MACHINE_NAME${NC}"
echo -e "${YELLOW}Modello:  $MACHINE_MODEL${NC}"
echo -e "${YELLOW}Ore:      $OPERATING_HOURS${NC}"
echo -e "${YELLOW}Stato:    $STATUS${NC}"
# Gestione interventi pregressi
INTERVENTIONS_JSON="[]"
if [ -n "$INTERVENTIONS_FILE" ]; then
    if [ ! -f "$INTERVENTIONS_FILE" ]; then
        echo -e "${RED}[ERRORE] File interventi non trovato: $INTERVENTIONS_FILE${NC}"
        exit 1
    fi
    
    INTERVENTIONS_JSON=$(jq -c '.' "$INTERVENTIONS_FILE" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERRORE] File JSON non valido${NC}"
        echo "$INTERVENTIONS_JSON"
        exit 1
    fi
    
    NUM_INTERVENTIONS=$(echo "$INTERVENTIONS_JSON" | jq 'length')
    echo -e "${YELLOW}Interventi pregressi: $NUM_INTERVENTIONS${NC}"
fi
echo ""

# ============================================
# VERIFICA SE MACCHINA ESISTE GIA'
# ============================================
echo -e "${BLUE}Verifica se macchina esiste gia...${NC}"
EXISTING=$(peer chaincode query -C maintenancech -n maintenance \
    -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}" 2>&1 || true)

if echo "$EXISTING" | grep -q "non trovata"; then
    echo -e "${GREEN}ID disponibile${NC}"
else
    echo -e "${RED}Errore: Macchina $MACHINE_ID gia' esistente${NC}"
    echo -e "${MAGENTA}Macchina $MACHINE_ID:${NC}"
    echo "$EXISTING" | jq '.'
    exit 1
fi

# ============================================
# REGISTRAZIONE MACCHINA
# ============================================
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
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/service.example.com/peers/peer0.service.example.com/tls/ca.crt" \
    -c "{\"function\":\"RegisterMachine\",\"Args\":[\"$MACHINE_ID\",\"$MACHINE_NAME\",\"$MACHINE_MODEL\",\"$OPERATING_HOURS\",\"$STATUS\",$(echo "$INTERVENTIONS_JSON" | jq -R)]}" 2>&1)

INVOKE_STATUS=$?
# Mostra solo eventuali errori
if [ $INVOKE_STATUS -ne 0 ]; then
    echo "$RESULT"
fi
if [ $INVOKE_STATUS -eq 0 ]; then
    echo -e "${GREEN}Macchina $MACHINE_ID registrata con successo${NC}"
else
    echo -e "${RED}[ERRORE] Registrazione fallita${NC}"
    exit 1
fi