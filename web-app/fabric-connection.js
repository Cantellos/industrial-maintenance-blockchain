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
        
        // Leggi connection profile esistente
        const ccpJSON = fs.readFileSync(ccpPath, 'utf8');
        const ccp = JSON.parse(ccpJSON);
        
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
        
        // Connetti al gateway con discovery disabilitato
        const gateway = new Gateway();
        await gateway.connect(ccp, {
            wallet,
            identity: 'admin',
            discovery: { 
                enabled: false,
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