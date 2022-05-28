package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/adgsm/filecoin-storage-providers-energy/helpers"
	"github.com/jackc/pgx/v4/pgxpool"
	"github.com/joho/godotenv"
	"github.com/robfig/cron/v3"
)

func main() {
	// Set configs file path
	confsPath := "configs/configs"

	// Read configs
	config, rcerr := helpers.ReadConfigs(confsPath)

	if rcerr != nil {
		panic(rcerr)
	}

	// Cast port to int
	port, atoierr := strconv.Atoi(config["postgresql_port"])

	if atoierr != nil {
		panic(atoierr)
	}

	// Init db connection
	db, dberr := helpers.DbInit(config["postgresql_host"], port,
		config["postgresql_user"], goDotEnvVariable(config["postgresql_password"]), config["postgresql_database"])

	if dberr != nil {
		panic(dberr)
	}

	defer db.Close()

	// instantiate cron
	crn := cron.New()

	crn.AddFunc(config["cron_parse_binaries"], func() {
		scrapeApis(db, config)
	})

	// start cron
	crn.Start()

	defer crn.Stop()

	// make it run forever
	done := make(chan bool)
	<-done
}

func scrapeApis(db *pgxpool.Pool, config helpers.Config) {
	// Get the list of Storage Providers
	storageProvidersApisEnv := goDotEnvVariable("STORAGE_PROVIDERS_APIS")
	storageProvidersApis := strings.Split(storageProvidersApisEnv, ",")
	for i := range storageProvidersApis {
		// Get Storage Provider data
		offset := 0
		batchSizeConf := config["batch_size"]
		batchSize, babatchSizeErr := strconv.Atoi(batchSizeConf)
		if (babatchSizeErr) != nil {
			batchSize = 100
		}
		getSPData(storageProvidersApis[i], db, config, time.Now(), offset, batchSize)
	}
}

// Load/read the .env file and
// return the value of the key
func goDotEnvVariable(key string) string {
	// load .env file
	err := godotenv.Load(".env")

	if err != nil {
		panic(err)
	}

	return os.Getenv(key)
}

// Get storage and authorisation method from env
type SPAuth map[string]string

func getSP(sp string) SPAuth {
	sp = strings.TrimSpace(sp)
	helpers.WriteLog("info", fmt.Sprintf("STORAGE_PROVIDER_API : %s", sp), "main.go/getSP")
	spAuthMethodEnvKey := fmt.Sprintf("%s%s", sp, "_AUTHORIZATION_METHOD")
	spAuthMethod := goDotEnvVariable(spAuthMethodEnvKey)
	helpers.WriteLog("info", fmt.Sprintf("%s : %s \n", spAuthMethodEnvKey, spAuthMethod), "main.go/getSP")
	result := SPAuth{
		"sp":         sp,
		"authMethod": spAuthMethod,
	}
	return result
}

// Get SP data
type AuthHeader map[string]string
type Model1EnergyConsumptionRecord struct {
	Id       int
	Location string
	Type     string
	Ip       string
	Power    int
	Time     string
}
type Model1EnergyConsumptionResponse struct {
	Count    int
	Next     string
	Previous string
	Results  []Model1EnergyConsumptionRecord
}

func getSPData(sp string, db *pgxpool.Pool, config helpers.Config,
	from time.Time, offset int, limit int) {

	spWithAuth := getSP(sp)
	var client *http.Client

	// Prepare authorization for API call
	switch spWithAuth["authMethod"] {
	case "HEADER":
		client = prepareClientWithHeader(spWithAuth["sp"])
	}

	// Prepare URI model for API call
	spUriParamsModel := prepareUriModel(spWithAuth["sp"])

	// Prepare URI model for API call
	spUriDateParamsModel := prepareUriDateModel(spWithAuth["sp"])

	// Prepare URI for API call
	spUri := prepareUri(spWithAuth["sp"])

	// When we had last reading
	var to time.Time
	var fromError error
	if offset == 0 {
		from, fromError = getLastReadingDate(spWithAuth["sp"], db, config)
		if fromError != nil {
			return
		}
	}

	// Get max reading frequency for API call
	spMaxReadingFreq, spMaxReadingFreqErr := getMaxReadingFreq(spWithAuth["sp"])
	if spMaxReadingFreqErr != nil {
		return
	}

	// Set from from most recent record
	helpers.WriteLog("info", fmt.Sprintf("Most recent record: %s.", from.Format(spUriDateParamsModel)), "main.go/getSPData")
	to = from.Add(time.Duration(spMaxReadingFreq))

	// If we do not read in the future it is OK
	if to.After(time.Now()) {
		helpers.WriteLog("info", fmt.Sprintf("Will not read from the future: %s.", to.Format(spUriDateParamsModel)), "main.go/getSPData")
		return
	}

	switch spUriParamsModel {
	case "L_O_SD_ED":
		spUri = fmt.Sprintf(spUri, limit, offset, from.Format(spUriDateParamsModel), to.Format(spUriDateParamsModel))
		helpers.WriteLog("info", fmt.Sprintf("URI: %s", spUri), "main.go/getSPData")
	case "YYYY_M_D":
		spUri = fmt.Sprintf(spUri, from.Year(), from.Month(), from.Day())
		helpers.WriteLog("info", fmt.Sprintf("URI: %s", spUri), "main.go/getSPData")
	}

	response, responseErr := getResponse(client, spUri)

	if responseErr != nil {
		return
	}

	// Determine response data model
	spDataModel := determineResponseModel(spWithAuth["sp"])

	switch spDataModel {
	case "MODEL_1":
		energyConsumptionResponse := new(Model1EnergyConsumptionResponse)
		json.NewDecoder(response.Body).Decode(energyConsumptionResponse)

		results, resultsErr := json.Marshal(energyConsumptionResponse.Results)
		if resultsErr != nil {
			return
		}
		// Add bach into a DB
		addBatchErr := addBatchIntoDB(spWithAuth["sp"], db, from, to, offset, limit, string(results))
		if addBatchErr != nil {
			return
		}

		// Look for next batch
		helpers.WriteLog("info", fmt.Sprintf("Total records: %d, next offset pointer: %d ",
			energyConsumptionResponse.Count, offset+limit), "main.go/getSPData")
		if energyConsumptionResponse.Count >= offset+limit {
			getSPData(sp, db, config, from, offset+limit, limit)
		}
	case "MODEL_2":
		body, _ := ioutil.ReadAll(response.Body) // response body is []byte
		addBatchErr := addBatchIntoDB(spWithAuth["sp"], db, from, to, -1, -1, string(body))
		if addBatchErr != nil {
			return
		}
	}

	response.Body.Close()

	// Get next reading cycle
	getSPData(sp, db, config, from, 0, limit)
}

func prepareClientWithHeader(sp string) *http.Client {
	spAuthEnvKey := fmt.Sprintf("%s%s", sp, "_AUTHORIZATION_HEADER")
	spAuth := goDotEnvVariable(spAuthEnvKey)
	helpers.WriteLog("info", fmt.Sprintf("%s : %s", spAuthEnvKey, spAuth), "main.go/prepareClientWithHeader")

	spAuthHeader := strings.Split(spAuth, ":")
	spAuthHeaderKey := spAuthHeader[0]
	spAuthHeaderValue := spAuthHeader[1]
	authHeader := AuthHeader{
		spAuthHeaderKey: spAuthHeaderValue,
	}
	return helpers.ClientWithHeader(authHeader)
}

func prepareUriModel(sp string) string {
	spUriParamsModelEnvKey := fmt.Sprintf("%s%s", sp, "_URI_PARAMETERS_MODEL")
	spUriParamsModel := goDotEnvVariable(spUriParamsModelEnvKey)
	helpers.WriteLog("info", fmt.Sprintf("%s : %s", spUriParamsModelEnvKey, spUriParamsModel), "main.go/prepareUriModel")
	return spUriParamsModel
}

func prepareUriDateModel(sp string) string {
	spUriDateParamsModelEnvKey := fmt.Sprintf("%s%s", sp, "_URI_DATE_PARAMETERS_MODEL")
	spUriDateParamsModel := goDotEnvVariable(spUriDateParamsModelEnvKey)
	helpers.WriteLog("info", fmt.Sprintf("%s : %s", spUriDateParamsModelEnvKey, spUriDateParamsModel), "main.go/prepareDateUriModel")
	return spUriDateParamsModel
}

func getMaxReadingFreq(sp string) (int64, error) {
	spMaxReadingFreqEnvKey := fmt.Sprintf("%s%s", sp, "_MAX_READING_FREQUENCY")
	spMaxReadingFreq := goDotEnvVariable(spMaxReadingFreqEnvKey)
	// Cast port to int
	freq, freqErr := strconv.ParseInt(spMaxReadingFreq, 10, 64)
	if freqErr != nil {
		helpers.WriteLog("error", fmt.Sprintf("%s can not be converted to int64", spMaxReadingFreq), "main.go/getMaxReadingFreq")
		return 0, freqErr
	}
	helpers.WriteLog("info", fmt.Sprintf("%s : %d", spMaxReadingFreqEnvKey, freq), "main.go/getMaxReadingFreq")
	return freq, nil
}

func prepareUri(sp string) string {
	spUriEnvKey := fmt.Sprintf("%s%s", sp, "_URI")
	return goDotEnvVariable(spUriEnvKey)
}

func getResponse(client *http.Client, uri string) (response *http.Response, responseErr error) {
	response, responseErr = client.Get(uri)
	if responseErr != nil {
		helpers.WriteLog("error", fmt.Sprintf("URL %s is unreachable.", uri), "main.go/getResponse")
		return nil, responseErr
	}
	helpers.WriteLog("info", fmt.Sprintf("Response status: %s", response.Status), "main.go/getResponse")
	return response, nil
}

func determineResponseModel(sp string) string {
	spDataModelEnvKey := fmt.Sprintf("%s%s", sp, "_DATA_MODEL")
	spDataModel := goDotEnvVariable(spDataModelEnvKey)
	helpers.WriteLog("info", fmt.Sprintf("%s : %s", spDataModelEnvKey, spDataModel), "main.go/determineResponseModel")
	return spDataModel
}

func getLastReadingDate(sp string, db *pgxpool.Pool, config helpers.Config) (time.Time, error) {
	var from time.Time
	var fromError error
	query := "select \"to\" from filecoin_storage_providers_energy_scraper.payloads where api=$1 order by \"to\" desc limit 1;"
	mostRecentRecord := db.QueryRow(context.Background(), query, sp)
	golangDateFormat := config["golang_date_format"]

	mostRecentRecordErr := mostRecentRecord.Scan(&from)
	if mostRecentRecordErr != nil {
		helpers.WriteLog("info", fmt.Sprintf("No records exist for \"%s\" API in the DB. Start collecting from the \"beginning\" of time.",
			sp), "main.go/getLastReadingDate")

		cfrom := config["measurement_started"]
		from, fromError = time.Parse(golangDateFormat, cfrom)

		if fromError != nil {
			helpers.WriteLog("error", fmt.Sprintf("Measurement started date \"%s\" in configs is invalid. %s",
				cfrom, fromError.Error()), "main.go/getLastReadingDate")
			return time.Now(), fromError
		}
	}

	return from, nil
}

func addBatchIntoDB(sp string, db *pgxpool.Pool,
	from time.Time, to time.Time, offset int, limit int, body string) error {
	statement := "insert into filecoin_storage_providers_energy_scraper.payloads (\"api\", \"from\", \"to\", \"offset\", \"limit\", \"body\") values ($1, $2, $3, $4, $5, $6::jsonb);"
	_, execErr := db.Exec(context.Background(), statement, sp, from, to, offset, limit, body)
	if execErr != nil {
		helpers.WriteLog("error", fmt.Sprintf("Error occured whilst addng batch to a database. %s",
			execErr.Error()), "main.go/addBatchIntoDB")
		return execErr
	}

	return nil
}
