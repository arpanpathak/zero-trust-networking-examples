// Package handlers contains the HTTP handler layer for the Orders service.
// Each handler method has a single responsibility:
//   - Parse request → call dependency → write response.
package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"orders-api/internal/client"
	"orders-api/internal/models"
	"orders-api/internal/store"
)

// OrderHandler handles all HTTP requests for the orders resource.
type OrderHandler struct {
	store    store.OrderStore
	catalog  client.CatalogClient
	hostname string
}

// NewOrderHandler creates a new OrderHandler with injected dependencies.
func NewOrderHandler(s store.OrderStore, c client.CatalogClient) *OrderHandler {
	hostname, _ := os.Hostname()
	return &OrderHandler{
		store:    s,
		catalog:  c,
		hostname: hostname,
	}
}

// HandleListOrders returns all orders.
func (h *OrderHandler) HandleListOrders(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "use GET"})
		return
	}
	log.Printf("[%s] GET /orders from %s", h.hostname, r.RemoteAddr)
	writeJSON(w, http.StatusOK, h.store.ListOrders())
}

// HandleCreateOrder creates a new order after validating against the catalog.
func (h *OrderHandler) HandleCreateOrder(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "use POST"})
		return
	}

	log.Printf("[%s] POST /order — fetching catalog first...", h.hostname)

	// Step 1: Validate that the catalog is reachable (ALLOWED by Cilium).
	catalogData, err := h.catalog.FetchItems()
	if err != nil {
		log.Printf("[%s] ❌ Cannot reach catalog: %v", h.hostname, err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": err.Error()})
		return
	}
	log.Printf("[%s] ✅ Catalog response: %s", h.hostname, string(catalogData))

	// Step 2: Parse the order request.
	var req models.CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
		return
	}

	// Step 3: Create the order.
	order := h.store.CreateOrder(req)
	writeJSON(w, http.StatusCreated, order)
}

// HandleTestCatalog tests connectivity to the catalog service.
// Useful for quickly verifying if the Cilium policy allows the connection.
func (h *OrderHandler) HandleTestCatalog(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] GET /test-catalog — testing catalog connectivity...", h.hostname)

	data, err := h.catalog.FetchItems()
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"status": "blocked",
			"error":  err.Error(),
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"connected","catalog":%s}`, string(data))
}

// HandleTestWrite attempts a POST to the catalog-api.
// This will be BLOCKED by the Cilium L7 policy.
func (h *OrderHandler) HandleTestWrite(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] GET /test-write — attempting POST to catalog (should be blocked)...", h.hostname)

	statusCode, body, err := h.catalog.WriteItem("Hacked Item", 0.01)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]string{
			"result": "blocked_by_cilium",
			"error":  err.Error(),
		})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"result":      "not_blocked",
		"status_code": statusCode,
		"response":    body,
	})
}

// HandleHealth returns the health status of the service.
func (h *OrderHandler) HandleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status":   "ok",
		"hostname": h.hostname,
	})
}

// writeJSON is a helper that sets Content-Type and encodes the response.
func writeJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
