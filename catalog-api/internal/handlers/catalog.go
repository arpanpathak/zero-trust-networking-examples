// Package handlers contains the HTTP handler layer for the Catalog service.
// Handlers are responsible for:
//   - Parsing HTTP requests
//   - Calling the store layer
//   - Writing HTTP responses
//
// They do NOT contain business logic or data access code.
package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"catalog-api/internal/models"
	"catalog-api/internal/store"
)

// CatalogHandler handles all HTTP requests for the catalog resource.
type CatalogHandler struct {
	store    store.CatalogStore
	hostname string
}

// NewCatalogHandler creates a new CatalogHandler with the given store.
func NewCatalogHandler(s store.CatalogStore) *CatalogHandler {
	hostname, _ := os.Hostname()
	return &CatalogHandler{
		store:    s,
		hostname: hostname,
	}
}

// HandleItems routes GET and POST /items to the appropriate method.
func (h *CatalogHandler) HandleItems(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.listItems(w, r)
	case http.MethodPost:
		h.createItem(w, r)
	default:
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
	}
}

// listItems returns all catalog items.
// This endpoint is ALLOWED by the Cilium L7 policy.
func (h *CatalogHandler) listItems(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] GET /items from %s", h.hostname, r.RemoteAddr)
	writeJSON(w, http.StatusOK, h.store.ListItems())
}

// createItem adds a new item to the catalog.
// This endpoint is BLOCKED by the Cilium L7 policy.
func (h *CatalogHandler) createItem(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] POST /items from %s", h.hostname, r.RemoteAddr)

	var item models.Item
	if err := json.NewDecoder(r.Body).Decode(&item); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
		return
	}

	created := h.store.AddItem(item)
	writeJSON(w, http.StatusCreated, created)
}

// HandleHealth returns the health status of the service.
func (h *CatalogHandler) HandleHealth(w http.ResponseWriter, r *http.Request) {
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
