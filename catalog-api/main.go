// Package main is the entry point for the Catalog API microservice.
// It wires up dependencies (store → handler → router) and starts the server.
// All business logic lives in internal/ — main.go only does orchestration.
package main

import (
	"log"
	"net/http"
	"os"

	"catalog-api/internal/handlers"
	"catalog-api/internal/store"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// 1. Initialize the data layer.
	catalogStore := store.NewCatalogStore()

	// 2. Initialize the HTTP handler with injected dependencies.
	catalogHandler := handlers.NewCatalogHandler(catalogStore)

	// 3. Register routes.
	mux := http.NewServeMux()
	mux.HandleFunc("/items", catalogHandler.HandleItems)
	mux.HandleFunc("/healthz", catalogHandler.HandleHealth)

	// 4. Start the server.
	log.Printf("🚀 Catalog API starting on :%s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
