// Package prometheus queries the Prometheus HTTP API and maintains
// a current dashboard status snapshot for the SSE endpoint.
package prometheus

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"sync"
	"time"

	"piboard/internal/config"
	"piboard/internal/homeassistant"
)

// DashboardStatus is the complete state snapshot sent to the frontend.
type DashboardStatus struct {
	Timestamp      time.Time                    `json:"timestamp"`
	OverallStatus  string                       `json:"overall_status"`
	Services       []ServiceStatus              `json:"services"`
	FiringAlerts   int                          `json:"firing_alerts"`
	ProxmoxSummary ProxmoxSummary               `json:"proxmox_summary"`
	PrometheusUp   bool                         `json:"prometheus_up"`
	Enclosure      homeassistant.EnclosureStatus `json:"enclosure"`
}

type ServiceStatus struct {
	Name         string  `json:"name"`
	Status       string  `json:"status"`
	ResponseTime float64 `json:"response_time"`
}

type ProxmoxSummary struct {
	AvgCPUPercent    float64      `json:"avg_cpu_percent"`
	AvgMemoryPercent float64      `json:"avg_memory_percent"`
	WorstDiskPercent float64      `json:"worst_disk_percent"`
	WorstDiskNode    string       `json:"worst_disk_node"`
	Nodes            []NodeStatus `json:"nodes"`
}

type NodeStatus struct {
	Name       string  `json:"name"`
	CPUPercent float64 `json:"cpu_percent"`
	MemPercent float64 `json:"mem_percent"`
}

// Poller periodically queries Prometheus and broadcasts status updates.
type Poller struct {
	client      *http.Client
	cfg         *config.Config
	haClient    *homeassistant.Client
	haEntities  homeassistant.EnclosureEntities
	mu          sync.RWMutex
	status      DashboardStatus
	subscribers map[uint64]chan DashboardStatus
	subMu       sync.Mutex
	nextID      uint64
}

func NewPoller(cfg *config.Config) *Poller {
	p := &Poller{
		client: &http.Client{
			Timeout: 10 * time.Second,
			Transport: &http.Transport{
				MaxIdleConns:    10,
				IdleConnTimeout: 60 * time.Second,
			},
		},
		cfg:         cfg,
		subscribers: make(map[uint64]chan DashboardStatus),
	}

	if cfg.HomeAssistant.URL != "" {
		token := os.Getenv("HOME_ASSISTANT_TOKEN")
		if token != "" {
			p.haClient = homeassistant.New(cfg.HomeAssistant.URL, token)
			p.haEntities = homeassistant.EnclosureEntities{
				Temperature:   cfg.HomeAssistant.Entities.Temperature,
				Humidity:      cfg.HomeAssistant.Entities.Humidity,
				BaskingLamp:   cfg.HomeAssistant.Entities.BaskingLamp,
				AmbientLight:  cfg.HomeAssistant.Entities.AmbientLight,
				CeramicHeater: cfg.HomeAssistant.Entities.CeramicHeater,
			}
		} else {
			slog.Warn("home_assistant.url configured but HOME_ASSISTANT_TOKEN env var not set")
		}
	}

	return p
}

// Subscribe returns a channel that receives status updates.
func (p *Poller) Subscribe() (uint64, <-chan DashboardStatus) {
	p.subMu.Lock()
	defer p.subMu.Unlock()

	id := p.nextID
	p.nextID++
	// Buffer of 1: drop stale updates if client is slow
	ch := make(chan DashboardStatus, 1)
	p.subscribers[id] = ch
	return id, ch
}

// Unsubscribe removes a subscriber.
func (p *Poller) Unsubscribe(id uint64) {
	p.subMu.Lock()
	defer p.subMu.Unlock()

	if ch, ok := p.subscribers[id]; ok {
		close(ch)
		delete(p.subscribers, id)
	}
}

// CurrentStatus returns the most recent dashboard snapshot.
func (p *Poller) CurrentStatus() DashboardStatus {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.status
}

// Run starts the polling loop. Blocks until ctx is cancelled.
func (p *Poller) Run(ctx context.Context) {
	ticker := time.NewTicker(time.Duration(p.cfg.PollIntervalSeconds) * time.Second)
	defer ticker.Stop()

	// Immediate first poll
	p.poll(ctx)

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			p.poll(ctx)
		}
	}
}

func (p *Poller) poll(ctx context.Context) {
	status := DashboardStatus{
		Timestamp:    time.Now(),
		PrometheusUp: true,
	}

	// Query service health and response times concurrently
	type queryResult struct {
		name string
		data []promResult
		err  error
	}

	queries := map[string]string{
		"probe_success":  `probe_success{job=~"blackbox-http|blackbox-https"}`,
		"probe_duration": `probe_duration_seconds{job=~"blackbox-http|blackbox-https"}`,
		"firing_alerts":  `count(ALERTS{alertstate="firing"}) or vector(0)`,
		// Filter to node-level metrics only and deduplicate across PVE API nodes.
		// Each PVE node in the cluster reports all node metrics, so we pick one
		// arbitrary instance's results via a single scrape target.
		"pve_cpu":        `pve_cpu_usage_ratio{job="proxmox-pve",id=~"node/.*"}`,
		"pve_mem_used":   `pve_memory_usage_bytes{job="proxmox-pve",id=~"node/.*"}`,
		"pve_mem_total":  `pve_memory_size_bytes{job="proxmox-pve",id=~"node/.*"}`,
		"disk_worst":     `topk(1, (1 - node_filesystem_avail_bytes{mountpoint="/",job="node-exporter"} / node_filesystem_size_bytes{mountpoint="/",job="node-exporter"}) * 100)`,
	}

	results := make(map[string][]promResult)
	var wg sync.WaitGroup
	var resultMu sync.Mutex

	for name, query := range queries {
		wg.Add(1)
		go func(n, q string) {
			defer wg.Done()
			data, err := p.instantQuery(ctx, q)
			resultMu.Lock()
			defer resultMu.Unlock()
			if err != nil {
				slog.Warn("prometheus query failed", "query", n, "error", err)
				// Mark Prometheus as down only if _all_ queries fail
				return
			}
			results[n] = data
		}(name, query)
	}
	wg.Wait()

	// If no results came back at all, Prometheus is unreachable
	if len(results) == 0 {
		status.PrometheusUp = false
		status.OverallStatus = "critical"
		p.updateAndBroadcast(status)
		return
	}

	// Build service statuses
	probeSuccess := indexByInstance(results["probe_success"])
	probeDuration := indexByInstance(results["probe_duration"])

	for _, svc := range p.cfg.Services {
		ss := ServiceStatus{
			Name:         svc.Name,
			Status:       "unknown",
			ResponseTime: -1,
		}

		if val, ok := probeSuccess[svc.Target]; ok {
			if val == 1 {
				ss.Status = "up"
			} else {
				ss.Status = "down"
			}
		}

		if dur, ok := probeDuration[svc.Target]; ok {
			ss.ResponseTime = dur
			// Upgrade to degraded if up but slow
			if ss.Status == "up" && dur > p.cfg.DegradedThresholdSeconds {
				ss.Status = "degraded"
			}
		}

		status.Services = append(status.Services, ss)
	}

	// Firing alerts
	if alertResults, ok := results["firing_alerts"]; ok && len(alertResults) > 0 {
		status.FiringAlerts = int(parseValue(alertResults[0]))
	}

	// Proxmox node metrics -- keyed by the "id" label (e.g. "node/thinkcentre1")
	// to deduplicate across PVE cluster API nodes.
	pveCPU := indexByLabel(results["pve_cpu"], "id")
	pveMemUsed := indexByLabel(results["pve_mem_used"], "id")
	pveMemTotal := indexByLabel(results["pve_mem_total"], "id")

	var totalCPU, totalMem float64
	var nodeCount int

	for _, node := range p.cfg.ProxmoxNodes {
		ns := NodeStatus{Name: node.Name}

		if cpu, ok := pveCPU[node.ID]; ok {
			ns.CPUPercent = cpu * 100
			totalCPU += ns.CPUPercent
			nodeCount++
		}

		if used, ok := pveMemUsed[node.ID]; ok {
			if total, ok := pveMemTotal[node.ID]; ok && total > 0 {
				ns.MemPercent = (used / total) * 100
				totalMem += ns.MemPercent
			}
		}

		status.ProxmoxSummary.Nodes = append(status.ProxmoxSummary.Nodes, ns)
	}

	if nodeCount > 0 {
		status.ProxmoxSummary.AvgCPUPercent = totalCPU / float64(nodeCount)
		status.ProxmoxSummary.AvgMemoryPercent = totalMem / float64(nodeCount)
	}

	// Worst disk usage
	if diskResults, ok := results["disk_worst"]; ok && len(diskResults) > 0 {
		status.ProxmoxSummary.WorstDiskPercent = parseValue(diskResults[0])
		if inst, ok := diskResults[0].Metric["instance"]; ok {
			status.ProxmoxSummary.WorstDiskNode = inst
		}
	}

	// Derive overall status
	status.OverallStatus = deriveOverallStatus(status)

	// Fetch enclosure data from Home Assistant (non-critical, errors logged internally)
	if p.haClient != nil {
		status.Enclosure = p.haClient.FetchEnclosure(ctx, p.haEntities)
	}

	p.updateAndBroadcast(status)
}

func (p *Poller) updateAndBroadcast(status DashboardStatus) {
	p.mu.Lock()
	p.status = status
	p.mu.Unlock()

	p.subMu.Lock()
	defer p.subMu.Unlock()

	for _, ch := range p.subscribers {
		// Non-blocking send: drop stale value if buffer full
		select {
		case ch <- status:
		default:
			// Drain and replace with fresh data
			select {
			case <-ch:
			default:
			}
			ch <- status
		}
	}
}

// deriveOverallStatus determines cluster health from service states and alerts.
func deriveOverallStatus(s DashboardStatus) string {
	if !s.PrometheusUp {
		return "critical"
	}

	for _, svc := range s.Services {
		if svc.Status == "down" {
			return "critical"
		}
	}

	if s.FiringAlerts > 0 {
		return "critical"
	}

	for _, svc := range s.Services {
		if svc.Status == "degraded" {
			return "degraded"
		}
	}

	return "healthy"
}

// --- Prometheus HTTP API helpers ---

type promResponse struct {
	Status string   `json:"status"`
	Data   promData `json:"data"`
}

type promData struct {
	ResultType string       `json:"resultType"`
	Result     []promResult `json:"result"`
}

type promResult struct {
	Metric map[string]string `json:"metric"`
	Value  []json.RawMessage `json:"value"`
}

// instantQuery executes a PromQL instant query and returns the result vector.
func (p *Poller) instantQuery(ctx context.Context, query string) ([]promResult, error) {
	u := fmt.Sprintf("%s/api/v1/query?query=%s", p.cfg.PrometheusURL, url.QueryEscape(query))

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing query: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	var pr promResponse
	if err := json.NewDecoder(resp.Body).Decode(&pr); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	if pr.Status != "success" {
		return nil, fmt.Errorf("query failed: status=%s", pr.Status)
	}

	return pr.Data.Result, nil
}

// indexByLabel maps a given label's values to their float64 metric values.
// When multiple results share the same label value (e.g. PVE cluster
// deduplication), the last one wins -- this is fine since all values
// for the same node are identical.
func indexByLabel(results []promResult, label string) map[string]float64 {
	m := make(map[string]float64, len(results))
	for _, r := range results {
		if val, ok := r.Metric[label]; ok {
			m[val] = parseValue(r)
		}
	}
	return m
}

// indexByInstance is a convenience wrapper for the common "instance" label.
func indexByInstance(results []promResult) map[string]float64 {
	return indexByLabel(results, "instance")
}

// parseValue extracts the float64 value from a Prometheus result.
// Prometheus returns [timestamp, "value_string"].
func parseValue(r promResult) float64 {
	if len(r.Value) < 2 {
		return 0
	}
	var s string
	if err := json.Unmarshal(r.Value[1], &s); err != nil {
		return 0
	}
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0
	}
	return v
}
