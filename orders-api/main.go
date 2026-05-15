// Package main is the entry point for the Orders API microservice.
// It wires up dependencies (client → store → handler → router) and starts the server.
package main

import (
	"log"
	"net/http"
	"os"

	"orders-api/internal/client"
	"orders-api/internal/handlers"
	"orders-api/internal/store"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	catalogURL := os.Getenv("CATALOG_URL")
	if catalogURL == "" {
		catalogURL = "http://catalog-api.cilium-demo.svc.cluster.local:8080"
	}

	// 1. Initialize the catalog client (outbound dependency).
	catalogClient := client.NewCatalogClient(catalogURL)

	// 2. Initialize the data layer.
	orderStore := store.NewOrderStore()

	// 3. Initialize the HTTP handler with injected dependencies.
	orderHandler := handlers.NewOrderHandler(orderStore, catalogClient)

	// 4. Register routes.
	mux := http.NewServeMux()
	mux.HandleFunc("/orders", orderHandler.HandleListOrders)
	mux.HandleFunc("/order", orderHandler.HandleCreateOrder)
	mux.HandleFunc("/test-catalog", orderHandler.HandleTestCatalog)
	mux.HandleFunc("/test-write", orderHandler.HandleTestWrite)
	mux.HandleFunc("/healthz", orderHandler.HandleHealth)

	// 5. Start the server.
	log.Printf("🚀 Orders API starting on :%s", port)
	log.Printf("📡 Catalog URL: %s", catalogURL)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
