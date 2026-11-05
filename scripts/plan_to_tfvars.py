#!/usr/bin/env python3
"""Convert a saved Terraform/OpenTofu plan JSON using an explicit price mapping."""
import argparse
import json
import math
import sys
from pathlib import Path


def number(value, field):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{field} must be a known number")
    if not math.isfinite(value) or value < 0:
        raise ValueError(f"{field} must be finite and nonnegative")
    return value


def walk(module):
    for resource in module.get("resources", []):
        if resource.get("mode") == "managed":
            yield resource
    for child in module.get("child_modules", []):
        yield from walk(child)


def convert(plan, catalog):
    if not str(plan.get("format_version", "")).startswith("1."):
        raise ValueError("Expected Terraform plan JSON format_version 1.x")
    if "planned_values" not in plan or "resource_changes" not in plan:
        raise ValueError("Expected saved plan JSON, not state JSON")
    if plan.get("errored") or plan.get("complete") is False:
        raise ValueError("Errored or incomplete plans cannot be estimated")
    for field in ("currency", "region", "price_source"):
        if not isinstance(catalog.get(field), str) or not catalog[field].strip():
            raise ValueError(f"catalog.{field} is required")
    mappings = catalog["resources"]
    rates = catalog["rates"]
    ignored = catalog.get("ignored_resources", {})
    if not all(isinstance(value, dict) for value in (mappings, rates, ignored)):
        raise ValueError("resources, rates and ignored_resources must be objects")
    if any(not isinstance(reason, str) or not reason.strip() for reason in ignored.values()):
        raise ValueError("Every ignored resource requires an exclusion reason")
    overlap = set(mappings) & set(ignored)
    if overlap:
        raise ValueError("A resource cannot be both priced and ignored")
    planned_resources = list(walk(plan["planned_values"].get("root_module", {})))
    resources = {r["address"]: r for r in planned_resources}
    if len(resources) != len(planned_resources):
        raise ValueError("Duplicate managed resource addresses in planned_values")
    changes = {
        r["address"]: r for r in plan["resource_changes"] if r.get("mode") == "managed"
    }
    # A managed after-object missing from planned_values must never disappear silently.
    if any(r["change"].get("actions") != ["delete"] and addr not in resources for addr, r in changes.items()):
        raise ValueError("Plan contains managed after-values absent from planned_values")
    missing = set(resources) - set(mappings) - set(ignored)
    stale = (set(mappings) | set(ignored)) - set(resources)
    if missing:
        raise ValueError("Unpriced resource addresses: " + ", ".join(sorted(missing)))
    if stale:
        raise ValueError("Mapping addresses absent from planned values: " + ", ".join(sorted(stale)))
    items = {}
    for address in sorted(mappings):
        components = mappings[address]
        if not isinstance(components, dict) or not components:
            raise ValueError(f"{address} needs at least one charge component")
        for name, component in components.items():
            if not name.strip():
                raise ValueError("Charge component names must not be blank")
            rate = rates[component["rate_key"]]
            unit = rate["unit"]
            if unit not in ("hourly", "monthly", "usage"):
                raise ValueError("Rate unit must be hourly, monthly or usage")
            eligible = rate.get("reserved_eligible", False)
            if not isinstance(eligible, bool):
                raise ValueError("reserved_eligible must be boolean")
            if ("quantity" in component) == ("quantity_path" in component):
                raise ValueError("Provide exactly one of quantity or quantity_path")
            quantity = component.get("quantity")
            if "quantity_path" in component:
                path = component["quantity_path"]
                if not isinstance(path, list) or not path:
                    raise ValueError("quantity_path must be a nonempty array of attribute keys/indexes")
                quantity = resources[address].get("values", {})
                for segment in path:
                    if isinstance(segment, bool) or not isinstance(segment, (str, int)):
                        raise ValueError("quantity_path segments must be string keys or integer indexes")
                    if isinstance(segment, int) and segment < 0:
                        raise ValueError("quantity_path indexes must be nonnegative")
                    quantity = quantity[segment]
            item = {
                "resource_address": address,
                "unit": unit,
                "unit_price": number(rate["unit_price"], "unit_price"),
                "quantity": number(quantity, f"{address}/{name} quantity"),
                "reserved_eligible": eligible,
            }
            if unit == "usage":
                item["monthly_usage"] = number(component.get("monthly_usage"), "monthly_usage")
            elif "monthly_usage" in component:
                raise ValueError("monthly_usage is only valid for usage rates")
            # JSON tuples avoid collisions between address/component delimiters.
            items[json.dumps([address, name], separators=(",", ":"))] = item
    return {field: catalog[field] for field in ("currency", "region", "price_source")} | {"cost_items": items}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", required=True, type=Path)
    parser.add_argument("--catalog", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = convert(json.loads(args.plan.read_text()), json.loads(args.catalog.read_text()))
        print(json.dumps(result, indent=2, allow_nan=False))
        return 0
    except (ValueError, KeyError, TypeError, IndexError, AttributeError, OSError) as exc:
        print(f"Cost mapping failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
