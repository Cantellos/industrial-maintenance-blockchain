package main

import (
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-protos-go/peer"
)

type Machine struct {
	ID              string         `json:"id"`
	Name            string         `json:"name"`
	Model           string         `json:"model"`
	OperatingHours  int            `json:"operatingHours"`
	Status          string         `json:"status"`
	Owner           string         `json:"owner"`
	Interventions   []Intervention `json:"interventions"`
	LastUpdate      string         `json:"lastUpdate"`
	NextMaintenance int            `json:"nextMaintenance"`
}

type Intervention struct {
	Date        string `json:"date"`
	Type        string `json:"type"`
	Description string `json:"description"`
	Technician  string `json:"technician"`
	ApprovedBy  string `json:"approvedBy"`
}

type Alert struct {
	ID      string `json:"id"`
	MachineID      string `json:"machineId"`
	MachineName    string `json:"machineName"`
	AlertType      string `json:"alertType"`
	Message        string `json:"message"`
	Timestamp      string `json:"timestamp"`
}

type SmartContract struct{}

func (s *SmartContract) getMSPID(stub shim.ChaincodeStubInterface) (string, error) {
	mspID, err := shim.GetMSPID()
	if err != nil {
		return "", fmt.Errorf("impossibile recuperare MSP ID: %v", err)
	}
	return mspID, nil
}

// Estrae l'MSP ID dal creator usando protobuf
func getCreatorMSPID(creatorBytes []byte) (string, error) {
	if len(creatorBytes) < 2 {
		return "", fmt.Errorf("creator bytes troppo corti")
	}
	
	if creatorBytes[0] != 0x0a {
		return "", fmt.Errorf("formato creator non valido")
	}
	
	mspIDLen := int(creatorBytes[1])
	
	if len(creatorBytes) < 2+mspIDLen {
		return "", fmt.Errorf("creator bytes incompleti")
	}
	
	mspID := string(creatorBytes[2 : 2+mspIDLen])
	
	return mspID, nil
}

func (s *SmartContract) InitLedger(stub shim.ChaincodeStubInterface) peer.Response {
	machines := []Machine{
		{
			ID:              "MACH001",
			Name:            "Tornio CNC",
			Model:           "Haas ST-30",
			OperatingHours:  450,
			Status:          "funzionante",
			Owner:           "OwnerMSP",
			LastUpdate:      time.Now().Format(time.RFC3339),
			NextMaintenance: 550,
			Interventions: []Intervention{
				{
					Date:        "2025-01-10T10:00:00Z",
					Type:        "ordinaria",
					Description: "Cambio olio lubrificante",
					Technician:  "Mario Rossi",
					ApprovedBy:  "OwnerMSP",
				},
			},
		},
		{
			ID:              "MACH002",
			Name:            "Fresatrice CNC",
			Model:           "DMG Mori NVX",
			OperatingHours:  1200,
			Status:          "funzionante",
			Owner:           "OwnerMSP",
			LastUpdate:      time.Now().Format(time.RFC3339),
			NextMaintenance: 1400,
			Interventions: []Intervention{
				{
					Date:        "2025-01-05T14:30:00Z",
					Type:        "ordinaria",
					Description: "Verifica parametri elettrici",
					Technician:  "Luigi Verdi",
					ApprovedBy:  "OwnerMSP",
				},
			},
		},
	}

	for _, machine := range machines {
		machineJSON, err := json.Marshal(machine)
		if err != nil {
			return shim.Error(err.Error())
		}
		err = stub.PutState(machine.ID, machineJSON)
		if err != nil {
			return shim.Error(fmt.Sprintf("Failed to put machine %s: %v", machine.ID, err))
		}
	}

	return shim.Success([]byte("Ledger initialized with 2 machines"))
}

func (s *SmartContract) RegisterMachine(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) < 3 || len(args) > 6 {
		return shim.Error("Numero argomenti errato. Uso: RegisterMachine <id> <name> <model> [operatingHours] [status] [interventionsJSON]")
	}

	creatorBytes, err := stub.GetCreator()
	if err != nil {
		return shim.Error(fmt.Sprintf("Impossibile recuperare creator: %v", err))
	}

	creatorMSPID, err := getCreatorMSPID(creatorBytes)
	if err != nil {
		return shim.Error(fmt.Sprintf("Impossibile estrarre MSP ID: %v", err))
	}

	if creatorMSPID != "OwnerMSP" {
		return shim.Error(fmt.Sprintf("Accesso negato: solo OwnerMSP può registrare macchine (chiamante: %s)", creatorMSPID))
	}

	id := args[0]
	name := args[1]
	model := args[2]

	existingMachineJSON, err := stub.GetState(id)
	if err != nil {
		return shim.Error(fmt.Sprintf("Errore controllo esistenza: %v", err))
	}
	if existingMachineJSON != nil {
		return shim.Error(fmt.Sprintf("Macchina %s già esistente", id))
	}

	// Parametri opzionali
	operatingHours := 0
	status := "funzionante"
	
	if len(args) >= 4 {
		hours, err := strconv.Atoi(args[3])
		if err != nil {
			return shim.Error("Le ore devono essere un numero intero")
		}
		operatingHours = hours
	}
	
	if len(args) >= 5 {
		if args[4] != "funzionante" && args[4] != "guasto" {
			return shim.Error("Status deve essere 'funzionante' o 'guasto'")
		}
		status = args[4]
	}

	interventions := []Intervention{}
	if len(args) >= 6 && args[5] != "" && args[5] != "[]" {
		err := json.Unmarshal([]byte(args[5]), &interventions)
		if err != nil {
			return shim.Error(fmt.Sprintf("Formato interventi non valido: %v", err))
		}
	}

	machine := Machine{
		ID:              id,
		Name:            name,
		Model:           model,
		OperatingHours:  operatingHours,
		Status:          status,
		Owner:           creatorMSPID,
		Interventions:   interventions,
		LastUpdate:      time.Now().Format(time.RFC3339),
		NextMaintenance: operatingHours + 200,
	}

	machineJSON, err := json.Marshal(machine)
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(id, machineJSON)
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success([]byte(fmt.Sprintf("Macchina %s registrata con successo", id)))
}

func (s *SmartContract) UpdateOperatingHours(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 2 {
		return shim.Error("Numero argomenti errato. Uso: UpdateOperatingHours <id> <hours>")
	}

	id := args[0]
	hours, err := strconv.Atoi(args[1])
	if err != nil {
		return shim.Error("Le ore devono essere un numero intero")
	}

	machineJSON, err := stub.GetState(id)
	if err != nil {
		return shim.Error(fmt.Sprintf("Errore recupero macchina: %v", err))
	}
	if machineJSON == nil {
		return shim.Error(fmt.Sprintf("Macchina %s non trovata", id))
	}

	var machine Machine
	err = json.Unmarshal(machineJSON, &machine)
	if err != nil {
		return shim.Error(err.Error())
	}

	machine.OperatingHours += hours
	machine.LastUpdate = time.Now().Format(time.RFC3339)

	alertMessage := ""
	if machine.OperatingHours >= machine.NextMaintenance {
		alertMessage = fmt.Sprintf(" | ALERT: Manutenzione richiesta (ore attuali: %d, prossima manutenzione prevista: %d)",
			machine.OperatingHours, machine.NextMaintenance)
		machine.NextMaintenance += 200
	}

	machineJSON, err = json.Marshal(machine)
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(id, machineJSON)
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success([]byte(fmt.Sprintf("Macchina %s aggiornata: +%d ore (totale: %d)%s", id, hours, machine.OperatingHours, alertMessage)))
}

func (s *SmartContract) CheckMachineStatus(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 1 {
		return shim.Error("Numero argomenti errato. Uso: CheckMachineStatus <id>")
	}

	id := args[0]

	machineJSON, err := stub.GetState(id)
	if err != nil {
		return shim.Error(fmt.Sprintf("Errore recupero macchina: %v", err))
	}
	if machineJSON == nil {
		return shim.Error(fmt.Sprintf("Macchina %s non trovata", id))
	}

	var machine Machine
	err = json.Unmarshal(machineJSON, &machine)
	if err != nil {
		return shim.Error(err.Error())
	}

	statusMessage := fmt.Sprintf("Macchina %s - Stato: %s, Ore: %d, Ultima modifica: %s",
		machine.Name, machine.Status, machine.OperatingHours, machine.LastUpdate)

	return shim.Success([]byte(statusMessage))
}

func (s *SmartContract) SetMachineStatus(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 2 {
		return shim.Error("Numero argomenti errato. Uso: SetMachineStatus <id> <status>")
	}

	id := args[0]
	status := args[1]

	if status != "funzionante" && status != "guasto" {
		return shim.Error("Status deve essere 'funzionante' o 'guasto'")
	}

	machineJSON, err := stub.GetState(id)
	if err != nil {
		return shim.Error(fmt.Sprintf("Errore recupero macchina: %v", err))
	}
	if machineJSON == nil {
		return shim.Error(fmt.Sprintf("Macchina %s non trovata", id))
	}

	var machine Machine
	err = json.Unmarshal(machineJSON, &machine)
	if err != nil {
		return shim.Error(err.Error())
	}

	machine.Status = status
	machine.LastUpdate = time.Now().Format(time.RFC3339)

	machineJSON, err = json.Marshal(machine)
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(id, machineJSON)
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success([]byte(fmt.Sprintf("Status macchina %s aggiornato a: %s", id, status)))
}

func (s *SmartContract) ReadMachine(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 1 {
		return shim.Error("Numero argomenti errato. Uso: ReadMachine <id>")
	}

	id := args[0]

	machineJSON, err := stub.GetState(id)
	if err != nil {
		return shim.Error(fmt.Sprintf("Errore recupero macchina: %v", err))
	}
	if machineJSON == nil {
		return shim.Error(fmt.Sprintf("Macchina %s non trovata", id))
	}

	return shim.Success(machineJSON)
}

func (s *SmartContract) GetAllMachines(stub shim.ChaincodeStubInterface) peer.Response {
	resultsIterator, err := stub.GetStateByRange("MACH", "MACH~")
	if err != nil {
		return shim.Error(err.Error())
	}
	defer resultsIterator.Close()

	var machines []Machine

	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return shim.Error(err.Error())
		}

		var machine Machine
		err = json.Unmarshal(queryResponse.Value, &machine)
		if err != nil {
			return shim.Error(err.Error())
		}
		machines = append(machines, machine)
	}

	machinesJSON, err := json.Marshal(machines)
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success(machinesJSON)
}

func (s *SmartContract) AddIntervention(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 4 {
		return shim.Error("Numero argomenti errato. Uso: AddIntervention <id> <type> <description> <technician>")
	}

	id := args[0]
	interventionType := args[1]
	description := args[2]
	technician := args[3]

	if interventionType != "ordinaria" && interventionType != "straordinaria" {
		return shim.Error("Type deve essere 'ordinaria' o 'straordinaria'")
	}

	machineJSON, err := stub.GetState(id)
	if err != nil {
		return shim.Error(fmt.Sprintf("Errore recupero macchina: %v", err))
	}
	if machineJSON == nil {
		return shim.Error(fmt.Sprintf("Macchina %s non trovata", id))
	}

	var machine Machine
	err = json.Unmarshal(machineJSON, &machine)
	if err != nil {
		return shim.Error(err.Error())
	}

	// Usa Creator MSP ID (deterministico su tutti i peer)
	creatorBytes, err := stub.GetCreator()
	if err != nil {
		return shim.Error(fmt.Sprintf("Impossibile recuperare creator: %v", err))
	}

	creatorMSPID, err := getCreatorMSPID(creatorBytes)
	if err != nil {
		return shim.Error(fmt.Sprintf("Impossibile estrarre MSP ID: %v", err))
	}

	intervention := Intervention{
		Date:        time.Now().Format(time.RFC3339),
		Type:        interventionType,
		Description: description,
		Technician:  technician,
		ApprovedBy:  creatorMSPID,
	}

	machine.Interventions = append(machine.Interventions, intervention)
	machine.LastUpdate = time.Now().Format(time.RFC3339)

	if interventionType == "straordinaria" || interventionType == "ordinaria" {
		machine.Status = "funzionante"
	}

	machineJSON, err = json.Marshal(machine)
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(id, machineJSON)
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success([]byte(fmt.Sprintf("Intervento %s aggiunto per macchina %s", interventionType, id)))
}

func (s *SmartContract) CreateAlert(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 4 {
		return shim.Error("Numero argomenti errato. Uso: CreateAlert <machineId> <machineName> <alertType> <message>")
	}

	machineID := args[0]
	machineName := args[1]
	alertType := args[2]
	message := args[3]

	timestamp := time.Now().Format(time.RFC3339)
	alertID := fmt.Sprintf("ALERT_%s_%s", machineID, timestamp)

	alert := Alert{
		ID:          alertID,
		MachineID:   machineID,
		MachineName: machineName,
		AlertType:   alertType,
		Message:     message,
		Timestamp:   timestamp,
	}

	alertJSON, err := json.Marshal(alert)
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(alertID, alertJSON)
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success([]byte(fmt.Sprintf("Alert %s creato con successo", alertID)))
}

func (s *SmartContract) GetAlertsByMachine(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 1 {
		return shim.Error("Numero argomenti errato. Uso: GetAlertsByMachine <machineId>")
	}

	machineID := args[0]

	startKey := fmt.Sprintf("ALERT_%s_", machineID)
	endKey := fmt.Sprintf("ALERT_%s_~", machineID)

	resultsIterator, err := stub.GetStateByRange(startKey, endKey)
	if err != nil {
		return shim.Error(err.Error())
	}
	defer resultsIterator.Close()

	var alerts []Alert

	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return shim.Error(err.Error())
		}

		var alert Alert
		err = json.Unmarshal(queryResponse.Value, &alert)
		if err != nil {
			return shim.Error(err.Error())
		}
		alerts = append(alerts, alert)
	}

	alertsJSON, err := json.Marshal(alerts)
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success(alertsJSON)
}

func (s *SmartContract) Init(stub shim.ChaincodeStubInterface) peer.Response {
	return shim.Success(nil)
}

func (s *SmartContract) Invoke(stub shim.ChaincodeStubInterface) peer.Response {
	function, args := stub.GetFunctionAndParameters()

	switch function {
	case "InitLedger":
		return s.InitLedger(stub)
	case "RegisterMachine":
		return s.RegisterMachine(stub, args)
	case "UpdateOperatingHours":
		return s.UpdateOperatingHours(stub, args)
	case "CheckMachineStatus":
		return s.CheckMachineStatus(stub, args)
	case "SetMachineStatus":
		return s.SetMachineStatus(stub, args)
	case "ReadMachine":
		return s.ReadMachine(stub, args)
	case "GetAllMachines":
		return s.GetAllMachines(stub)
	case "AddIntervention":
		return s.AddIntervention(stub, args)
	case "CreateAlert":
		return s.CreateAlert(stub, args)
	case "GetAlertsByMachine":
		return s.GetAlertsByMachine(stub, args)
	default:
		return shim.Error(fmt.Sprintf("Funzione %s non riconosciuta", function))
	}
}

func main() {
	if err := shim.Start(new(SmartContract)); err != nil {
		fmt.Printf("Errore avvio chaincode: %v\n", err)
	}
}
