// Package homeassistant polls the Home Assistant REST API for enclosure entity states.
package homeassistant

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"time"
)

// EnclosureEntities holds the entity IDs for Gutgrinda's enclosure devices.
type EnclosureEntities struct {
	Temperature   string
	Humidity      string
	BaskingLamp   string
	AmbientLight  string
	CeramicHeater string
}

// EnclosureStatus holds the current state of the enclosure.
type EnclosureStatus struct {
	Temperature   float64 `json:"temperature"`
	Humidity      float64 `json:"humidity"`
	BaskingLamp   bool    `json:"basking_lamp"`
	AmbientLight  bool    `json:"ambient_light"`
	CeramicHeater bool    `json:"ceramic_heater"`
	Available     bool    `json:"available"`
}

// Client fetches entity states from Home Assistant.
type Client struct {
	baseURL string
	token   string
	http    *http.Client
}

// New creates a Home Assistant client for the given base URL and bearer token.
func New(baseURL, token string) *Client {
	return &Client{
		baseURL: baseURL,
		token:   token,
		http:    &http.Client{Timeout: 5 * time.Second},
	}
}

// FetchEnclosure returns the current state of all enclosure entities.
// Returns an unavailable status on any error.
func (c *Client) FetchEnclosure(ctx context.Context, entities EnclosureEntities) EnclosureStatus {
	temp, err := c.fetchFloat(ctx, entities.Temperature)
	if err != nil {
		slog.Warn("HA temperature fetch failed", "entity", entities.Temperature, "error", err)
		return EnclosureStatus{}
	}
	hum, err := c.fetchFloat(ctx, entities.Humidity)
	if err != nil {
		slog.Warn("HA humidity fetch failed", "entity", entities.Humidity, "error", err)
		return EnclosureStatus{}
	}
	return EnclosureStatus{
		Temperature:   temp,
		Humidity:      hum,
		BaskingLamp:   c.fetchSwitch(ctx, entities.BaskingLamp),
		AmbientLight:  c.fetchSwitch(ctx, entities.AmbientLight),
		CeramicHeater: c.fetchSwitch(ctx, entities.CeramicHeater),
		Available:     true,
	}
}

type haState struct {
	State string `json:"state"`
}

func (c *Client) fetchState(ctx context.Context, entityID string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		fmt.Sprintf("%s/api/states/%s", c.baseURL, entityID), nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)

	resp, err := c.http.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("status %d for %s", resp.StatusCode, entityID)
	}

	var s haState
	if err := json.NewDecoder(resp.Body).Decode(&s); err != nil {
		return "", err
	}
	return s.State, nil
}

func (c *Client) fetchFloat(ctx context.Context, entityID string) (float64, error) {
	state, err := c.fetchState(ctx, entityID)
	if err != nil {
		return 0, err
	}
	return strconv.ParseFloat(state, 64)
}

func (c *Client) fetchSwitch(ctx context.Context, entityID string) bool {
	state, err := c.fetchState(ctx, entityID)
	if err != nil {
		slog.Warn("HA switch fetch failed", "entity", entityID, "error", err)
		return false
	}
	return state == "on"
}
