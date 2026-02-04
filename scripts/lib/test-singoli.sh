# ============================================
# TEST CONTROLLI ACCESSO
# ============================================


# ============================================
# TEST 1: OwnerMSP registra macchina
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    -c '{"function":"RegisterMachine","Args":["MACH_TEST01","Test Machine 01","Test Model","0","funzionante","[]"]}'
# ============================================


# ============================================
# TEST 2: OrdinaryMSP prova a registrare  (FAIL)
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"RegisterMachine","Args":["MACH_TEST02","Test","Test","0","funzionante","[]"]}'
# ============================================


# ============================================
# TEST 3: ExtraordinaryMSP prova a registrare (FAIL)
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="ExtraordinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/extraordinary.example.com/users/Admin@extraordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:11051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt" \
    -c '{"function":"RegisterMachine","Args":["MACH_TEST03","Test","Test","0","funzionante","[]"]}'
# ============================================


# ============================================
# TEST 4: OwnerMSP cambia stato macchina
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OwnerMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    -c '{"function":"SetMachineStatus","Args":["MACH001","guasto"]}'
# ============================================


# ============================================
# TEST 5: OrdinaryMSP prova a cambiare stato (FAIL)
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"SetMachineStatus","Args":["MACH002","guasto"]}'
# ============================================


# ============================================
# TEST 6: OrdinaryMSP aggiunge intervento ordinario (CON Owner)
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","ordinaria","Test ordinary intervention","Tecnico Test"]}'
# ============================================


# ============================================
# TEST 7: ExtraordinaryMSP prova intervento ordinario (FAIL)
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="ExtraordinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/extraordinary.example.com/users/Admin@extraordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:11051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","ordinaria","Test2","Test2"]}'
# ============================================


# ============================================
# TEST 8: OrdinaryMSP prova intervento ordinario SENZA Owner (FAIL)
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","ordinaria","Test8","Test8"]}'

# Non bloccata dal chaincode ma bloccata dall'endorsement policy
VERIFY=$(peer chaincode query -C maintenancech -n maintenance \
    -c '{"function":"ReadMachine","Args":["MACH001"]}' | jq '.interventions | length')

if [ "$VERIFY" == "1" ]; then
    echo "Policy correttamente bloccata"
else
    echo "Intervento NON dovrebbe essere nel ledger"
fi
# ============================================


# ============================================
# TEST 9: ExtraordinaryMSP aggiunge intervento straordinario (CON Owner)
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="ExtraordinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/extraordinary.example.com/users/Admin@extraordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:11051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/extraordinary.example.com/peers/peer0.extraordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","straordinaria","Test extraordinary intervention","Tecnico Test"]}'
# ============================================


# ============================================
# TEST 10: OrdinaryMSP prova intervento straordinario (FAIL)
cd ~/fabric-projects/fabric-maintenance-network/network
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="OrdinaryMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/ordinary.example.com/users/Admin@ordinary.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C maintenancech -n maintenance \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/ordinary.example.com/peers/peer0.ordinary.example.com/tls/ca.crt" \
    -c '{"function":"AddIntervention","Args":["MACH_TEST01","straordinaria","Test","Test"]}'
# ============================================


