// Package store provides the data access layer for the Orders service.
package store

import (
	"fmt"
	"sync"
	"time"

	"orders-api/internal/models"
)

// OrderStore defines the contract for order data operations.
type OrderStore interface {
	ListOrders() []models.Order
	CreateOrder(req models.CreateOrderRequest) models.Order
}

// inMemoryOrderStore is a thread-safe in-memory implementation.
type inMemoryOrderStore struct {
	mu     sync.RWMutex
	orders []models.Order
	nextID int
}

// NewOrderStore creates a new empty OrderStore.
func NewOrderStore() OrderStore {
	return &inMemoryOrderStore{nextID: 1}
}

// ListOrders returns all orders.
func (s *inMemoryOrderStore) ListOrders() []models.Order {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]models.Order, len(s.orders))
	copy(result, s.orders)
	return result
}

// CreateOrder creates a new order and returns it with a generated ID.
func (s *inMemoryOrderStore) CreateOrder(req models.CreateOrderRequest) models.Order {
	s.mu.Lock()
	defer s.mu.Unlock()

	order := models.Order{
		ID:        fmt.Sprintf("order-%03d", s.nextID),
		ItemName:  req.ItemName,
		Quantity:  req.Quantity,
		Status:    "confirmed",
		CreatedAt: time.Now(),
	}
	s.nextID++
	s.orders = append(s.orders, order)
	return order
}
