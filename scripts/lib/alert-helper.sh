#!/bin/bash

# ============================================
# ALERT HELPER - Funzione centralizzata
# ============================================
# Uso: create_alert <MACHINE_ID> <MACHINE_NAME> <ALERT_TYPE> <MESSAGE>
# ============================================

create_alert() {
    local MACHINE_ID="$1"
    local MACHINE_NAME="$2"
    local ALERT_TYPE="$3"
    local MESSAGE="$4"
    
    # Validazione parametri
    if [ -z "$MACHINE_ID" ] || [ -z "$MACHINE_NAME" ] || [ -z "$ALERT_TYPE" ] || [ -z "$MESSAGE" ]; then
        echo "ERRORE: Parametri mancanti in create_alert"
        echo "Uso: create_alert <MACHINE_ID> <MACHINE_NAME> <ALERT_TYPE> <MESSAGE>"
        return 1
    fi
    
    # Path
    local BASE_DIR="$HOME/fabric-projects/fabric-maintenance-network"
    local NETWORK_DIR="$BASE_DIR/network"
    local SCRIPTS_DIR="$BASE_DIR/scripts"
    local LOG_DIR="$BASE_DIR/logs"
    local ALERT_LOG="$LOG_DIR/maintenance-alerts.log"
    
    # Crea directory log se non esiste
    mkdir -p "$LOG_DIR"
    
    # Timestamp
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # ============================================
    # 1. REGISTRA SU BLOCKCHAIN
    # ============================================
    
    # Setup ambiente (se non gia' settato)
    if [ -z "$ORDERER_CA" ]; then
        export CORE_PEER_TLS_ENABLED=true
        export CORE_PEER_LOCALMSPID="OwnerMSP"
        export CORE_PEER_TLS_ROOTCERT_FILE=$NETWORK_DIR/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=$NETWORK_DIR/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
        export CORE_PEER_ADDRESS=localhost:7051
        export ORDERER_CA=$NETWORK_DIR/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    fi
    
    # Salva directory corrente
    local ORIGINAL_DIR=$(pwd)
    cd "$NETWORK_DIR"
    
    # Crea alert su blockchain
    local BLOCKCHAIN_RESULT=$(peer chaincode invoke \
        -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile "$ORDERER_CA" \
        -C maintenancech -n maintenance \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles $NETWORK_DIR/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles $NETWORK_DIR/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt \
        --peerAddresses localhost:11051 \
        --tlsRootCertFiles $NETWORK_DIR/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt \
        -c "{\"function\":\"CreateAlert\",\"Args\":[\"$MACHINE_ID\",\"$MACHINE_NAME\",\"$ALERT_TYPE\",\"$MESSAGE\"]}" 2>&1)
        
    # Ritorna alla directory originale
    cd "$ORIGINAL_DIR"
    
    local BLOCKCHAIN_STATUS=$?
    
    if [ $BLOCKCHAIN_STATUS -ne 0 ]; then
        echo "ERRORE: Creazione alert blockchain fallita per $MACHINE_ID"
        echo "$BLOCKCHAIN_RESULT"
        return 1
    fi
    
    # ============================================
    # 2. INVIA EMAIL
    # ============================================
    
    # Determina priorita' e oggetto
    local EMAIL_SUBJECT
    local EMAIL_PRIORITY
    
    if [ "$ALERT_TYPE" = "guasto_segnalato" ]; then
        EMAIL_SUBJECT="[BLOCKCHAIN] GUASTO RILEVATO - $MACHINE_NAME"
        EMAIL_PRIORITY="URGENTE"
    elif [ "$ALERT_TYPE" = "manutenzione_richiesta" ]; then
        EMAIL_SUBJECT="[BLOCKCHAIN] Manutenzione richiesta - $MACHINE_NAME"
        EMAIL_PRIORITY="NORMALE"
    else
        EMAIL_SUBJECT="[BLOCKCHAIN] Segnalazione - $MACHINE_NAME"
        EMAIL_PRIORITY="INFO"
    fi
    
    # Corpo email
    local EMAIL_BODY="ALERT SISTEMA BLOCKCHAIN
Priorita: $EMAIL_PRIORITY
Data: $(date '+%Y-%m-%d %H:%M:%S')

Macchina: $MACHINE_NAME ($MACHINE_ID)
Tipo alert: $ALERT_TYPE
Messaggio: $MESSAGE

Azione richiesta:
$(if [ "$ALERT_TYPE" = "guasto_segnalato" ]; then
    echo "  - Intervento straordinario urgente"
elif [ "$ALERT_TYPE" = "manutenzione_richiesta" ]; then
    echo "  - Pianificare manutenzione ordinaria"
else
    echo "  - Verificare stato macchina"
fi)

Sistema di monitoraggio blockchain
Laboratorio Industria 4.0"
    
    # Invia email in background
    if [ -f "$SCRIPTS_DIR/lib/send-email-alert.sh" ]; then
        "$SCRIPTS_DIR/lib/send-email-alert.sh" "$EMAIL_SUBJECT" "$EMAIL_BODY" &
    fi
    
    # Scrittura su log
    echo "[$TIMESTAMP] ALERT: $MESSAGE" >> "$ALERT_LOG"

    echo "Alert creato con successo"
        
    return 0
}

# Esporta la funzione
export -f create_alert