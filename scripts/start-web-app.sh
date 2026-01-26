#!/bin/bash

# ============================================
# START WEB APPLICATION
# ============================================
# Avvia l'applicazione web per la gestione manutenzione
# ============================================

set -e

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_DIR="$HOME/fabric-projects/fabric-maintenance-network"
WEB_APP_DIR="$BASE_DIR/web-app"

echo -e "${BLUE}AVVIO APPLICAZIONE WEB GESTIONE MANUTENZIONE"
echo -e "${NC}"

# ============================================
# VERIFICA ESISTENZA DIRECTORY WEB-APP
# ============================================
if [ ! -d "$WEB_APP_DIR" ]; then
    echo -e "${RED}[ERRORE] Directory web-app non trovata: $WEB_APP_DIR${NC}"
    exit 1
fi

# ============================================
# VERIFICA NODE.JS INSTALLATO
# ============================================
if ! command -v node &> /dev/null; then
    echo -e "${RED}[ERRORE] Node.js non installato${NC}"
    echo "Installa Node.js con:"
    echo "  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
    echo "  sudo apt-get install -y nodejs"
    exit 1
fi

# ============================================
# VERIFICA DIPENDENZE NPM
# ============================================
if [ ! -d "$WEB_APP_DIR/node_modules" ]; then
    echo -e "${YELLOW}[WARNING] Dipendenze npm non installate${NC}"
    echo -e "${BLUE}Installazione dipendenze in corso...${NC}"
    cd "$WEB_APP_DIR"
    npm install
    echo -e "${GREEN}Dipendenze installate${NC}"
    echo ""
fi

# ============================================
# VERIFICA RETE BLOCKCHAIN ATTIVA
# ============================================
echo -e "${BLUE}Verifica rete blockchain...${NC}"

if ! docker ps | grep -q "peer0.owner.example.com"; then
    echo -e "${YELLOW}[WARNING] La rete blockchain non sembra attiva${NC}"
    echo ""
    echo "Avvia prima la rete con:"
    echo "  cd $BASE_DIR/network"
    echo "  ./setup-completo.sh"
    echo ""
    read -p "Vuoi continuare comunque? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}Rete blockchain attiva${NC}"
fi

echo ""

# ============================================
# AVVIO SERVER WEB
# ============================================
echo -e "${GREEN}Avvio server web...${NC}"
echo ""

# Vai alla directory web-app ed esegui il server
cd "$WEB_APP_DIR"
node server.js
