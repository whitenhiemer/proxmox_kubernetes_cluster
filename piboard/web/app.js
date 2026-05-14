// Piboard dashboard client.
// Connects to /api/status via SSE and renders service health tiles.
(function () {
    "use strict";

    var eventSource = null;
    var reconnectDelay = 1000;
    var MAX_RECONNECT_DELAY = 30000;

    var statusDot = document.getElementById("status-dot");
    var statusText = document.getElementById("status-text");
    var timestampEl = document.getElementById("timestamp");
    var serviceGrid = document.getElementById("service-grid");
    var alertsCount = document.getElementById("alerts-count");
    var cpuSummary = document.getElementById("cpu-summary");
    var memSummary = document.getElementById("mem-summary");
    var diskSummary = document.getElementById("disk-summary");
    var connectionLost = document.getElementById("connection-lost");
    var encTemp = document.getElementById("enc-temp");
    var encHum = document.getElementById("enc-hum");
    var encBasking = document.getElementById("enc-basking");
    var encAmbient = document.getElementById("enc-ambient");
    var encHeater = document.getElementById("enc-heater");

    function connect() {
        if (eventSource) {
            eventSource.close();
        }

        eventSource = new EventSource("/api/status");

        eventSource.onopen = function () {
            reconnectDelay = 1000;
            connectionLost.className = "";
        };

        eventSource.onmessage = function (event) {
            try {
                var data = JSON.parse(event.data);
                render(data);
            } catch (e) {
                console.error("failed to parse SSE data:", e);
            }
        };

        eventSource.onerror = function () {
            eventSource.close();
            eventSource = null;
            connectionLost.className = "visible";

            setTimeout(connect, reconnectDelay);
            reconnectDelay = Math.min(reconnectDelay * 2, MAX_RECONNECT_DELAY);
        };
    }

    function render(data) {
        // Top bar
        statusDot.className = data.overall_status;
        statusText.textContent = formatStatus(data.overall_status, data.prometheus_up);
        timestampEl.textContent = formatTime(data.timestamp);
        timestampEl.className = "";

        // Service grid
        renderServices(data.services);

        // Enclosure bar
        renderEnclosure(data.enclosure);

        // Bottom bar
        renderAlerts(data.firing_alerts);
        renderInfra(data.proxmox_summary);
    }

    function formatStatus(status, prometheusUp) {
        if (!prometheusUp) return "Prometheus Unreachable";
        switch (status) {
            case "healthy":  return "All Systems Operational";
            case "degraded": return "Degraded Performance";
            case "critical": return "System Alert";
            default:         return "Unknown";
        }
    }

    function formatTime(isoString) {
        var d = new Date(isoString);
        return d.toLocaleTimeString("en-US", {
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit",
            hour12: false
        });
    }

    // Create a single service tile using safe DOM methods
    function createTile(index) {
        var tile = document.createElement("div");
        tile.className = "service-tile";
        tile.id = "svc-" + index;

        var dot = document.createElement("div");
        dot.className = "service-status-dot";
        tile.appendChild(dot);

        var name = document.createElement("div");
        name.className = "service-name";
        tile.appendChild(name);

        var rt = document.createElement("div");
        rt.className = "service-response-time";
        tile.appendChild(rt);

        return tile;
    }

    function renderServices(services) {
        if (!services) return;

        // Rebuild tiles if count changed
        if (serviceGrid.children.length !== services.length) {
            while (serviceGrid.firstChild) {
                serviceGrid.removeChild(serviceGrid.firstChild);
            }
            for (var i = 0; i < services.length; i++) {
                serviceGrid.appendChild(createTile(i));
            }
        }

        for (var j = 0; j < services.length; j++) {
            var svc = services[j];
            var el = document.getElementById("svc-" + j);
            el.className = "service-tile " + svc.status;
            el.querySelector(".service-status-dot").className = "service-status-dot " + svc.status;
            el.querySelector(".service-name").textContent = svc.name;
            el.querySelector(".service-response-time").textContent =
                svc.response_time >= 0 ? svc.response_time.toFixed(2) + "s" : "--";
        }
    }

    function renderEnclosure(enc) {
        if (!enc || !enc.available) {
            encTemp.textContent = "TEMP: --°F";
            encHum.textContent = "HUM: --%";
            encBasking.className = "enc-dot unavailable";
            encAmbient.className = "enc-dot unavailable";
            encHeater.className = "enc-dot unavailable";
            return;
        }
        encTemp.textContent = "TEMP: " + enc.temperature.toFixed(1) + "°F";
        encHum.textContent = "HUM: " + enc.humidity.toFixed(0) + "%";
        encBasking.className = "enc-dot " + (enc.basking_lamp ? "on" : "off");
        encAmbient.className = "enc-dot " + (enc.ambient_light ? "on" : "off");
        encHeater.className = "enc-dot " + (enc.ceramic_heater ? "on" : "off");
    }

    function renderAlerts(count) {
        if (count === undefined || count === null) count = 0;
        alertsCount.textContent = count + (count === 1 ? " alert" : " alerts");
        alertsCount.className = count > 0 ? "firing" : "";
    }

    function renderInfra(summary) {
        if (!summary) return;
        cpuSummary.textContent = "CPU: " + summary.avg_cpu_percent.toFixed(0) + "%";
        memSummary.textContent = "MEM: " + summary.avg_memory_percent.toFixed(0) + "%";

        var diskText = "DISK: " + summary.worst_disk_percent.toFixed(0) + "%";
        if (summary.worst_disk_node) {
            diskText += " (" + summary.worst_disk_node + ")";
        }
        diskSummary.textContent = diskText;
    }

    connect();
})();
