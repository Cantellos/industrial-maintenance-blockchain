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
DAILY_HOURS="100"

./maintenance-check.sh "$DAILY_HOURS" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] CONTROLLO COMPLETATO CON SUCCESSO" >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] CONTROLLO FALLITO - VERIFICARE LOG" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
