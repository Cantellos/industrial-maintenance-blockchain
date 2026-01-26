#!/bin/bash

# ============================================
# SCRIPT SETUP COMPLETO RETE BLOCKCHAIN
# ============================================

set -e
set -u
set -o pipefail

# Colori output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}[ERRORE] $1${NC}" >&2
    echo -e "${YELLOW}Consulta i logs per dettagli:${NC}"
    echo "  docker-compose logs"
    echo "  docker ps -a"
    exit 1
}

cleanup() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Script interrotto con errori${NC}"
    fi
}
trap cleanup EXIT

# ============================================
# FUNZIONE: CHECK E INSTALLA JQ
# ============================================
check_and_install_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq non trovato. Installazione in corso...${NC}"
        sudo apt-get update -qq && sudo apt-get install -y jq || error_exit "Impossibile installare jq"
        
        if ! command -v jq &> /dev/null; then
            error_exit "jq non installato correttamente"
        fi
        
        echo -e "${GREEN}[OK] jq installato con successo${NC}"
    fi
}

# ============================================
# FUNZIONE: HEALTH CHECK ORDERER
# ============================================
wait_for_orderer() {
    local MAX_RETRY=60
    local RETRY_COUNT=0
    
    echo -e "${YELLOW}Verifica health orderer (max 60 sec)...${NC}"
    
    while [ $RETRY_COUNT -lt $MAX_RETRY ]; do
        if docker exec orderer.example.com test -d /var/hyperledger &> /dev/null; then
            if docker exec orderer.example.com pgrep -f "orderer" &> /dev/null; then
                echo -e "${GREEN}[OK] Orderer pronto (dopo $RETRY_COUNT secondi)${NC}"
                return 0
            fi
        fi
        
        echo -n "."
        sleep 1
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done
    
    error_exit "Timeout: Orderer non risponde dopo $MAX_RETRY secondi"
}

# ============================================
# FUNZIONE: HEALTH CHECK PEER
# ============================================
wait_for_peer() {
    local PEER_NAME=$1
    local MAX_RETRY=60
    local RETRY_COUNT=0
    
    echo -e "${YELLOW}Verifica health $PEER_NAME (max 60 sec)...${NC}"
    
    while [ $RETRY_COUNT -lt $MAX_RETRY ]; do
        if docker exec "$PEER_NAME" test -d /var/hyperledger &> /dev/null; then
            if docker exec "$PEER_NAME" pgrep -f "peer node start" &> /dev/null; then
                echo -e "${GREEN}[OK] $PEER_NAME pronto (dopo $RETRY_COUNT secondi)${NC}"
                return 0
            fi
        fi
        
        echo -n "."
        sleep 1
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done
    
    echo -e "${RED}[ERRORE] Timeout: $PEER_NAME non risponde dopo $MAX_RETRY secondi${NC}"
    echo -e "${YELLOW}Verifica logs:${NC} docker logs $PEER_NAME"
    error_exit "Peer health check fallito"
}

# ============================================
# INIZIO SCRIPT
# ============================================
echo -e "${CYAN}"
echo "========================================"
echo "  SETUP COMPLETO RETE BLOCKCHAIN"
echo "========================================"
echo -e "${NC}"

check_and_install_jq

BASE_DIR="$HOME/fabric-projects/fabric-maintenance-network"
NETWORK_DIR="$BASE_DIR/network"
CHAINCODE_DIR="$BASE_DIR/chaincode/maintenance/go"

[ ! -d "$BASE_DIR" ] && error_exit "Directory progetto non trovata: $BASE_DIR"
[ ! -d "$NETWORK_DIR" ] && error_exit "Directory network non trovata: $NETWORK_DIR"
[ ! -d "$CHAINCODE_DIR" ] && error_exit "Directory chaincode non trovata: $CHAINCODE_DIR"

# ============================================
# STEP 1: PULIZIA AMBIENTE
# ============================================
echo -e "${YELLOW}[1/9] Pulizia ambiente...${NC}"

cd "$NETWORK_DIR"

docker-compose down --volumes --remove-orphans 2>/dev/null || true

docker ps -a | grep dev-peer | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
docker images | grep dev-peer | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

rm -rf organizations/ordererOrganizations
rm -rf organizations/peerOrganizations
rm -rf channel-artifacts/*

LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
touch "$LOG_DIR/maintenance-alerts.log"

echo -e "${GREEN}[OK] Ambiente pulito${NC}"
sleep 1

# ============================================
# STEP 2: GENERAZIONE CERTIFICATI
# ============================================
echo -e "${YELLOW}[2/9] Generazione certificati...${NC}"

cryptogen generate --config=./crypto-config.yaml --output="organizations" || error_exit "Errore generazione certificati"

if [ ! -d "organizations/peerOrganizations/owner.example.com" ]; then
    error_exit "Certificati non generati correttamente"
fi

echo -e "${GREEN}[OK] Certificati generati${NC}"
sleep 1

# ============================================
# STEP 3: AVVIO CONTAINER DOCKER
# ============================================
echo -e "${YELLOW}[3/9] Avvio container Docker...${NC}"

docker-compose up -d || error_exit "Errore avvio container"

echo "Attesa avvio container..."
MAX_RETRY=30
RETRY_COUNT=0
EXPECTED_CONTAINERS=3

while [ $RETRY_COUNT -lt $MAX_RETRY ]; do
    RUNNING=$(docker ps --filter "label=service=hyperledger-fabric" --format "{{.Names}}" | wc -l)
    
    if [ "$RUNNING" -eq "$EXPECTED_CONTAINERS" ]; then
        echo -e "${GREEN}[OK] Tutti i $EXPECTED_CONTAINERS container sono UP${NC}"
        break
    fi
    
    echo -n "."
    sleep 1
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRY ]; then
    echo -e "${RED}[ERRORE] Timeout: container non avviati dopo 30 secondi${NC}"
    docker ps -a
    error_exit "Container startup failed"
fi

wait_for_orderer
wait_for_peer "peer0.owner.example.com"
wait_for_peer "peer0.service.example.com"

echo -e "${GREEN}[OK] Tutti i container sono healthy${NC}"
sleep 2

# ============================================
# STEP 4: CREAZIONE GENESIS BLOCK CANALE
# ============================================
echo -e "${YELLOW}[4/9] Creazione genesis block canale...${NC}"

mkdir -p channel-artifacts

# FIX: Usa FABRIC_CFG_PATH solo per questo comando
cd "$NETWORK_DIR"
FABRIC_CFG_PATH=${PWD} configtxgen -profile MaintenanceChannel \
    -outputBlock ./channel-artifacts/maintenancech.block \
    -channelID maintenancech || error_exit "Errore creazione genesis block"

if [ ! -f "channel-artifacts/maintenancech.block" ]; then
    error_exit "Genesis block non creato"
fi

echo -e "${GREEN}[OK] Genesis block creato${NC}"
sleep 1

# ============================================
# STEP 5: JOIN ORDERER AL CANALE
# ============================================
echo -e "${YELLOW}[5/9] Join orderer al canale...${NC}"

ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

osnadmin channel join \
    --channelID maintenancech \
    --config-block ./channel-artifacts/maintenancech.block \
    -o localhost:7053 \
    --ca-file "$ORDERER_CA" \
    --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" \
    --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" || error_exit "Errore join orderer al canale"

echo -e "${GREEN}[OK] Orderer joinato al canale${NC}"
sleep 2

# ============================================
# STEP 6: JOIN PEER OWNER AL CANALE
# ============================================
echo -e "${YELLOW}[6/9] Join peer Owner al canale...${NC}"

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

[ ! -f "$CORE_PEER_TLS_ROOTCERT_FILE" ] && error_exit "Owner TLS cert non trovato"
[ ! -d "$CORE_PEER_MSPCONFIGPATH" ] && error_exit "Owner MSP path non trovato"

peer channel join -b ./channel-artifacts/maintenancech.block || error_exit "Errore join peer Owner"

peer channel list

echo -e "${GREEN}[OK] Peer Owner joinato${NC}"
sleep 1

# ============================================
# STEP 7: JOIN PEER SERVICE AL CANALE
# ============================================
echo -e "${YELLOW}[7/9] Join peer Service al canale...${NC}"

export CORE_PEER_LOCALMSPID="ServiceMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/service.example.com/peers/peer0.service.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/service.example.com/users/Admin@service.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

[ ! -f "$CORE_PEER_TLS_ROOTCERT_FILE" ] && error_exit "Service TLS cert non trovato"
[ ! -d "$CORE_PEER_MSPCONFIGPATH" ] && error_exit "Service MSP path non trovato"

peer channel join -b ./channel-artifacts/maintenancech.block || error_exit "Errore join peer Service"

peer channel list

echo -e "${GREEN}[OK] Peer Service joinato${NC}"
sleep 1

# ============================================
# STEP 8: DEPLOY CHAINCODE
# ============================================
echo -e "${YELLOW}[8/9] Deploy chaincode...${NC}"

# Verifica chaincode esiste
[ ! -f "$CHAINCODE_DIR/maintenance.go" ] && error_exit "Chaincode maintenance.go non trovato"
[ ! -f "$CHAINCODE_DIR/go.mod" ] && error_exit "Chaincode go.mod non trovato"

# Vai alla directory chaincode
cd "$CHAINCODE_DIR"

# Rimuovi vecchi package e vendor
rm -f maintenance.tar.gz
rm -rf vendor/

# FIX CRITICO: Imposta FABRIC_CFG_PATH a NETWORK_DIR prima di eseguire peer package
# Questo risolve il problema "core.yaml not found"
echo "Packaging chaincode..."
FABRIC_CFG_PATH="$NETWORK_DIR" peer lifecycle chaincode package maintenance.tar.gz \
    --path . \
    --lang golang \
    --label maintenance_1.0 || error_exit "Errore package chaincode"

# Verifica package creato
if [ ! -f "maintenance.tar.gz" ]; then
    error_exit "Package chaincode non creato"
fi

echo -e "${GREEN}[OK] Package creato: maintenance.tar.gz${NC}"

# Torna a network directory
cd "$NETWORK_DIR"

# Install su OwnerMSP
echo "Install su peer Owner..."
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install "$CHAINCODE_DIR/maintenance.tar.gz" || error_exit "Errore install chaincode su Owner"

# Salva package ID automaticamente con jq
export PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq -r '.installed_chaincodes[0].package_id')

if [ -z "$PACKAGE_ID" ] || [ "$PACKAGE_ID" = "null" ]; then
    error_exit "Package ID non trovato"
fi

echo -e "${GREEN}[OK] Package ID: $PACKAGE_ID${NC}"

# Install su ServiceMSP
echo "Install su peer Service..."
export CORE_PEER_LOCALMSPID="ServiceMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/service.example.com/peers/peer0.service.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/service.example.com/users/Admin@service.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install "$CHAINCODE_DIR/maintenance.tar.gz" || error_exit "Errore install chaincode su Service"

# Approve for OwnerMSP
echo "Approve per Owner..."
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" \
    --channelID maintenancech \
    --name maintenance \
    --version 1.0 \
    --package-id "$PACKAGE_ID" \
    --sequence 1 || error_exit "Errore approve Owner"

# Approve for ServiceMSP
echo "Approve per Service..."
export CORE_PEER_LOCALMSPID="ServiceMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/service.example.com/peers/peer0.service.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/service.example.com/users/Admin@service.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" \
    --channelID maintenancech \
    --name maintenance \
    --version 1.0 \
    --package-id "$PACKAGE_ID" \
    --sequence 1 || error_exit "Errore approve Service"

# Check commit readiness
echo "Verifica commit readiness..."
peer lifecycle chaincode checkcommitreadiness \
    --channelID maintenancech \
    --name maintenance \
    --version 1.0 \
    --sequence 1 \
    --output json

# Commit chaincode
echo "Commit chaincode..."
peer lifecycle chaincode commit \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" \
    --channelID maintenancech \
    --name maintenance \
    --version 1.0 \
    --sequence 1 \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/service.example.com/peers/peer0.service.example.com/tls/ca.crt" || error_exit "Errore commit chaincode"

echo -e "${GREEN}[OK] Chaincode deployed${NC}"
sleep 2

# ============================================
# STEP 9: INIZIALIZZAZIONE LEDGER
# ============================================
echo -e "${YELLOW}[9/9] Inizializzazione ledger...${NC}"

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls \
    --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" \
    -C maintenancech \
    -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/service.example.com/peers/peer0.service.example.com/tls/ca.crt" \
    -c '{"function":"InitLedger","Args":[]}' || error_exit "Errore inizializzazione ledger"

echo -e "${GREEN}[OK] Ledger inizializzato${NC}"
sleep 2

# ============================================
# RIEPILOGO FINALE
# ============================================
echo -e "${CYAN}"
echo "========================================"
echo "  SETUP COMPLETATO CON SUCCESSO"
echo "========================================"
echo -e "${NC}"

echo -e "${GREEN}Container attivi:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${GREEN}Canale creato:${NC} maintenancech"
echo -e "${GREEN}Chaincode deployed:${NC} maintenance v1.0"
echo -e "${GREEN}Package ID:${NC} $PACKAGE_ID"
echo -e "${GREEN}Macchine iniziali:${NC} 2 (MACH001, MACH002)"

echo ""
echo -e "${GREEN}Tutto pronto per la demo!${NC}"
echo ""