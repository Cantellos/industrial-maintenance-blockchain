#!/bin/bash

# ============================================
# VIEW ALERTS
# ============================================
# Usage: ./view-alerts.sh [MACHINEID|all]
# ============================================

set -e

BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
NC='\033[0m'

cd ~/fabric-projects/fabric-maintenance-network/network

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

MACHINE_ID="${1:-all}"

echo -e "${BLUE}STORICO SEGNALAZIONI BLOCKCHAIN"
echo -e "${NC}"

if [ "$MACHINE_ID" = "all" ]; then
    echo -e "${YELLOW}Visualizzazione di tutte le segnalazioni${NC}"
    echo ""
    
    # Ottieni tutte le macchine
    MACHINES=$(peer chaincode query -C maintenancech -n maintenance \
        -c '{"function":"GetAllMachines","Args":[]}' 2>/dev/null)
    
    if [ -z "$MACHINES" ] || [ "$MACHINES" = "[]" ]; then
        echo -e "${YELLOW}Nessuna macchina trovata${NC}"
        exit 0
    fi
    
    # Conta macchine
    NUM_MACHINES=$(echo "$MACHINES" | jq 'length')
    
    # Usa process substitution invece di pipe
    FOUND_ALERTS=false
    
    # Itera attraverso array usando for invece di while read
    for i in $(seq 0 $((NUM_MACHINES - 1))); do
        MACHINE=$(echo "$MACHINES" | jq ".[$i]")
        ID=$(echo "$MACHINE" | jq -r '.id')
        MACHINE_NAME=$(echo "$MACHINE" | jq -r '.name')
        
        # Query alert per questa macchina
        ALERTS=$(peer chaincode query -C maintenancech -n maintenance \
            -c "{\"function\":\"GetAlertsByMachine\",\"Args\":[\"$ID\"]}" 2>/dev/null)
        
        NUM_ALERTS=$(echo "$ALERTS" | jq 'length' 2>/dev/null || echo "0")
        
        if [ "$NUM_ALERTS" -gt 0 ]; then
            FOUND_ALERTS=true
            
            echo -e "${CYAN}========================================${NC}"
            echo -e "${CYAN}Macchina: $MACHINE_NAME ($ID)${NC}"
            echo -e "${CYAN}========================================${NC}"
            echo -e "${MAGENTA}Segnalazioni: $NUM_ALERTS${NC}"
            echo ""
            
            # Stampa ogni alert
            for j in $(seq 0 $((NUM_ALERTS - 1))); do
                ALERT=$(echo "$ALERTS" | jq ".[$j]")
                TIMESTAMP=$(echo "$ALERT" | jq -r '.timestamp')
                TYPE=$(echo "$ALERT" | jq -r '.alertType')
                MESSAGE=$(echo "$ALERT" | jq -r '.message')
                
                if [ "$TYPE" = "guasto_segnalato" ]; then
                    COLOR=$RED
                    LABEL="[URGENTE]"
                else
                    COLOR=$YELLOW
                    LABEL="[NORMALE]"
                fi
                
                echo -e "${COLOR}$LABEL [$TIMESTAMP]${NC}"
                echo "  Tipo: $TYPE"
                echo "  Messaggio: $MESSAGE"
                echo ""
            done
        fi
    done
    
    if [ "$FOUND_ALERTS" = false ]; then
        echo -e "${GREEN}Nessuna segnalazione presente sulla blockchain${NC}"
        echo ""
    fi
    
else
    # Visualizzazione per singola macchina
    echo -e "${YELLOW}Segnalazioni per macchina: $MACHINE_ID${NC}"
    echo ""
    
    # Verifica che la macchina esista
    MACHINE_DATA=$(peer chaincode query -C maintenancech -n maintenance \
        -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}" 2>&1)
    
    if echo "$MACHINE_DATA" | grep -q "non trovata"; then
        echo -e "${RED}Macchina $MACHINE_ID non trovata${NC}"
        exit 1
    fi
    
    MACHINE_NAME=$(echo "$MACHINE_DATA" | jq -r '.name')
    
    # Query alert
    ALERTS=$(peer chaincode query -C maintenancech -n maintenance \
        -c "{\"function\":\"GetAlertsByMachine\",\"Args\":[\"$MACHINE_ID\"]}" 2>/dev/null)
    
    NUM_ALERTS=$(echo "$ALERTS" | jq 'length' 2>/dev/null || echo "0")
    
    if [ "$NUM_ALERTS" -eq 0 ]; then
        echo -e "${GREEN}Nessuna segnalazione per $MACHINE_NAME ($MACHINE_ID)${NC}"
        echo ""
        exit 0
    fi
    
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Macchina: $MACHINE_NAME ($MACHINE_ID)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${MAGENTA}Trovate $NUM_ALERTS segnalazioni${NC}"
    echo ""
    
    # Stampa alert
    for i in $(seq 0 $((NUM_ALERTS - 1))); do
        ALERT=$(echo "$ALERTS" | jq ".[$i]")
        TIMESTAMP=$(echo "$ALERT" | jq -r '.timestamp')
        TYPE=$(echo "$ALERT" | jq -r '.alertType')
        MESSAGE=$(echo "$ALERT" | jq -r '.message')
        
        if [ "$TYPE" = "guasto_segnalato" ]; then
            COLOR=$RED
            LABEL="[URGENTE]"
        else
            COLOR=$YELLOW
            LABEL="[NORMALE]"
        fi
        
        echo -e "${COLOR}$LABEL [$TIMESTAMP]${NC}"
        echo "  Tipo: $TYPE"
        echo "  Messaggio: $MESSAGE"
        echo ""
    done
fi