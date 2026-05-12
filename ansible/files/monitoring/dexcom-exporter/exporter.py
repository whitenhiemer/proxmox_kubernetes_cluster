#!/usr/bin/env python3
# Dexcom glucose Prometheus exporter
#
# Polls the Dexcom Share/Follow API and exposes glucose readings
# as Prometheus metrics on :9666/metrics.

import os
import sys
import time
import logging
from prometheus_client import start_http_server, Gauge, Enum, Info

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("dexcom-exporter")

# Trend arrow mappings from pydexcom
TREND_LABELS = {
    0: "none",
    1: "double_up",
    2: "single_up",
    3: "forty_five_up",
    4: "flat",
    5: "forty_five_down",
    6: "single_down",
    7: "double_down",
    8: "not_computable",
    9: "out_of_range",
}

# Prometheus metrics
glucose_mgdl = Gauge(
    "dexcom_glucose_mgdl",
    "Current glucose reading in mg/dL",
)
glucose_mmol = Gauge(
    "dexcom_glucose_mmol",
    "Current glucose reading in mmol/L",
)
glucose_trend = Gauge(
    "dexcom_glucose_trend",
    "Glucose trend direction (1=double_up, 4=flat, 7=double_down)",
)
glucose_trend_label = Enum(
    "dexcom_glucose_trend_direction",
    "Glucose trend as a human-readable label",
    states=list(TREND_LABELS.values()),
)
reading_timestamp = Gauge(
    "dexcom_reading_timestamp_seconds",
    "Unix timestamp of the most recent glucose reading",
)
exporter_errors = Gauge(
    "dexcom_exporter_errors_total",
    "Total number of consecutive API errors",
)
exporter_info = Info(
    "dexcom_exporter",
    "Exporter metadata",
)


def poll_dexcom(dexcom):
    """Fetch the latest glucose reading and update Prometheus metrics."""
    try:
        reading = dexcom.get_current_glucose_reading()
        if reading is None:
            log.warning("No current glucose reading available")
            return

        glucose_mgdl.set(reading.mg_dl)
        glucose_mmol.set(reading.mmol_l)
        glucose_trend.set(reading.trend)
        glucose_trend_label.state(TREND_LABELS.get(reading.trend, "none"))

        # pydexcom returns a datetime; convert to unix timestamp
        ts = reading.datetime.timestamp() if reading.datetime else time.time()
        reading_timestamp.set(ts)

        exporter_errors.set(0)

        trend_name = TREND_LABELS.get(reading.trend, "unknown")
        log.info(
            "Glucose: %d mg/dL (%.1f mmol/L) trend=%s",
            reading.mg_dl,
            reading.mmol_l,
            trend_name,
        )

    except Exception as e:
        log.error("Failed to fetch glucose reading: %s", e)
        exporter_errors.inc()


def main():
    username = os.environ.get("DEXCOM_USERNAME")
    password = os.environ.get("DEXCOM_PASSWORD")
    ous = os.environ.get("DEXCOM_OUS", "false").lower() == "true"
    port = int(os.environ.get("EXPORTER_PORT", "9666"))
    interval = int(os.environ.get("POLL_INTERVAL", "300"))

    if not username or not password:
        log.error("DEXCOM_USERNAME and DEXCOM_PASSWORD environment variables are required")
        sys.exit(1)

    exporter_info.info({
        "version": "1.0.0",
        "poll_interval_seconds": str(interval),
        "region": "ous" if ous else "us",
    })

    from pydexcom import Dexcom, Region

    region = Region.OUS if ous else Region.US

    # Start metrics server before auth so /metrics is reachable even when auth fails
    start_http_server(port)
    log.info("Serving metrics on :%d/metrics (poll interval: %ds)", port, interval)

    dexcom = None
    retry_delay = 60

    while True:
        if dexcom is None:
            try:
                log.info("Connecting to Dexcom Share API (region=%s)...", region.value)
                dexcom = Dexcom(username=username, password=password, region=region)
                log.info("Authenticated successfully")
                exporter_errors.set(0)
                retry_delay = 60
            except Exception as e:
                log.error("Authentication failed: %s — retrying in %ds", e, retry_delay)
                exporter_errors.inc()
                time.sleep(retry_delay)
                retry_delay = min(retry_delay * 2, 3600)
                continue

        poll_dexcom(dexcom)
        time.sleep(interval)


if __name__ == "__main__":
    main()
