let allMachines = [];
let currentFilter = 'all';
let interventionCounter = 0;

// ============================================
// TAB MANAGEMENT
// ============================================
function showTab(tabName) {
    // Nascondi tutti i tab
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    
    document.querySelectorAll('.tab-button').forEach(btn => {
        btn.classList.remove('active');
    });
    
    // Mostra il tab selezionato
    if (tabName === 'view') {
        document.getElementById('viewTab').classList.add('active');
        document.querySelectorAll('.tab-button')[0].classList.add('active');
        loadAllMachines();
    } else {
        document.getElementById('registerTab').classList.add('active');
        document.querySelectorAll('.tab-button')[1].classList.add('active');
    }
}

// ============================================
// VISUALIZZAZIONE MACCHINE (codice esistente)
// ============================================
window.addEventListener('load', () => {
    loadAllMachines();
    setupFormHandler();
});

async function loadAllMachines() {
    showLoading(true);
    hideError();
    
    try {
        const response = await fetch('/api/machines');
        if (!response.ok) throw new Error('Errore caricamento macchine');
        
        allMachines = await response.json();
        displayMachines(allMachines);
        
    } catch (error) {
        showError('Errore caricamento dati: ' + error.message);
    } finally {
        showLoading(false);
    }
}

async function searchMachine() {
    const searchInput = document.getElementById('searchInput');
    const machineId = searchInput.value.trim().toUpperCase();
    
    if (!machineId) {
        loadAllMachines();
        return;
    }
    
    showLoading(true);
    hideError();
    
    try {
        const response = await fetch(`/api/machines/${machineId}`);
        if (!response.ok) throw new Error('Macchina non trovata');
        
        const machine = await response.json();
        displayMachines([machine]);
        
    } catch (error) {
        showError(`Macchina ${machineId} non trovata`);
        displayMachines([]);
    } finally {
        showLoading(false);
    }
}

function applyFilter() {
    const filterSelect = document.getElementById('filterType');
    currentFilter = filterSelect.value;
    
    if (allMachines.length > 0) {
        displayMachines(allMachines);
    }
}

function displayMachines(machines) {
    const container = document.getElementById('machinesContainer');
    
    if (machines.length === 0) {
        container.innerHTML = '<div class="no-interventions">Nessuna macchina trovata</div>';
        return;
    }
    
    container.innerHTML = machines.map(machine => createMachineCard(machine)).join('');
}

function createMachineCard(machine) {
    const interventions = machine.interventions || [];
    const filteredInterventions = filterInterventions(interventions);
    
    return `
        <div class="machine-card">
            <div class="machine-header">
                <div>
                    <div class="machine-title">${machine.id}</div>
                    <div style="color: #666; margin-top: 5px;">${machine.name} - ${machine.model}</div>
                </div>
                <div class="status-badge status-${machine.status}">
                    ${machine.status.toUpperCase()}
                </div>
            </div>
            
            <div class="machine-details">
                <div class="detail-item">
                    <div class="detail-label">Ore Operative</div>
                    <div class="detail-value">${machine.operatingHours} ore</div>
                </div>
                <div class="detail-item">
                    <div class="detail-label">Proprietario</div>
                    <div class="detail-value">${machine.owner}</div>
                </div>
                <div class="detail-item">
                    <div class="detail-label">Prossima Manutenzione</div>
                    <div class="detail-value">${machine.nextMaintenance} ore</div>
                </div>
                <div class="detail-item">
                    <div class="detail-label">Ultimo Aggiornamento</div>
                    <div class="detail-value">${formatDate(machine.lastUpdate)}</div>
                </div>
            </div>
            
            <div class="interventions-section">
                <div class="interventions-title">
                    Interventi di Manutenzione 
                    ${currentFilter !== 'all' ? `(${currentFilter})` : ''}
                    (${filteredInterventions.length})
                </div>
                ${filteredInterventions.length > 0 
                    ? filteredInterventions.map(intervention => createInterventionCard(intervention)).join('')
                    : '<div class="no-interventions">Nessun intervento registrato</div>'
                }
            </div>
        </div>
    `;
}

function createInterventionCard(intervention) {
    return `
        <div class="intervention-card ${intervention.type}">
            <div class="intervention-header">
                <span class="intervention-type type-${intervention.type}">
                    ${intervention.type}
                </span>
                <span class="intervention-date">
                    ${formatDate(intervention.date)}
                </span>
            </div>
            <div class="intervention-details">
                <strong>Descrizione:</strong> ${intervention.description}<br>
                <strong>Tecnico:</strong> ${intervention.technician}<br>
            </div>
        </div>
    `;
}

function filterInterventions(interventions) {
    if (!interventions || !Array.isArray(interventions)) {
        return [];
    }
    
    if (currentFilter === 'all') {
        return interventions;
    }
    return interventions.filter(i => i.type === currentFilter);
}

function formatDate(isoString) {
    const date = new Date(isoString);
    return date.toLocaleString('it-IT', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'block' : 'none';
}

function showError(message) {
    const errorDiv = document.getElementById('error');
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
}

function hideError() {
    document.getElementById('error').style.display = 'none';
}

document.getElementById('searchInput').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        searchMachine();
    }
});

// ============================================
// REGISTRAZIONE NUOVA MACCHINA
// ============================================
function setupFormHandler() {
    const form = document.getElementById('registerForm');
    form.addEventListener('submit', handleRegisterSubmit);
}

async function handleRegisterSubmit(e) {
    e.preventDefault();
    
    // Nascondi messaggi precedenti
    document.getElementById('registerError').style.display = 'none';
    document.getElementById('registerSuccess').style.display = 'none';
    document.getElementById('registerLoading').style.display = 'block';
    
    try {
        // Raccogli dati dal form
        const machineData = {
            id: document.getElementById('machineId').value.trim().toUpperCase(),
            name: document.getElementById('machineName').value.trim(),
            model: document.getElementById('machineModel').value.trim(),
            operatingHours: parseInt(document.getElementById('operatingHours').value) || 0,
            status: document.getElementById('machineStatus').value,
            interventions: collectInterventions()
        };
        
        // Invia richiesta
        const response = await fetch('/api/machines', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(machineData)
        });
        
        const result = await response.json();
        
        if (!response.ok) {
            throw new Error(result.error || 'Errore registrazione macchina');
        }
        
        // Mostra successo
        showRegisterSuccess(`Macchina ${machineData.id} registrata con successo sulla blockchain!`);
        
        // Reset form
        resetForm();
        
        // Ricarica lista macchine
        await loadAllMachines();
        
    } catch (error) {
        showRegisterError(error.message);
    } finally {
        document.getElementById('registerLoading').style.display = 'none';
    }
}

function collectInterventions() {
    const interventions = [];
    const container = document.getElementById('interventionsContainer');
    const items = container.querySelectorAll('.intervention-item');
    
    items.forEach(item => {
        const intervention = {
            date: item.querySelector('.intervention-date-input').value || new Date().toISOString(),
            type: item.querySelector('.intervention-type-select').value,
            description: item.querySelector('.intervention-description').value.trim(),
            technician: item.querySelector('.intervention-technician').value.trim(),
        };
        
        // Aggiungi solo se ha almeno descrizione o tecnico
        if (intervention.description || intervention.technician) {
            interventions.push(intervention);
        }
    });
    
    return interventions;
}

function addInterventionField() {
    interventionCounter++;
    const container = document.getElementById('interventionsContainer');
    
    const interventionHTML = `
        <div class="intervention-item" id="intervention-${interventionCounter}">
            <div class="intervention-item-header">
                <h4>Intervento #${interventionCounter}</h4>
                <button type="button" class="btn-remove" onclick="removeIntervention(${interventionCounter})">Rimuovi</button>
            </div>
            
            <div class="intervention-grid">
                <div class="form-group">
                    <label>Data</label>
                    <input type="datetime-local" class="intervention-date-input" value="${getCurrentDateTime()}">
                </div>
                
                <div class="form-group">
                    <label>Tipo</label>
                    <select class="intervention-type-select">
                        <option value="ordinaria">Ordinaria</option>
                        <option value="straordinaria">Straordinaria</option>
                    </select>
                </div>
            </div>
            
            <div class="form-group">
                <label>Descrizione</label>
                <input type="text" class="intervention-description" placeholder="es. Cambio olio lubrificante">
            </div>
            
            <div class="form-group">
                <label>Tecnico</label>
                <input type="text" class="intervention-technician" placeholder="es. Mario Rossi">
            </div>
        </div>
    `;
    
    container.insertAdjacentHTML('beforeend', interventionHTML);
}

function removeIntervention(id) {
    const item = document.getElementById(`intervention-${id}`);
    if (item) {
        item.remove();
    }
}

function getCurrentDateTime() {
    const now = new Date();
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
    return now.toISOString().slice(0, 16);
}

function resetForm() {
    document.getElementById('registerForm').reset();
    document.getElementById('interventionsContainer').innerHTML = '';
    interventionCounter = 0;
    document.getElementById('registerError').style.display = 'none';
    document.getElementById('registerSuccess').style.display = 'none';
}

function showRegisterSuccess(message) {
    const successDiv = document.getElementById('registerSuccess');
    successDiv.textContent = message;
    successDiv.style.display = 'block';
    
    // Scroll verso il messaggio
    successDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function showRegisterError(message) {
    const errorDiv = document.getElementById('registerError');
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
    
    // Scroll verso il messaggio
    errorDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}