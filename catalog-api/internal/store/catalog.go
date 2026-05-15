// Package store provides the data access layer for the Catalog service.
// It encapsulates all storage logic behind a clean interface, making it
// easy to swap the in-memory implementation for Redis/Postgres later.
package store

import (
	"fmt"
	"sync"
	"time"

	"catalog-api/internal/models"
)

// CatalogStore defines the contract for catalog data operations.
type CatalogStore interface {
	ListItems() []models.Item
	AddItem(item models.Item) models.Item
}

// inMemoryCatalogStore is a thread-safe in-memory implementation.
type inMemoryCatalogStore struct {
	mu    sync.RWMutex
	items []models.Item
}

// NewCatalogStore creates a new CatalogStore with seed data.
func NewCatalogStore() CatalogStore {
	return &inMemoryCatalogStore{
		items: []models.Item{
			{ID: "item-001", Name: "Kubernetes in Action", Price: 49.99, CreatedAt: time.Now()},
			{ID: "item-002", Name: "Programming Kubernetes", Price: 39.99, CreatedAt: time.Now()},
			{ID: "item-003", Name: "Cloud Native Go", Price: 44.99, CreatedAt: time.Now()},
		},
	}
}

// ListItems returns all items in the catalog.
func (s *inMemoryCatalogStore) ListItems() []models.Item {
	s.mu.RLock()
	defer s.mu.RUnlock()

	// Return a copy to prevent data races on the caller side.
	result := make([]models.Item, len(s.items))
	copy(result, s.items)
	return result
}

// AddItem adds a new item to the catalog and returns the created item with a generated ID.
func (s *inMemoryCatalogStore) AddItem(item models.Item) models.Item {
	s.mu.Lock()
	defer s.mu.Unlock()

	item.ID = fmt.Sprintf("item-%03d", len(s.items)+1)
	item.CreatedAt = time.Now()
	s.items = append(s.items, item)
	return item
}
