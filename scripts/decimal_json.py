"""JSON numbers retain decimal precision through parsing and serialization."""
import json
from decimal import Decimal


def loads(text):
    def invalid_constant(value):
        raise ValueError(f"Nonfinite JSON number: {value}")

    return json.loads(text, parse_float=Decimal, parse_constant=invalid_constant)


def dumps(value):
    """Write Decimal values as JSON numbers, never strings or binary floats."""
    if isinstance(value, Decimal):
        if not value.is_finite():
            raise ValueError("Nonfinite JSON number")
        return str(value)
    if isinstance(value, dict):
        return "{" + ",".join(
            json.dumps(key) + ":" + dumps(item) for key, item in value.items()
        ) + "}"
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(dumps(item) for item in value) + "]"
    return json.dumps(value, allow_nan=False)
