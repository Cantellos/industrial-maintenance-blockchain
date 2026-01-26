const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');

const CHANNEL_NAME = 'maintenancech';
const CHAINCODE_NAME = 'maintenance';
const MSP_ID = 'OwnerMSP';

async function getContract() {
    try {
        // Path ai certificati
        const networkDir = path.resolve(__dirname, '../network');
        const ccpPath = path.join(networkDir, 'connection-owner.json');
        
        // Crea connection profile completo con entrambi i peer
        const ccp = {
            "name": "maintenance-network",
            "version": "1.0.0",
            "client": {
                "organization": "Owner",
                "connection": {
                    "timeout": {
                        "peer": { "endorser": "300" },
                        "orderer": "300"
                    }
                }
            },
            "organizations": {
                "Owner": {
                    "mspid": "OwnerMSP",
                    "peers": ["peer0.owner.example.com"],
                    "certificateAuthorities": ["ca.owner.example.com"]
                },
                "Service": {
                    "mspid": "ServiceMSP",
                    "peers": ["peer0.service.example.com"],
                    "certificateAuthorities": ["ca.service.example.com"]
                }
            },
            "orderers": {
                "orderer.example.com": {
                    "url": "grpcs://localhost:7050",
                    "tlsCACerts": {
                        "path": path.join(networkDir, 
                            "organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem")
                    },
                    "grpcOptions": {
                        "ssl-target-name-override": "orderer.example.com",
                        "hostnameOverride": "orderer.example.com"
                    }
                }
            },
            "peers": {
                "peer0.owner.example.com": {
                    "url": "grpcs://localhost:7051",
                    "tlsCACerts": {
                        "path": path.join(networkDir, 
                            "organizations/peerOrganizations/owner.example.com/peers/peer0.owner.example.com/tls/ca.crt")
                    },
                    "grpcOptions": {
                        "ssl-target-name-override": "peer0.owner.example.com",
                        "hostnameOverride": "peer0.owner.example.com"
                    }
                },
                "peer0.service.example.com": {
                    "url": "grpcs://localhost:9051",
                    "tlsCACerts": {
                        "path": path.join(networkDir, 
                            "organizations/peerOrganizations/service.example.com/peers/peer0.service.example.com/tls/ca.crt")
                    },
                    "grpcOptions": {
                        "ssl-target-name-override": "peer0.service.example.com",
                        "hostnameOverride": "peer0.service.example.com"
                    }
                }
            },
            "channels": {
                "maintenancech": {
                    "orderers": ["orderer.example.com"],
                    "peers": {
                        "peer0.owner.example.com": {
                            "endorsingPeer": true,
                            "chaincodeQuery": true,
                            "ledgerQuery": true,
                            "eventSource": true
                        },
                        "peer0.service.example.com": {
                            "endorsingPeer": true,
                            "chaincodeQuery": true,
                            "ledgerQuery": true,
                            "eventSource": true
                        }
                    }
                }
            }
        };
        
        // Salva il connection profile (opzionale, per debug)
        fs.writeFileSync(ccpPath, JSON.stringify(ccp, null, 2));
        
        // Crea wallet in memoria
        const wallet = await Wallets.newInMemoryWallet();
        
        // Carica identità admin OwnerMSP
        const credPath = path.join(networkDir, 
            'organizations/peerOrganizations/owner.example.com/users/Admin@owner.example.com/msp');
        
        const certPath = path.join(credPath, 'signcerts');
        const certFiles = fs.readdirSync(certPath);
        const certificate = fs.readFileSync(path.join(certPath, certFiles[0])).toString();
        
        const keyPath = path.join(credPath, 'keystore');
        const keyFiles = fs.readdirSync(keyPath);
        const privateKey = fs.readFileSync(path.join(keyPath, keyFiles[0])).toString();
        
        const identity = {
            credentials: {
                certificate: certificate,
                privateKey: privateKey,
            },
            mspId: MSP_ID,
            type: 'X.509',
        };
        
        await wallet.put('admin', identity);
        
        // Connetti al gateway CON DISCOVERY DISABILITATO
        const gateway = new Gateway();
        await gateway.connect(ccp, {
            wallet,
            identity: 'admin',
            discovery: { 
                enabled: false,  // DISABILITA discovery per evitare errori
                asLocalhost: true 
            }
        });
        
        // Ottieni network e contract
        const network = await gateway.getNetwork(CHANNEL_NAME);
        const contract = network.getContract(CHAINCODE_NAME);
        
        return contract;
        
    } catch (error) {
        console.error('Errore connessione Fabric:', error);
        throw error;
    }
}

module.exports = { getContract };