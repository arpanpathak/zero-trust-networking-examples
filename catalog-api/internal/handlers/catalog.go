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
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

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

// HandleAdmin exposes a sensitive admin endpoint.
// Used in Exercise 7 (path-based L7 routing) to demonstrate that
// Cilium can block access to /admin at the kernel level while
// allowing /items and /healthz.
func (h *CatalogHandler) HandleAdmin(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] ⚠️  GET /admin accessed from %s", h.hostname, r.RemoteAddr)
	writeJSON(w, http.StatusOK, map[string]any{
		"admin":    true,
		"hostname": h.hostname,
		"message":  "This is a sensitive admin endpoint. Cilium should block access to this path.",
		"items":    h.store.ListItems(),
		"config": map[string]string{
			"db_host": "redis-master.cilium-demo.svc.cluster.local",
			"secret":  "hunter2",
		},
	})
}

// HandleTestEgress attempts to call an external service.
// Used in Exercise 1 (egress lockdown) and Exercise 2 (FQDN egress)
// to verify that Cilium blocks outbound calls to the internet.
func (h *CatalogHandler) HandleTestEgress(w http.ResponseWriter, r *http.Request) {
	url := r.URL.Query().Get("url")
	if url == "" {
		url = "https://httpbin.org/ip"
	}

	log.Printf("[%s] GET /test-egress — calling %s...", h.hostname, url)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]string{
			"status":      "blocked",
			"target":      url,
			"error":       err.Error(),
			"explanation": "Cilium egress policy blocked this outbound call.",
		})
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	writeJSON(w, http.StatusOK, map[string]string{
		"status":      "allowed",
		"target":      url,
		"response":    string(body),
		"explanation": fmt.Sprintf("Egress to %s succeeded — not blocked by policy.", url),
	})
}

// writeJSON is a helper that sets Content-Type and encodes the response.
func writeJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
