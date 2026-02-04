#!/bin/bash

# ============================================
# DAILY MAINTENANCE CHECK
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

# Carica alert helper
source "$SCRIPTS_DIR/lib/alert-helper.sh"

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE=$(date '+%Y-%m-%d')

# ============================================
# CONFIGURAZIONE
# ============================================
DAILY_HOURS="${1:-8}"

echo -e "${CYAN}========================================"
echo "  AGGIORNAMENTO AUTOMATICO ORE DI LAVORO"
echo "  Data: $DATE"
echo "========================================"
echo -e "${NC}"

# Vai a directory network
cd "$NETWORK_DIR"

# ============================================
# SETUP AMBIENTE
# ============================================
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$NETWORK_DIR/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$NETWORK_DIR/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
export ORDERER_CA=$NETWORK_DIR/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# ============================================
# RECUPERO DI TUTTE LE MACCHINE
# ============================================
echo -e "${BLUE}Recupero lista macchine...${NC}"

MACHINES=$(peer chaincode query \
    -C maintenancech \
    -n maintenance \
    -c '{"function":"GetAllMachines","Args":[]}' 2>/dev/null)

if [ $? -ne 0 ]; then
    echo -e "${RED}[ERRORE] Impossibile recuperare lista macchine${NC}"
    exit 1
fi

NUM_MACHINES=$(echo "$MACHINES" | jq 'length')
echo -e "${YELLOW}Trovate $NUM_MACHINES macchine${NC}"
echo ""

# ============================================
# ELABORAZIONE DI OGNI MACCHINA
# ============================================
ALERTS_COUNT=0

for i in $(seq 0 $((NUM_MACHINES - 1))); do
    MACHINE=$(echo "$MACHINES" | jq ".[$i]")
    MACHINE_ID=$(echo "$MACHINE" | jq -r '.id')
    MACHINE_NAME=$(echo "$MACHINE" | jq -r '.name')
    STATUS=$(echo "$MACHINE" | jq -r '.status')
    HOURS_BEFORE=$(echo "$MACHINE" | jq -r '.operatingHours')
    NEXT_MAINTENANCE=$(echo "$MACHINE" | jq -r '.nextMaintenance')
    
    echo -e "${BLUE}Aggiornamento macchina: $MACHINE_ID - $MACHINE_NAME${NC}"
    echo -e "  Stato attuale:     $STATUS"
    echo -e "  Ore attuali:       $HOURS_BEFORE"
    
    # ============================================
    # Salta macchine guaste e crea alert
    # ============================================
    if [ "$STATUS" = "guasto" ]; then
        echo -e "${YELLOW}  Macchina in guasto, nessun aggiornamento ore${NC}"
        
        ALERT_MSG="Macchina $MACHINE_NAME in stato GUASTO - richiede intervento straordinario"
        
        create_alert "$MACHINE_ID" "$MACHINE_NAME" "guasto_segnalato" "$ALERT_MSG" > /dev/null 2>&1
        
        echo -e "${RED}  [ALERT] Segnalazione inviata${NC}"
        ALERTS_COUNT=$((ALERTS_COUNT + 1))
        echo ""
        continue
    fi
    
    # ============================================
    # Aggiorna ore di lavoro
    # ============================================
    echo "  Aggiornamento ore: +$DAILY_HOURS ore"
    
    RESULT=$(peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile "$ORDERER_CA" \
        -C maintenancech -n maintenance \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles $NETWORK_DIR/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt \
        -c "{\"function\":\"UpdateOperatingHours\",\"Args\":[\"$MACHINE_ID\",\"$DAILY_HOURS\"]}" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  Ore aggiornate con successo${NC}"
        
        # Ore dopo aggiornamento
        HOURS_AFTER=$((HOURS_BEFORE + DAILY_HOURS))
        
        # ============================================
        # Verifica se serve manutenzione e crea alert
        # ============================================
        if [ $HOURS_AFTER -ge $NEXT_MAINTENANCE ]; then
            echo -e "  Ore aggiornate:    ${CYAN}$HOURS_AFTER${NC} >= Prossima manutenzione: ${CYAN}$NEXT_MAINTENANCE${NC}"
            echo -e "${RED}  [ALERT] Manutenzione richiesta${NC}"
            
            ALERT_MSG="Macchina $MACHINE_NAME ha raggiunto $HOURS_AFTER ore - Manutenzione ordinaria richiesta"
            
            create_alert "$MACHINE_ID" "$MACHINE_NAME" "manutenzione_richiesta" "$ALERT_MSG" > /dev/null 2>&1
            
            ALERTS_COUNT=$((ALERTS_COUNT + 1))
        else
            REMAINING=$((NEXT_MAINTENANCE - HOURS_AFTER))
            echo -e "  Ore aggiornate:    ${CYAN}$HOURS_AFTER${NC}"
            echo -e "  Manutenzione tra:  ${CYAN}$REMAINING${NC} ore"
        fi
    else
        echo -e "${RED}  [ERRORE] Aggiornamento fallito${NC}"
    fi
    echo ""
    sleep 2
done

echo ""
echo -e "${GREEN}Aggiornamento stato macchine completato alle $(date '+%H:%M:%S')${NC}"
echo ""