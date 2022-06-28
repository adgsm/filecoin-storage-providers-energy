package api

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/adgsm/filecoin-storage-providers-energy-api/internal"
	"github.com/lib/pq"

	"github.com/gorilla/mux"
	"github.com/rs/cors"

	"github.com/jackc/pgx/v4/pgxpool"
)

// declare global vars
type Api struct {
	Router *mux.Router
}

var config internal.Config
var rcerr error
var confsPath = "configs/configs"
var db *pgxpool.Pool

func New(dtb *pgxpool.Pool) http.Handler {
	// read configs
	config, rcerr = internal.ReadConfigs(confsPath)
	if rcerr != nil {
		panic(rcerr)
	}

	// set db pointer
	db = dtb

	// set api struct
	a := &Api{
		Router: mux.NewRouter(),
	}
	a.Router.Host(config["api_host"])

	// set api v1 subroute
	v1 := a.Router.PathPrefix("/sp-metered-energy/api/v1").Subrouter()

	// inti routes
	initRoutes(v1)

	// allow cros-origine requests
	cr := cors.New(cors.Options{
		AllowedOrigins:   []string{"http://localhost:3000", "https://localhost:3000", fmt.Sprintf("https://%s", config["api_host"])},
		AllowCredentials: true,
	})
	hndl := cr.Handler(v1)

	return hndl
}

func initRoutes(r *mux.Router) {
	// search / filter storage providers
	r.HandleFunc("/storage-providers", storageProviders).Methods(http.MethodGet)
	r.HandleFunc("/storage-providers?name={name}", storageProviders).Methods(http.MethodGet)

	// search / filter storage provider's hardware
	r.HandleFunc("/hardware", hardware).Methods(http.MethodGet)
	r.HandleFunc("/hardware?storage_provider_id={storage_provider_id}&name={name}&racks={racks}&miners={miners}&locations={locations}&functions={functions}", hardware).Methods(http.MethodGet)

	// search / filter storage provider's power consumption
	r.HandleFunc("/power", power).Methods(http.MethodGet)
	r.HandleFunc("/power?storage_provider_id={storage_provider_id}&name={name}&racks={racks}&miners={miners}&locations={locations}&functions={functions}&from={from}&to={to}&offset={offset}&limit={limit}", power).Methods(http.MethodGet)

	// search / filter storage provider's energy consumption
	r.HandleFunc("/energy", energy).Methods(http.MethodGet)
	r.HandleFunc("/energy?storage_provider_id={storage_provider_id}&name={name}&racks={racks}&miners={miners}&locations={locations}&functions={functions}&from={from}&to={to}&offset={offset}&limit={limit}", energy).Methods(http.MethodGet)
}

func storageProviders(w http.ResponseWriter, r *http.Request) {
	// declare types
	type Record struct {
		Id              int
		StorageProvider string
		Description     internal.NullString
	}

	// set defalt response content type
	w.Header().Set("Content-Type", "application/json")

	// collect query parameters
	queryParams := r.URL.Query()

	// check for provided name
	name := queryParams.Get("name")

	internal.WriteLog("info", fmt.Sprintf("Search storage providers containing '%s' in its name.", name), "api")

	// search sites with provided parameters
	rows, rowsErr := db.Query(context.Background(),
		"select \"id\", \"storage_provider\", \"description\" from filecoin_storage_providers_energy_api.storage_providers where lower(storage_provider) like $1;",
		"%"+strings.ToLower(name)+"%")

	if rowsErr != nil {
		fmt.Print(rowsErr.Error())
		message := "Error occured whilst searching for storage providers."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(jsonMessage))
		return
	}

	defer rows.Close()

	records := []Record{}

	for rows.Next() {
		var record Record
		if recordErr := rows.Scan(&record.Id, &record.StorageProvider, &record.Description); recordErr != nil {
			message := fmt.Sprintf("Error occured whilst searching for storage providers in the the database. (%s)", recordErr.Error())
			jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
			internal.WriteLog("error", message, "api")
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(jsonMessage))
			return
		}
		records = append(records, record)
	}

	// send response
	sitesJson, errJson := json.Marshal(records)
	if errJson != nil {
		message := "Cannot marshal the database response for searched storage providers."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(jsonMessage))
		return
	}

	// response writter
	w.WriteHeader(http.StatusOK)
	w.Write(sitesJson)
}

func hardware(w http.ResponseWriter, r *http.Request) {
	// declare types
	type Record struct {
		Id                int
		StorageProviderId int
		Name              string
		Functions         []string
		Rack              internal.NullString
		MinerId           internal.NullString
		Ip                internal.NullString
		Location          internal.NullString
		Description       internal.NullString
	}

	// set defalt response content type
	w.Header().Set("Content-Type", "application/json")

	// collect query parameters
	queryParams := r.URL.Query()

	// check for provided storage provider id
	storageProviderIdStr := queryParams.Get("storage_provider_id")

	if storageProviderIdStr == "" {
		message := "Storage provider Id is mandatory parameter."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	storageProviderId, storageProviderIdErr := strconv.Atoi(storageProviderIdStr)
	if storageProviderIdErr != nil {
		message := "Storage provider Id should be valid integer."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	// check for other provided parameters
	name := queryParams.Get("name")
	miners := queryParams.Get("miners")
	functions := queryParams.Get("functions")
	racks := queryParams.Get("racks")
	locations := queryParams.Get("locations")

	internal.WriteLog("info", fmt.Sprintf("Searching storage provider's hardware with following parameters:"+
		"storage provider id: %d, name '%s', miners '%s', functions '%s', racks '%s', locations '%s'.",
		storageProviderId, internal.SqlNullableString(name).String, internal.SqlNullableString(miners).String,
		internal.SqlNullableString(functions).String, internal.SqlNullableString(racks).String,
		internal.SqlNullableString(locations).String), "api")

	// split search words into sql array
	var minersArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(miners) == 0 {
		minersArr = pq.Array([]sql.NullString{})
	} else {
		minersArr = pq.Array(strings.Split(internal.SqlNullableString(miners).String, ","))
	}

	var functionsArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(functions) == 0 {
		functionsArr = pq.Array([]sql.NullString{})
	} else {
		functionsArr = pq.Array(strings.Split(internal.SqlNullableString(functions).String, ","))
	}

	var racksArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(racks) == 0 {
		racksArr = pq.Array([]sql.NullString{})
	} else {
		racksArr = pq.Array(strings.Split(internal.SqlNullableString(racks).String, ","))
	}

	var locationsArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(locations) == 0 {
		locationsArr = pq.Array([]sql.NullString{})
	} else {
		locationsArr = pq.Array(strings.Split(internal.SqlNullableString(locations).String, ","))
	}

	// search hardware with provided parameters
	rows, rowsErr := db.Query(context.Background(), "select * from filecoin_storage_providers_energy_api.search_hardware($1::integer, $2::varchar(255), $3::varchar(255)[], $4::varchar(255)[], $5::varchar(255)[], $6::varchar(255)[]);",
		storageProviderId, internal.SqlNullableString(name), minersArr, functionsArr, racksArr, locationsArr)

	if rowsErr != nil {
		fmt.Print(rowsErr.Error())
		message := "Error occured whilst searching for storage provider's hardware."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(jsonMessage))
		return
	}

	defer rows.Close()

	records := []Record{}

	for rows.Next() {
		var record Record
		if recordErr := rows.Scan(&record.Id, &record.StorageProviderId, &record.Name, &record.Functions,
			&record.Rack, &record.MinerId, &record.Ip, &record.Location, &record.Description); recordErr != nil {
			message := fmt.Sprintf("Error occured whilst searching for storage provider's hardware in the the database. (%s)", recordErr.Error())
			jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
			internal.WriteLog("error", message, "api")
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(jsonMessage))
			return
		}
		records = append(records, record)
	}

	// send response
	sitesJson, errJson := json.Marshal(records)
	if errJson != nil {
		message := "Cannot marshal the database response for searched storage provider's hardware."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(jsonMessage))
		return
	}

	// response writter
	w.WriteHeader(http.StatusOK)
	w.Write(sitesJson)
}

func power(w http.ResponseWriter, r *http.Request) {
	// declare types
	type Record struct {
		Id                int
		StorageProviderId int
		Name              string
		Functions         []string
		Rack              internal.NullString
		MinerId           internal.NullString
		Ip                internal.NullString
		Location          internal.NullString
		Description       internal.NullString
		Power             int
		Time              time.Time
	}

	// set defalt response content type
	w.Header().Set("Content-Type", "application/json")

	// collect query parameters
	queryParams := r.URL.Query()

	// check for provided storage provider id
	storageProviderIdStr := queryParams.Get("storage_provider_id")

	if storageProviderIdStr == "" {
		message := "Storage provider Id is mandatory parameter."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	storageProviderId, storageProviderIdErr := strconv.Atoi(storageProviderIdStr)
	if storageProviderIdErr != nil {
		message := "Storage provider Id should be valid integer."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	from := queryParams.Get("from")
	to := queryParams.Get("to")

	if from == "" || to == "" {
		message := "From - to dates are mandatory parameters."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	fromTime, fromErr := time.Parse(time.RFC3339, from)
	if fromErr != nil {
		message := "From date is not valid RFC3339 format."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	toTime, toErr := time.Parse(time.RFC3339, to)
	if toErr != nil {
		message := "To date is not valid RFC3339 format."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	if fromTime.After(toTime) {
		message := "From date can not be after To date."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	// check for other provided parameters
	name := queryParams.Get("name")
	miners := queryParams.Get("miners")
	functions := queryParams.Get("functions")
	racks := queryParams.Get("racks")
	locations := queryParams.Get("locations")
	offset := queryParams.Get("offset")
	limit := queryParams.Get("limit")

	var off int
	var lmt int
	var limitErr error
	if offset == "" {
		off = 0
	}

	if limit == "" {
		lmt, limitErr = strconv.Atoi(config["limit"])
		if limitErr != nil {
			message := "Default query limit defined in configs is not valid intiger."
			jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
			internal.WriteLog("error", message, "api")
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(jsonMessage))
			return
		}
	}

	internal.WriteLog("info", fmt.Sprintf("Searching storage provider's power consumption with following parameters:"+
		"storage provider id: %d, name '%s', miners '%s', functions '%s', racks '%s', locations '%s'"+
		"from '%s', to '%s', offset '%d', limit '%d'.",
		storageProviderId, internal.SqlNullableString(name).String, internal.SqlNullableString(miners).String,
		internal.SqlNullableString(functions).String, internal.SqlNullableString(racks).String,
		internal.SqlNullableString(locations).String, from, to, off, lmt), "api")

	// split search words into sql array
	var minersArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(miners) == 0 {
		minersArr = pq.Array([]sql.NullString{})
	} else {
		minersArr = pq.Array(strings.Split(internal.SqlNullableString(miners).String, ","))
	}

	var functionsArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(functions) == 0 {
		functionsArr = pq.Array([]sql.NullString{})
	} else {
		functionsArr = pq.Array(strings.Split(internal.SqlNullableString(functions).String, ","))
	}

	var racksArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(racks) == 0 {
		racksArr = pq.Array([]sql.NullString{})
	} else {
		racksArr = pq.Array(strings.Split(internal.SqlNullableString(racks).String, ","))
	}

	var locationsArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(locations) == 0 {
		locationsArr = pq.Array([]sql.NullString{})
	} else {
		locationsArr = pq.Array(strings.Split(internal.SqlNullableString(locations).String, ","))
	}

	// search power consumption with provided parameters
	rows, rowsErr := db.Query(context.Background(), "select * from filecoin_storage_providers_energy_api.search_power($1::integer, $2::varchar(255), $3::varchar(255)[], $4::varchar(255)[], $5::varchar(255)[], $6::varchar(255)[], $7::timestamptz, $8::timestamptz, $9::integer, $10::integer);",
		storageProviderId, internal.SqlNullableString(name), minersArr, functionsArr, racksArr, locationsArr,
		from, to, off, lmt)

	if rowsErr != nil {
		fmt.Print(rowsErr.Error())
		message := "Error occured whilst searching for storage provider's power consumption."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(jsonMessage))
		return
	}

	defer rows.Close()

	records := []Record{}

	for rows.Next() {
		var record Record
		if recordErr := rows.Scan(&record.Id, &record.StorageProviderId, &record.Name, &record.Functions,
			&record.Rack, &record.MinerId, &record.Ip, &record.Location, &record.Description,
			&record.Power, &record.Time); recordErr != nil {
			message := fmt.Sprintf("Error occured whilst searching for storage provider's power consumption in the the database. (%s)", recordErr.Error())
			jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
			internal.WriteLog("error", message, "api")
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(jsonMessage))
			return
		}
		records = append(records, record)
	}

	// send response
	sitesJson, errJson := json.Marshal(records)
	if errJson != nil {
		message := "Cannot marshal the database response for searched storage provider's power consumption."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(jsonMessage))
		return
	}

	// response writter
	w.WriteHeader(http.StatusOK)
	w.Write(sitesJson)
}

func energy(w http.ResponseWriter, r *http.Request) {
	// declare types
	type Record struct {
		Id                int
		StorageProviderId int
		Name              string
		Functions         []string
		Rack              internal.NullString
		MinerId           internal.NullString
		Ip                internal.NullString
		Location          internal.NullString
		Description       internal.NullString
		Power             int
		Time              time.Time
	}

	// set defalt response content type
	w.Header().Set("Content-Type", "application/json")

	// collect query parameters
	queryParams := r.URL.Query()

	// check for provided storage provider id
	storageProviderIdStr := queryParams.Get("storage_provider_id")

	if storageProviderIdStr == "" {
		message := "Storage provider Id is mandatory parameter."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	storageProviderId, storageProviderIdErr := strconv.Atoi(storageProviderIdStr)
	if storageProviderIdErr != nil {
		message := "Storage provider Id should be valid integer."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	from := queryParams.Get("from")
	to := queryParams.Get("to")

	if from == "" || to == "" {
		message := "From - to dates are mandatory parameters."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	fromTime, fromErr := time.Parse(time.RFC3339, from)
	if fromErr != nil {
		message := "From date is not valid RFC3339 format."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	toTime, toErr := time.Parse(time.RFC3339, to)
	if toErr != nil {
		message := "To date is not valid RFC3339 format."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	if fromTime.After(toTime) {
		message := "From date can not be after To date."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(jsonMessage))
		return
	}

	// check for other provided parameters
	name := queryParams.Get("name")
	miners := queryParams.Get("miners")
	functions := queryParams.Get("functions")
	racks := queryParams.Get("racks")
	locations := queryParams.Get("locations")
	offset := queryParams.Get("offset")
	limit := queryParams.Get("limit")

	var off int
	var lmt int
	var limitErr error
	if offset == "" {
		off = 0
	}

	if limit == "" {
		lmt, limitErr = strconv.Atoi(config["limit"])
		if limitErr != nil {
			message := "Default query limit defined in configs is not valid intiger."
			jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
			internal.WriteLog("error", message, "api")
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(jsonMessage))
			return
		}
	}

	internal.WriteLog("info", fmt.Sprintf("Searching storage provider's energy consumption with following parameters:"+
		"storage provider id: %d, name '%s', miners '%s', functions '%s', racks '%s', locations '%s'"+
		"from '%s', to '%s', offset '%d', limit '%d'.",
		storageProviderId, internal.SqlNullableString(name).String, internal.SqlNullableString(miners).String,
		internal.SqlNullableString(functions).String, internal.SqlNullableString(racks).String,
		internal.SqlNullableString(locations).String, from, to, off, lmt), "api")

	// split search words into sql array
	var minersArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(miners) == 0 {
		minersArr = pq.Array([]sql.NullString{})
	} else {
		minersArr = pq.Array(strings.Split(internal.SqlNullableString(miners).String, ","))
	}

	var functionsArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(functions) == 0 {
		functionsArr = pq.Array([]sql.NullString{})
	} else {
		functionsArr = pq.Array(strings.Split(internal.SqlNullableString(functions).String, ","))
	}

	var racksArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(racks) == 0 {
		racksArr = pq.Array([]sql.NullString{})
	} else {
		racksArr = pq.Array(strings.Split(internal.SqlNullableString(racks).String, ","))
	}

	var locationsArr interface {
		sql.Scanner
		driver.Valuer
	}

	if len(locations) == 0 {
		locationsArr = pq.Array([]sql.NullString{})
	} else {
		locationsArr = pq.Array(strings.Split(internal.SqlNullableString(locations).String, ","))
	}

	// search power consumption with provided parameters
	rows, rowsErr := db.Query(context.Background(), "select * from filecoin_storage_providers_energy_api.search_energy($1::integer, $2::varchar(255), $3::varchar(255)[], $4::varchar(255)[], $5::varchar(255)[], $6::varchar(255)[], $7::timestamptz, $8::timestamptz, $9::integer, $10::integer);",
		storageProviderId, internal.SqlNullableString(name), minersArr, functionsArr, racksArr, locationsArr,
		from, to, off, lmt)

	if rowsErr != nil {
		fmt.Print(rowsErr.Error())
		message := "Error occured whilst searching for storage provider's energy consumption."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(jsonMessage))
		return
	}

	defer rows.Close()

	records := []Record{}

	for rows.Next() {
		var record Record
		if recordErr := rows.Scan(&record.Id, &record.StorageProviderId, &record.Name, &record.Functions,
			&record.Rack, &record.MinerId, &record.Ip, &record.Location, &record.Description,
			&record.Power, &record.Time); recordErr != nil {
			message := fmt.Sprintf("Error occured whilst searching for storage provider's energy consumption in the the database. (%s)", recordErr.Error())
			jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
			internal.WriteLog("error", message, "api")
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(jsonMessage))
			return
		}
		records = append(records, record)
	}

	// send response
	sitesJson, errJson := json.Marshal(records)
	if errJson != nil {
		message := "Cannot marshal the database response for searched storage provider's energy consumption."
		jsonMessage := fmt.Sprintf("{\"message\":\"%s\"}", message)
		internal.WriteLog("error", message, "api")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(jsonMessage))
		return
	}

	// response writter
	w.WriteHeader(http.StatusOK)
	w.Write(sitesJson)
}
