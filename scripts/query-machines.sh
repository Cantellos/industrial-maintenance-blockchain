#!/bin/bash

# ============================================
# QUERY MACHINES - Visualizzazione stato macchine e interventi
# ============================================
# Uso: ./query-machines.sh [ID|all] [tipo_intervento]
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
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# ============================================
# MACCHINA/E E TIPO MANUTENZIONE CONFIGURABILI
# ============================================
MACHINE_ID="${1:-all}"
FILTER_TYPE="${2:-all}"

# Validazione filtro sul tipo di manutenzione
if [ "$FILTER_TYPE" != "all" ] && [ "$FILTER_TYPE" != "ordinaria" ] && [ "$FILTER_TYPE" != "straordinaria" ]; then
    echo -e "${RED}[ERRORE] Tipo intervento non valido: $FILTER_TYPE${NC}"
    echo "Usa: all | ordinaria | straordinaria"
    exit 1
fi

# ============================================
# FUNZIONE: STAMPA DATI DI UNA MACCHINA
# ============================================
print_machine() {
    local MACHINE_JSON="$1"
    local FILTER="$2"
    
    # Estrai campi
    local ID=$(echo "$MACHINE_JSON" | jq -r '.id')
    local NAME=$(echo "$MACHINE_JSON" | jq -r '.name')
    local MODEL=$(echo "$MACHINE_JSON" | jq -r '.model')
    local HOURS=$(echo "$MACHINE_JSON" | jq -r '.operatingHours')
    local STATUS=$(echo "$MACHINE_JSON" | jq -r '.status')
    local OWNER=$(echo "$MACHINE_JSON" | jq -r '.owner')
    local LAST_UPDATE=$(echo "$MACHINE_JSON" | jq -r '.lastUpdate')
    local NEXT_MAINT=$(echo "$MACHINE_JSON" | jq -r '.nextMaintenance')
    
    # Header macchina
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}MACCHINA: $ID${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "Nome:              $NAME"
    echo -e "Modello:           $MODEL"
    echo -e "Ore operative:     $HOURS"
    
    if [ "$STATUS" = "funzionante" ]; then
        echo -e "Stato:             ${GREEN}$STATUS${NC}"
    else
        echo -e "Stato:             ${RED}$STATUS${NC}"
    fi
    
    echo -e "Proprietario:      $OWNER"
    echo -e "Ultimo aggiornamento: $LAST_UPDATE"
    echo -e "Prossima manutenzione: $NEXT_MAINT ore"
    echo ""
    
    local INTERVENTIONS=$(echo "$MACHINE_JSON" | jq -c '.interventions[]')
    local TOTAL_COUNT=$(echo "$MACHINE_JSON" | jq '.interventions | length')
    
    if [ "$TOTAL_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}Nessun intervento registrato${NC}"
        echo ""
        return
    fi
    
    # Filtra interventi se richiesto
    if [ "$FILTER" != "all" ]; then
        INTERVENTIONS=$(echo "$MACHINE_JSON" | jq -c ".interventions[] | select(.type == \"$FILTER\")")
        local FILTERED_COUNT=$(echo "$INTERVENTIONS" | wc -l)
        
        if [ -z "$INTERVENTIONS" ] || [ "$FILTERED_COUNT" -eq 0 ]; then
            echo -e "${YELLOW}Nessun intervento di tipo '$FILTER'${NC}"
            echo ""
            return
        fi
        
        echo -e "${MAGENTA}INTERVENTI ($FILTER): $FILTERED_COUNT di $TOTAL_COUNT${NC}"
    else
        echo -e "${MAGENTA}INTERVENTI: $TOTAL_COUNT${NC}"
    fi
    
    echo -e "${MAGENTA}----------------------------------------${NC}"
    
    # Stampa interventi
    local INDEX=1
    echo "$INTERVENTIONS" | while read -r intervention; do
        if [ -n "$intervention" ]; then
            local DATE=$(echo "$intervention" | jq -r '.date')
            local TYPE=$(echo "$intervention" | jq -r '.type')
            local DESC=$(echo "$intervention" | jq -r '.description')
            local TECH=$(echo "$intervention" | jq -r '.technician')
            local APPROVED=$(echo "$intervention" | jq -r '.approvedBy')
            
            echo -e "${YELLOW}[$INDEX]${NC}"
            echo "  Data:        $DATE"
            
            # Colora tipo
            if [ "$TYPE" = "ordinaria" ]; then
                echo -e "  Tipo:        ${GREEN}$TYPE${NC}"
            else
                echo -e "  Tipo:        ${RED}$TYPE${NC}"
            fi
            
            echo "  Descrizione: $DESC"
            echo "  Tecnico:     $TECH"
            echo "  Approvato:   $APPROVED"
            echo ""
            
            INDEX=$((INDEX + 1))
        fi
    done
    
    echo ""
}

# ============================================
# QUERY ITERATIVA DI STAMPA SULLE MACCHINE
# ============================================
if [ "$MACHINE_ID" = "all" ]; then
    echo -e "${BLUE}Recupero tutte le macchine...${NC}"
    RESULT=$(peer chaincode query -C maintenancech -n maintenance \
        -c '{"function":"GetAllMachines","Args":[]}')
    
    # Conta macchine
    COUNT=$(echo "$RESULT" | jq '. | length')
    echo -e "${YELLOW}Trovate $COUNT macchine${NC}"
    echo ""
    
    # Processa ogni macchina
    for i in $(seq 0 $((COUNT - 1))); do
        MACHINE=$(echo "$RESULT" | jq ".[$i]")
        print_machine "$MACHINE" "$FILTER_TYPE"
    done
else
    echo -e "${BLUE}Recupero macchina $MACHINE_ID...${NC}"
    RESULT=$(peer chaincode query -C maintenancech -n maintenance \
        -c "{\"function\":\"ReadMachine\",\"Args\":[\"$MACHINE_ID\"]}" 2>&1)
    
    if echo "$RESULT" | grep -q "non trovata"; then
        echo -e "${RED}[ERRORE] Macchina $MACHINE_ID non trovata${NC}"
        exit 1
    fi
    
    print_machine "$RESULT" "$FILTER_TYPE"
fi