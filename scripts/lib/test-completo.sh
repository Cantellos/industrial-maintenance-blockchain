#!/bin/bash

# ============================================
# TEST CONTROLLI ACCESSO
# ============================================
# Verifica che le policy di accesso funzionino correttamente
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

cd ~/fabric-projects/fabric-maintenance-network/network

export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Contatori
PASSED=0
FAILED=0

echo -e "${CYAN}"
echo "========================================"
echo "  TEST CONTROLLI DI ACCESSO"
echo "========================================"
echo -e "${NC}"
echo ""

# ============================================
# FUNZIONI HELPER
# ============================================

test_success() {
    local TEST_NAME="$1"
    echo -e "${GREEN}PASS${NC} - $TEST_NAME"
    PASSED=$((PASSED + 1))
}

test_fail() {
    local TEST_NAME="$1"
    echo -e "${RED}FAIL${NC} - $TEST_NAME"
    FAILED=$((FAILED + 1))
}

test_expected_fail() {
    local TEST_NAME="$1"
    echo -e "${GREEN}PASS${NC} - $TEST_NAME ${YELLOW}(fallimento atteso)${NC}"
    PASSED=$((PASSED + 1))
}

# ============================================
# TEST 1: OwnerMSP registra macchina
# ============================================
echo -e "${BLUE}[TEST 1] OwnerMSP registra macchina MACH_TEST01${NC}"

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    -c '{"function":"RegisterMachine","Args":["MACH_TEST01","Test Machine 01","Test Model","0","funzionante","[]"]}' 2>&1)

if echo "$RESULT" | grep -q "registrata con successo"; then
    test_success "OwnerMSP puo' registrare macchine"
else
    test_fail "OwnerMSP puo' registrare macchine"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 2: OrdinaryMSP prova a registrare (DEVE FALLIRE)
# ============================================
echo -e "${BLUE}[TEST 2] OrdinaryMSP prova a registrare macchina (deve fallire)${NC}"

export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"RegisterMachine","Args":["MACH_TEST02","Test","Test","0","funzionante","[]"]}' 2>&1 || true)

if echo "$RESULT" | grep -q "Accesso negato" || echo "$RESULT" | grep -q "solo OwnerMSP"; then
    test_expected_fail "OrdinaryMSP correttamente bloccato dalla registrazione"
else
    test_fail "OrdinaryMSP NON dovrebbe poter registrare macchine"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 3: ExtraordinaryMSP prova a registrare (DEVE FALLIRE)
# ============================================
echo -e "${BLUE}[TEST 3] ExtraordinaryMSP prova a registrare macchina (deve fallire)${NC}"

export CORE_PEER_LOCALMSPID="ExtraordinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/extraordinary.example.com/users/Admin@extraordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:11051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt" \
    -c '{"function":"RegisterMachine","Args":["MACH_TEST03","Test","Test","0","funzionante","[]"]}' 2>&1 || true)

if echo "$RESULT" | grep -q "Accesso negato" || echo "$RESULT" | grep -q "solo OwnerMSP"; then
    test_expected_fail "ExtraordinaryMSP correttamente bloccato dalla registrazione"
else
    test_fail "ExtraordinaryMSP NON dovrebbe poter registrare macchine"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 4: OwnerMSP cambia stato macchina
# ============================================
echo -e "${BLUE}[TEST 4] OwnerMSP cambia stato macchina${NC}"

export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    -c '{"function":"SetMachineStatus","Args":["MACH001","guasto"]}' 2>&1)

if echo "$RESULT" | grep -q "aggiornato"; then
    test_success "OwnerMSP puo' cambiare stato macchina"
else
    test_fail "OwnerMSP puo' cambiare stato macchina"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 5: OrdinaryMSP prova a cambiare stato (DEVE FALLIRE)
# ============================================
echo -e "${BLUE}[TEST 5] OrdinaryMSP prova a cambiare stato (deve fallire)${NC}"

export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"SetMachineStatus","Args":["MACH002","guasto"]}' 2>&1 || true)

if echo "$RESULT" | grep -q "Accesso negato" || echo "$RESULT" | grep -q "solo OwnerMSP"; then
    test_expected_fail "OrdinaryMSP correttamente bloccato dal cambio stato"
else
    test_fail "OrdinaryMSP NON dovrebbe poter cambiare stato"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 6: OrdinaryMSP aggiunge intervento ordinario (CON Owner)
# ============================================
echo -e "${BLUE}[TEST 6] OrdinaryMSP aggiunge intervento ordinario (con Owner)${NC}"

export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","ordinaria","Test ordinary intervention","Tecnico Test"]}' 2>&1)

if echo "$RESULT" | grep -q "aggiunto"; then
    test_success "OrdinaryMSP puo' aggiungere intervento ordinario (con Owner endorsement)"
else
    test_fail "OrdinaryMSP puo' aggiungere intervento ordinario"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 7: ExtraordinaryMSP prova intervento ordinario (DEVE FALLIRE)
# ============================================
echo -e "${BLUE}[TEST 7] ExtraordinaryMSP prova intervento ordinario (deve fallire)${NC}"

export CORE_PEER_LOCALMSPID="ExtraordinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/extraordinary.example.com/users/Admin@extraordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:11051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","ordinaria","Test2","Test2"]}' 2>&1 || true)

if echo "$RESULT" | grep -q "Accesso negato" || echo "$RESULT" | grep -q "solo OrdinaryMSP"; then
    test_expected_fail "ExtraordinaryMSP correttamente bloccato da intervento ordinario"
else
    test_fail "ExtraordinaryMSP NON dovrebbe fare interventi ordinari"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 8: OrdinaryMSP prova intervento ordinario SENZA Owner (DEVE FALLIRE)
# ============================================
echo -e "${BLUE}[TEST 8] OrdinaryMSP prova intervento ordinario SENZA Owner endorsement (deve fallire)${NC}"

export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","ordinaria","Test8","Test8"]}' 2>&1 || true)

VERIFY=$(peer chaincode query -C maintenancech -n maintenance \
    -c '{"function":"ReadMachine","Args":["MACH001"]}' | jq '.interventions | length')

if [ "$VERIFY" == "1" ]; then
    test_expected_fail "Policy correttamente bloccata"
else
    test_fail "Intervento NON dovrebbe essere nel ledger"
fi
echo ""
sleep 2

# ============================================
# TEST 9: ExtraordinaryMSP aggiunge intervento straordinario (CON Owner)
# ============================================
echo -e "${BLUE}[TEST 9] ExtraordinaryMSP aggiunge intervento straordinario (con Owner)${NC}"

export CORE_PEER_LOCALMSPID="ExtraordinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/extraordinary.example.com/users/Admin@extraordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:11051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","straordinaria","Test extraordinary intervention","Tecnico Test"]}' 2>&1)

if echo "$RESULT" | grep -q "aggiunto"; then
    test_success "ExtraordinaryMSP puo' aggiungere intervento straordinario (con Owner)"
else
    test_fail "ExtraordinaryMSP puo' aggiungere intervento straordinario"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 10: OrdinaryMSP prova intervento straordinario (DEVE FALLIRE)
# ============================================
echo -e "${BLUE}[TEST 10] OrdinaryMSP prova intervento straordinario (deve fallire)${NC}"

export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

RESULT=$(peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","straordinaria","Test","Test"]}' 2>&1 || true)

if echo "$RESULT" | grep -q "Accesso negato" || echo "$RESULT" | grep -q "solo ExtraordinaryMSP"; then
    test_expected_fail "OrdinaryMSP correttamente bloccato da intervento straordinario"
else
    test_fail "OrdinaryMSP NON dovrebbe fare interventi straordinari"
    echo "$RESULT"
fi
echo ""
sleep 2

# ============================================
# TEST 11: Verifica stato finale macchina di test
# ============================================
echo -e "${BLUE}[VERIFICA] Stato finale MACH_TEST01${NC}"

export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

MACHINE_DATA=$(peer chaincode query \
    -C maintenancech \
    -n maintenance \
    -c '{"function":"ReadMachine","Args":["MACH_TEST01"]}' 2>&1)

if echo "$MACHINE_DATA" | grep -q "MACH_TEST01"; then
    echo ""
    echo "$MACHINE_DATA" | jq '.'
    echo ""
fi

# ============================================
# RIEPILOGO FINALE
# ============================================
echo ""
echo -e "${CYAN}"
echo "========================================"
echo "  RIEPILOGO TEST"
echo "========================================"
echo -e "${NC}"
echo ""
echo -e "${GREEN}Test passati: $PASSED${NC}"
echo -e "${RED}Test falliti: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ TUTTI I TEST SONO PASSATI${NC}"
    echo -e "${GREEN}I controlli di accesso funzionano correttamente!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ ALCUNI TEST SONO FALLITI${NC}"
    echo -e "${YELLOW}Verifica la configurazione del chaincode e della rete${NC}"
    echo ""
    exit 1
fi