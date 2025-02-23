package cache

import (
	"sync"
	"time"
	"unsafe"

	"github.com/ahmedakef/gotutor/serialize"
	lru "github.com/hashicorp/golang-lru/v2/expirable"
	"go.uber.org/atomic"
)

// LRUCache is an interface for a generic LRU cache
type LRUCache interface {
	// Get returns the value for the given key and a boolean indicating if the key existed in the cache
	Get(key string) (serialize.ExecutionResponse, bool)
	// Set sets the value for the given key
	Set(key string, value serialize.ExecutionResponse)
}

type cache[T serialize.ExecutionResponse] struct {
	maxCacheSize int64
	cacheSize    *atomic.Int64

	mu    sync.RWMutex
	cache *lru.LRU[string, T]
}

// NewLRUCache creates a new LRUCache
func NewLRUCache[T serialize.ExecutionResponse](maxSize int64, maxItems int, cacheTTL time.Duration) *cache[T] {
	cacheSize := atomic.NewInt64(0)

	onEvict := func(key string, value T) {
		cacheSize.Sub(getValueSize(value))
	}

	return &cache[T]{
		maxCacheSize: maxSize,
		cacheSize:    cacheSize,
		cache:        lru.NewLRU(maxItems, onEvict, cacheTTL),
	}
}

// Get implements the LRUCache interface
func (c *cache[T]) Get(key string) (T, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	cachedVal, ok := c.cache.Get(key)

	return cachedVal, ok
}

// Set sets the value in the cache
func (c *cache[T]) Set(key string, value T) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.cache.Remove(key)

	c.cache.Add(key, value)

	c.cacheSize.Add(getValueSize(value))

	if c.cacheSize.Load() > c.maxCacheSize {
		c.evictBySize()
	}
}

func (c *cache[T]) evictBySize() {

	for c.cacheSize.Load() > c.maxCacheSize {
		_, _, ok := c.cache.RemoveOldest()
		if !ok {
			break
		}
	}
}

func getValueSize[T serialize.ExecutionResponse](valueI T) int64 {
	size := int64(0)
	switch value := any(valueI).(type) {
	case serialize.ExecutionResponse:

		size += int64(len(value.Output))
		size += int64(len(value.Duration))
		size += int64(len(value.Steps)) * int64(unsafe.Sizeof(serialize.Step{}))
		for _, step := range value.Steps {
			size += int64(unsafe.Sizeof(step))
		}
	}
	return size
}
