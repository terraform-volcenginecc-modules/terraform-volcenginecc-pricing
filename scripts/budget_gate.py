#!/usr/bin/env python3
"""Read the complete example's saved estimate plan JSON; emit an event and gate CI."""
import argparse
import json
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    args = parser.parse_args()
    try:
        plan = json.loads(args.plan.read_text())
        if plan.get("errored") or plan.get("complete") is False:
            raise ValueError("Estimate plan is errored or incomplete")
        output = plan["planned_values"]["outputs"]["alert_payload"]
        payload = output["value"]
        if output.get("sensitive") or not isinstance(payload.get("exceeded"), bool):
            raise ValueError("Alert must be known and nonsensitive")
        print(json.dumps(payload, allow_nan=False))
        return 2 if payload["exceeded"] else 0
    except (ValueError, KeyError, TypeError, AttributeError, OSError) as exc:
        print(f"Budget evaluation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
