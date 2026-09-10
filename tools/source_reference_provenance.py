"""Allow only the reviewed credential removal from protected source references.

This does not permit layout, copy, style, asset or interaction changes. Original
archive bytes stay private and immutable; an unknown embedded token fails closed.
"""
import hashlib
import re

REVIEWED_PUBLIC_TOKEN_SHA256 = "757ab79539c4d7b129d7cd995f4724253e28d6e1a52767b5bcbab10c0b5cbc4a"
PUBLIC_TOKEN = re.compile(rb"pk\.eyJ[A-Za-z0-9_.-]+")
PLACEHOLDER = b"MAPBOX_PUBLIC_TOKEN_REQUIRED"


def publishable_reference_bytes(original: bytes) -> bytes:
    def redact(match):
        if hashlib.sha256(match.group()).hexdigest() != REVIEWED_PUBLIC_TOKEN_SHA256:
            raise ValueError("Unreviewed embedded map credential in original reference")
        return PLACEHOLDER

    return PUBLIC_TOKEN.sub(redact, original)
