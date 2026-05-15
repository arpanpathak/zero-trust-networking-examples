// Package models defines the domain entities for the Orders service.
package models

import "time"

// Order represents a customer order.
type Order struct {
	ID        string    `json:"id"`
	ItemName  string    `json:"item_name"`
	Quantity  int       `json:"quantity"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// CreateOrderRequest is the inbound DTO for creating an order.
type CreateOrderRequest struct {
	ItemName string `json:"item_name"`
	Quantity int    `json:"quantity"`
}
