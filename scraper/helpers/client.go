package helpers

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"strings"
)

type rtWithHeader struct {
	http.Header
	rt http.RoundTripper
}

func RTWithHeader(rt http.RoundTripper) rtWithHeader {
	if rt == nil {
		rt = http.DefaultTransport
	}

	return rtWithHeader{Header: make(http.Header), rt: rt}
}

func (h rtWithHeader) RoundTrip(req *http.Request) (*http.Response, error) {
	for k, v := range h.Header {
		req.Header[k] = v
	}

	return h.rt.RoundTrip(req)
}

func ClientWithHeader(headers map[string]string) *http.Client {
	client := http.DefaultClient
	// Allow transport with insecure TSL
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: true,
		},
	}
	// Set headers
	rt := RTWithHeader(tr)
	for k, v := range headers {
		rt.Set(k, v)
	}

	reqHeaders := rt.Header
	for k, v := range reqHeaders {
		WriteLog("info", fmt.Sprintf("H: %s : %s\n", k, strings.Join(v, " ")), "helpers/client.go/ClientWithHeader")
	}

	client.Transport = rt
	return client
}
