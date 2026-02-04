#!/bin/bash

# ============================================
# SCHEDULE MAINTENANCE CHECK - Configurazione Cron
# ============================================
# Uso: ./schedule-maintenance.sh [intervallo] [unita] [ore_giornaliere]
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

# ============================================
# PARAMETRI
# ============================================
INTERVAL="${1:-1}"
UNIT="${2:-days}"
DAILY_HOURS="${3:-8}"

# Percorsi
BASE_DIR="$HOME/fabric-projects/fabric-maintenance-network"
SCRIPTS_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"
CRON_LOG="$LOG_DIR/scheduled-maintenance.log"

# Crea directory log se non esiste
mkdir -p "$LOG_DIR"

echo -e "${CYAN}========================================"
echo "  CONFIGURAZIONE CONTROLLO MANUTENZIONE"
echo "========================================"
echo -e "${NC}"

# ============================================
# CONVERSIONE INTERVALLO IN FORMATO CRON
# ============================================
CRON_SCHEDULE=""

case "$UNIT" in
    seconds|second)
        echo -e "${RED}[ERRORE] Cron non supporta i secondi${NC}"
        echo "Usa 'minutes' per intervalli brevi (minimo 1 minuto)"
        exit 1
        ;;
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
    *)
        echo -e "${RED}[ERRORE] Unita' non valida: $UNIT${NC}"
        echo "Unita' supportate: minutes, hours, days"
        exit 1
        ;;
esac

echo -e "${YELLOW}Configurazione:${NC}"
echo "  Intervallo: $DESCRIPTION"
echo "  Cron:       $CRON_SCHEDULE"
echo "  Ore di lavoro: $DAILY_HOURS"
echo ""

# ============================================
# CREA SCRIPT WRAPPER PER CRON
# ============================================
WRAPPER_SCRIPT="$SCRIPTS_DIR/cron-scheduled-maintenance.sh"

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
SCRIPTS_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/scheduled-maintenance.log"

# Crea directory log
mkdir -p "$LOG_DIR"

echo "========================================" >> "$LOG_FILE"
echo "[$TIMESTAMP] AVVIO CONTROLLO MANUTENZIONE AUTOMATICO" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Debug: logga il PATH
echo "[$TIMESTAMP] PATH: $PATH" >> "$LOG_FILE"
echo "[$TIMESTAMP] Peer command: $(which peer 2>&1)" >> "$LOG_FILE"
echo "[$TIMESTAMP] JQ command: $(which jq 2>&1)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Esegui maintenance-check.sh
cd "$SCRIPTS_DIR"

# Parametro ore giornaliere (default 8)
DAILY_HOURS="DAILY_HOURS_PLACEHOLDER"

./maintenance-check.sh "$DAILY_HOURS" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] CONTROLLO COMPLETATO CON SUCCESSO" >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] CONTROLLO FALLITO - VERIFICARE LOG" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
EOF

# Sostituisci il placeholder con il valore effettivo
sed -i "s/DAILY_HOURS_PLACEHOLDER/$DAILY_HOURS/" "$WRAPPER_SCRIPT"

chmod +x "$WRAPPER_SCRIPT"

echo -e "${GREEN}Script wrapper creato: cron-scheduled-maintenance.sh${NC}"
echo ""

# ============================================
# CONFIGURAZIONE CRONTAB
# ============================================
# Riga da aggiungere al crontab
CRON_JOB="$CRON_SCHEDULE $WRAPPER_SCRIPT"

# Verifica se job esiste gia'
if crontab -l 2>/dev/null | grep -q "cron-scheduled-maintenance.sh.sh"; then
    echo -e "${YELLOW}Job cron esistente trovato${NC}"
    echo ""
    echo -e "${YELLOW}Vuoi sostituirlo? [y/N]${NC}"
    read -r RESPONSE
    
    if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
        # Rimuovi vecchio job
        crontab -l 2>/dev/null | grep -v "cron-scheduled-maintenance.sh" | crontab -
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
echo -e "${GREEN}Configurazione maintenance completata${NC}"
echo ""
echo "  - Log: $CRON_LOG"
echo "  - Per disabilitare i trigger: crontab -e"
echo "  - Per visualizzare i trigger: crontab -l"
echo ""