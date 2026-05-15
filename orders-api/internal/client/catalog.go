// Package client provides HTTP clients for communicating with external services.
// This package isolates all outbound network calls so they can be mocked in tests
// and swapped without touching handler logic.
package client

import (
	"fmt"
	"io"
	"net/http"
	"strings"
)

// CatalogClient abstracts communication with the Catalog API service.
type CatalogClient interface {
	// FetchItems calls GET /items on the catalog service.
	// This will be ALLOWED by the Cilium L3/L4 policy.
	FetchItems() ([]byte, error)

	// WriteItem calls POST /items on the catalog service.
	// This will be BLOCKED by the Cilium L7 policy.
	WriteItem(name string, price float64) (statusCode int, body string, err error)
}

type httpCatalogClient struct {
	baseURL string
	client  *http.Client
}

// NewCatalogClient creates a new CatalogClient pointing to the given base URL.
func NewCatalogClient(baseURL string) CatalogClient {
	return &httpCatalogClient{
		baseURL: baseURL,
		client:  &http.Client{},
	}
}

// FetchItems calls GET /items on the catalog service.
func (c *httpCatalogClient) FetchItems() ([]byte, error) {
	resp, err := c.client.Get(c.baseURL + "/items")
	if err != nil {
		return nil, fmt.Errorf("failed to reach catalog-api: %w", err)
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}

// WriteItem attempts to POST a new item to the catalog service.
func (c *httpCatalogClient) WriteItem(name string, price float64) (int, string, error) {
	payload := fmt.Sprintf(`{"name":"%s","price":%.2f}`, name, price)
	resp, err := c.client.Post(c.baseURL+"/items", "application/json", strings.NewReader(payload))
	if err != nil {
		return 0, "", fmt.Errorf("blocked by Cilium: %w", err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(data), nil
}
