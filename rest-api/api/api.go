package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/adgsm/filecoin-storage-providers-energy/internal"

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
	r.HandleFunc("/storage-providers?name={nae}", storageProviders).Methods(http.MethodGet)
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
