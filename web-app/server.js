const express = require('express');
const path = require('path');
const { getContract } = require('./fabric-connection');

const app = express();
const PORT = 3000;

// Funzione per sanitizzare i dati delle macchine
function sanitizeMachine(machine) {
    return {
        ...machine,
        interventions: Array.isArray(machine.interventions) ? machine.interventions : []
    };
}

// Serve file statici dalla cartella public
app.use(express.static('public'));
app.use(express.json());

// ============================================
// API GET: Recupera tutte le macchine
// ============================================
app.get('/api/machines', async (req, res) => {
    try {
        const contract = await getContract();
        const result = await contract.evaluateTransaction('GetAllMachines');
        const machines = JSON.parse(result.toString());
        
        const sanitizedMachines = machines.map(sanitizeMachine);
        
        res.json(sanitizedMachines);
    } catch (error) {
        console.error('Errore recupero macchine:', error);
        res.status(500).json({ error: 'Errore recupero macchine' });
    }
});

// ============================================
// API GET: Recupera una singola macchina
// ============================================
app.get('/api/machines/:id', async (req, res) => {
    try {
        const contract = await getContract();
        const result = await contract.evaluateTransaction('ReadMachine', req.params.id);
        const machine = JSON.parse(result.toString());
        
        const sanitizedMachine = sanitizeMachine(machine);
        
        res.json(sanitizedMachine);
    } catch (error) {
        console.error('Errore recupero macchina:', error);
        res.status(404).json({ error: 'Macchina non trovata' });
    }
});

// ============================================
// API POST: Registra una nuova macchina
// ============================================
app.post('/api/machines', async (req, res) => {
    try {
        const { id, name, model, operatingHours, status, interventions } = req.body;
        
        // Validazione input
        if (!id || !name || !model) {
            return res.status(400).json({ 
                error: 'Campi obbligatori mancanti: id, name, model' 
            });
        }
        
        // Validazione ID formato
        if (!/^[A-Z0-9]+$/.test(id)) {
            return res.status(400).json({ 
                error: 'ID non valido. Usa solo lettere maiuscole e numeri (es. MACH003)' 
            });
        }
        
        // Validazione stato
        if (status && status !== 'funzionante' && status !== 'guasto') {
            return res.status(400).json({ 
                error: 'Status deve essere "funzionante" o "guasto"' 
            });
        }
        
        // Prepara argomenti
        const args = [
            id,
            name,
            model,
            operatingHours ? operatingHours.toString() : '0',
            status || 'funzionante'
        ];
        
        // Aggiungi interventi se presenti
        if (interventions && Array.isArray(interventions) && interventions.length > 0) {
            args.push(JSON.stringify(interventions));
        } else {
            args.push('[]');
        }
        
        // Invoca chaincode
        const contract = await getContract();
        const result = await contract.submitTransaction('RegisterMachine', ...args);
        
        console.log(`Macchina ${id} registrata con successo`);
        
        // Recupera la macchina appena creata per conferma
        const newMachineResult = await contract.evaluateTransaction('ReadMachine', id);
        const newMachine = JSON.parse(newMachineResult.toString());
        
        res.status(201).json({
            success: true,
            message: `Macchina ${id} registrata con successo`,
            machine: sanitizeMachine(newMachine)
        });
        
    } catch (error) {
        console.error('Errore registrazione macchina:', error);
        
        // Gestisci errori specifici dal chaincode
        if (error.message.includes('già esistente')) {
            return res.status(409).json({ 
                error: 'Macchina già esistente con questo ID' 
            });
        }
        
        res.status(500).json({ 
            error: 'Errore registrazione macchina: ' + error.message 
        });
    }
});

app.listen(PORT, () => {
    console.log(`Server avviato su http://localhost:${PORT}`);
    console.log('Premi Ctrl+C per terminare');
});