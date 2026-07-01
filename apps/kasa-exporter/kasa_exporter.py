#!/usr/bin/env python3
"""Prometheus exporter for TP-Link Kasa devices, built on python-kasa.

Drop-in replacement for kasa-rs's kasa-prometheus exporter: identical CLI
flags, metric names, and labels (so existing dashboards keep working), while
python-kasa handles every TP-Link protocol variant — legacy XOR, KLAP v1/v2,
and SMART devices like the KP125M — with per-device transport auto-detection.
"""

import argparse
import asyncio
import logging
import os
import sys
import time
from datetime import datetime, timezone

from kasa import Device, Discover
from prometheus_client import Gauge, start_http_server

log = logging.getLogger("kasa_exporter")

DEV = ["alias", "device_id", "ip", "model"]
PLUG = DEV + ["plug_alias", "plug_id", "plug_slot"]

GAUGES = {
    "kasa_device_power_watts": Gauge("kasa_device_power_watts", "Current power draw", DEV),
    "kasa_device_voltage_volts": Gauge("kasa_device_voltage_volts", "Voltage", DEV),
    "kasa_device_current_amps": Gauge("kasa_device_current_amps", "Current draw", DEV),
    "kasa_device_energy_watt_hours_total": Gauge(
        "kasa_device_energy_watt_hours_total", "Total energy consumed", DEV
    ),
    "kasa_device_relay_state": Gauge("kasa_device_relay_state", "Relay on/off", DEV),
    "kasa_device_rssi_dbm": Gauge("kasa_device_rssi_dbm", "WiFi signal strength", DEV),
    "kasa_device_on_time_seconds": Gauge(
        "kasa_device_on_time_seconds", "Seconds since the device turned on", DEV
    ),
    "kasa_device_cloud_connected": Gauge(
        "kasa_device_cloud_connected", "TP-Link cloud connectivity", DEV
    ),
    "kasa_plug_power_watts": Gauge("kasa_plug_power_watts", "Per-plug power draw", PLUG),
    "kasa_plug_voltage_volts": Gauge("kasa_plug_voltage_volts", "Per-plug voltage", PLUG),
    "kasa_plug_current_amps": Gauge("kasa_plug_current_amps", "Per-plug current", PLUG),
    "kasa_plug_energy_watt_hours_total": Gauge(
        "kasa_plug_energy_watt_hours_total", "Per-plug total energy", PLUG
    ),
    "kasa_plug_relay_state": Gauge("kasa_plug_relay_state", "Per-plug relay on/off", PLUG),
    "kasa_plug_on_time_seconds": Gauge(
        "kasa_plug_on_time_seconds", "Per-plug seconds since turned on", PLUG
    ),
}
DEVICE_INFO = Gauge(
    "kasa_device_info", "Device metadata", DEV + ["mac", "hw_ver", "sw_ver", "device_type"]
)
DEVICES_DISCOVERED = Gauge("kasa_devices_discovered", "Number of devices being polled")
SCRAPE_SUCCESS = Gauge("kasa_scrape_success", "Whether the last poll succeeded", ["ip"])
SCRAPE_DURATION = Gauge("kasa_scrape_duration_seconds", "Duration of the last poll", ["ip"])


def _feature(dev, name):
    feat = dev.features.get(name)
    if feat is None or feat.value is None:
        return None
    return feat.value


def _set(metric, labels, value):
    if value is None:
        return
    if isinstance(value, bool):
        value = 1 if value else 0
    if isinstance(value, datetime):
        value = max(0.0, (datetime.now(timezone.utc) - value).total_seconds())
    GAUGES[metric].labels(**labels).set(value)


def _export_common(prefix, dev, labels):
    _set(f"{prefix}_power_watts", labels, _feature(dev, "current_consumption"))
    _set(f"{prefix}_voltage_volts", labels, _feature(dev, "voltage"))
    _set(f"{prefix}_current_amps", labels, _feature(dev, "current"))
    total_kwh = _feature(dev, "consumption_total")
    if total_kwh is not None:
        _set(f"{prefix}_energy_watt_hours_total", labels, float(total_kwh) * 1000)
    _set(f"{prefix}_relay_state", labels, _feature(dev, "state"))
    _set(f"{prefix}_on_time_seconds", labels, _feature(dev, "on_since"))


def _export(dev: Device, ip: str):
    labels = {
        "alias": dev.alias or ip,
        "device_id": dev.device_id or "",
        "ip": ip,
        "model": dev.model or "",
    }
    _export_common("kasa_device", dev, labels)
    _set("kasa_device_rssi_dbm", labels, _feature(dev, "rssi"))
    _set("kasa_device_cloud_connected", labels, _feature(dev, "cloud_connection"))
    DEVICE_INFO.labels(
        **labels,
        mac=dev.mac or "",
        hw_ver=dev.hw_info.get("hw_ver", "") if dev.hw_info else "",
        sw_ver=dev.hw_info.get("sw_ver", "") if dev.hw_info else "",
        device_type=str(dev.device_type),
    ).set(1)

    for slot, child in enumerate(dev.children):
        plug_labels = {
            **labels,
            "plug_alias": child.alias or f"plug-{slot}",
            "plug_id": child.device_id or "",
            "plug_slot": str(slot),
        }
        _export_common("kasa_plug", child, plug_labels)


async def poll_device(ip: str, username: str | None, password: str | None, devices: dict):
    start = time.monotonic()
    try:
        dev = devices.get(ip)
        if dev is None:
            dev = await Discover.discover_single(ip, username=username, password=password)
            devices[ip] = dev
        await dev.update()
        _export(dev, ip)
        SCRAPE_SUCCESS.labels(ip=ip).set(1)
    except Exception as e:
        # Drop the cached device so the next cycle re-discovers (fresh transport).
        devices.pop(ip, None)
        SCRAPE_SUCCESS.labels(ip=ip).set(0)
        log.warning("failed to poll device target=%s error=%s", ip, e)
    finally:
        SCRAPE_DURATION.labels(ip=ip).set(time.monotonic() - start)


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen", default="0.0.0.0:9101", help="metrics listen address")
    parser.add_argument(
        "--target", action="append", default=[], metavar="IP", help="device IP (repeatable)"
    )
    parser.add_argument("--scrape-interval", type=int, default=15, help="poll interval seconds")
    parser.add_argument("--username", default=os.environ.get("KASA_USERNAME"))
    parser.add_argument("--password", default=os.environ.get("KASA_PASSWORD"))
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    if not args.target:
        log.error("no --target given; discovery-by-broadcast is not supported, exiting")
        sys.exit(1)

    host, _, port = args.listen.rpartition(":")
    start_http_server(int(port), addr=host or "0.0.0.0")
    log.info(
        "starting kasa-exporter listen=%s targets=%s creds=%s",
        args.listen,
        args.target,
        "yes" if args.username and args.password else "no",
    )
    DEVICES_DISCOVERED.set(len(args.target))

    devices: dict[str, Device] = {}
    while True:
        await asyncio.gather(
            *(poll_device(ip, args.username, args.password, devices) for ip in args.target)
        )
        await asyncio.sleep(args.scrape_interval)


if __name__ == "__main__":
    asyncio.run(main())
