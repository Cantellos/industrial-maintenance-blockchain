#!/bin/bash

# ============================================
# SCHEDULE INTERVENTION - Configurazione Cron
# ============================================
# Uso: ./schedule-intervention.sh [intervallo] [unita]
# ============================================

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# PARAMETRI
# ============================================
INTERVAL="${1:-2}"
UNIT="${2:-weeks}"

# Percorsi
BASE_DIR="$HOME/fabric-projects/fabric-maintenance-network"
SCRIPTS_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"
CRON_LOG="$LOG_DIR/scheduled-intervention.log"

# Crea directory log se non esiste
mkdir -p "$LOG_DIR"

echo -e "${CYAN}========================================"
echo "  CONFIGURAZIONE MANUTENZIONE PERIODICA"
echo "========================================"
echo -e "${NC}"

# ============================================
# CONVERSIONE INTERVALLO IN FORMATO CRON
# ============================================
CRON_SCHEDULE=""

case "$UNIT" in
    minutes|minute)
        # Ogni N minuti
        CRON_SCHEDULE="*/$INTERVAL * * * *"
        DESCRIPTION="ogni $INTERVAL minuti"
        ;;
    hours|hour)
        # Ogni N ore
        CRON_SCHEDULE="0 */$INTERVAL * * *"
        DESCRIPTION="ogni $INTERVAL ore"
        ;;
    days|day)
        # Ogni N giorni alle 02:00
        if [ "$INTERVAL" -eq 1 ]; then
            CRON_SCHEDULE="0 2 * * *"
            DESCRIPTION="ogni giorno alle 02:00"
        else
            CRON_SCHEDULE="0 2 */$INTERVAL * *"
            DESCRIPTION="ogni $INTERVAL giorni alle 02:00"
        fi
        ;;
    weeks|week)
        # Ogni N settimane (lunedi' alle 02:00)
        if [ "$INTERVAL" -eq 1 ]; then
            CRON_SCHEDULE="0 2 * * 1"
            DESCRIPTION="ogni lunedi' alle 02:00"
        elif [ "$INTERVAL" -eq 2 ]; then
            CRON_SCHEDULE="0 2 1,15 * *"
            DESCRIPTION="ogni 2 settimane (1 e 15 del mese) alle 02:00"
        else
            CRON_SCHEDULE="0 2 1 * *"
            DESCRIPTION="il 1 di ogni mese alle 02:00 (approssimazione di $INTERVAL settimane)"
        fi
        ;;
    *)
        echo -e "${RED}[ERRORE] Unita' non valida: $UNIT${NC}"
        echo "Unita' supportate: minutes, hours, days, weeks"
        exit 1
        ;;
esac

echo -e "${YELLOW}Configurazione:${NC}"
echo "  Intervallo: $DESCRIPTION"
echo "  Cron:       $CRON_SCHEDULE"
echo "  Log:        $CRON_LOG"
echo ""

# ============================================
# CREA SCRIPT WRAPPER PER CRON
# ============================================
WRAPPER_SCRIPT="$SCRIPTS_DIR/cron-scheduled-intervention.sh"

cat > "$WRAPPER_SCRIPT" << 'EOF'
#!/bin/bash

# Setup PATH per cron - Fabric binaries
export PATH="/home/cantellos/fabric-projects/fabric-samples/bin:/usr/bin:/usr/local/bin:$PATH"

# Carica variabili ambiente Fabric
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

# Wrapper per esecuzione da cron

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Paths
BASE_DIR="$HOME/fabric-projects/fabric-maintenance-network"
NETWORK_DIR="$BASE_DIR/network"
SCRIPTS_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/scheduled-intervention.log"

# Crea directory log
mkdir -p "$LOG_DIR"

echo "========================================" >> "$LOG_FILE"
echo "[$TIMESTAMP] AVVIO MANUTENZIONE PROGRAMMATA" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Vai a network directory e setup ambiente (come query-machines.sh)
cd "$NETWORK_DIR"

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Query tutte le macchine (come in query-machines.sh)
echo "[$TIMESTAMP] Recupero lista macchine..." >> "$LOG_FILE"

MACHINES_JSON=$(peer chaincode query -C maintenancech -n maintenance \
    -c '{"function":"GetAllMachines","Args":[]}' 2>&1)

QUERY_STATUS=$?

if [ $QUERY_STATUS -ne 0 ]; then
    echo "[$TIMESTAMP] ERRORE query: $MACHINES_JSON" >> "$LOG_FILE"
    exit 1
fi

# Estrai ID macchine
MACHINE_IDS=$(echo "$MACHINES_JSON" | jq -r '.[].id' 2>&1)

if [ -z "$MACHINE_IDS" ]; then
    echo "[$TIMESTAMP] Nessuna macchina trovata" >> "$LOG_FILE"
    exit 0
fi

echo "[$TIMESTAMP] Macchine trovate: $MACHINE_IDS" >> "$LOG_FILE"

# Esegui manutenzione ordinaria su ogni macchina
cd "$SCRIPTS_DIR"

for MACHINE_ID in $MACHINE_IDS; do
    echo "[$TIMESTAMP] Elaborazione $MACHINE_ID..." >> "$LOG_FILE"
    
    ./add-ordinary-intervention.sh \
        "$MACHINE_ID" \
        "Manutenzione ordinaria programmata automatica - $TIMESTAMP" \
        "Tecnico ServiceMSP - Team Manutenzione" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "[$TIMESTAMP] $MACHINE_ID: OK" >> "$LOG_FILE"
    else
        echo "[$TIMESTAMP] $MACHINE_ID: ERRORE" >> "$LOG_FILE"
    fi
    
    echo "" >> "$LOG_FILE"
done

echo "[$TIMESTAMP] MANUTENZIONE PROGRAMMATA COMPLETATA" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
EOF

chmod +x "$WRAPPER_SCRIPT"

echo -e "${GREEN}Script wrapper creato: $WRAPPER_SCRIPT${NC}"
echo ""

# ============================================
# CONFIGURAZIONE CRONTAB
# ============================================
echo -e "${BLUE}Configurazione crontab...${NC}"

# Riga da aggiungere al crontab
CRON_JOB="$CRON_SCHEDULE $WRAPPER_SCRIPT >> $CRON_LOG 2>&1"

# Verifica se job esiste gia'
if crontab -l 2>/dev/null | grep -q "cron-scheduled-intervention.sh"; then
    echo -e "${YELLOW}Job cron esistente trovato${NC}"
    echo ""
    echo -e "${YELLOW}Vuoi sostituirlo? [y/N]${NC}"
    read -r RESPONSE
    
    if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
        # Rimuovi vecchio job
        crontab -l 2>/dev/null | grep -v "cron-scheduled-intervention.sh" | crontab -
        echo -e "${GREEN}Vecchio job rimosso${NC}"
    else
        echo -e "${YELLOW}Operazione annullata${NC}"
        exit 0
    fi
fi

# Aggiungi nuovo job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo -e "${GREEN}Cron job configurato con successo${NC}"
echo ""

# ============================================
# VERIFICA CONFIGURAZIONE
# ============================================
echo -e "${BLUE}Verifica configurazione${NC}"
echo ""

echo -e "${MAGENTA}Prossime esecuzioni (prossimi 5 trigger):${NC}"
# Mostra prossime 5 esecuzioni
for i in {1..5}; do
    # Calcola prossima esecuzione (approssimativo)
    case "$UNIT" in
        minutes|minute)
            NEXT=$(date -d "+$((i*INTERVAL)) minutes" '+%Y-%m-%d %H:%M')
            ;;
        hours|hour)
            NEXT=$(date -d "+$((i*INTERVAL)) hours" '+%Y-%m-%d %H:%M')
            ;;
        days|day)
            NEXT=$(date -d "+$((i*INTERVAL)) days" '+%Y-%m-%d 02:00')
            ;;
        weeks|week)
            NEXT=$(date -d "+$((i*INTERVAL)) weeks" '+%Y-%m-%d 02:00')
            ;;
    esac
    echo "  $i) $NEXT"
done
echo ""

echo -e "${GREEN}Configurazione intervention completata${NC}"
echo ""
echo "  - Log salvati in: $CRON_LOG"
echo "  - Per disabilitare i trigger: crontab -e"
echo "  - Per visualizzare i trigger: crontab -l"
echo ""