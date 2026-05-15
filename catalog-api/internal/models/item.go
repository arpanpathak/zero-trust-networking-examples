// Package models defines the domain entities for the Catalog service.
// These structs are shared across handlers and store layers.
package models

import "time"

// Item represents a product in the catalog.
type Item struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Price     float64   `json:"price"`
	CreatedAt time.Time `json:"created_at"`
}
