#!/usr/bin/env python3
"""Prints "<device type id> <runtime id>" for a simulator device name, picking the newest
iOS runtime that supports it.  Usage: pick_simulator.py "iPhone Duo"
"""
import json
import subprocess
import sys


def simctl(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", *args, "-j"]))


def version_key(runtime):
    return tuple(int(part) for part in runtime.get("version", "0").split(".") if part.isdigit())


def main():
    name = sys.argv[1]
    device_types = simctl("devicetypes")["devicetypes"]
    runtimes = simctl("runtimes")["runtimes"]

    matches = [t for t in device_types if t["name"] == name]
    if not matches:
        sys.exit(f"No device type named '{name}'. Available: " + ", ".join(sorted(t["name"] for t in device_types if "iP" in t["name"])))
    device = matches[0]

    usable = [
        r for r in runtimes
        if r.get("isAvailable") and r.get("platform", "iOS") == "iOS"
        and any(s["identifier"] == device["identifier"] for s in r.get("supportedDeviceTypes", []))
    ]
    if not usable:
        sys.exit(f"No available iOS runtime supports '{name}'")
    runtime = sorted(usable, key=version_key)[-1]
    print(device["identifier"], runtime["identifier"])


if __name__ == "__main__":
    main()
