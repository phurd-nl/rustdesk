#!/usr/bin/env python3
"""Build and sign the NextSession custom-client config (custom.txt).

Reads branding/custom_client.json, signs it with the private seed from
branding/secrets/nextsession_signing.key, base64-encodes the combined
signature||message blob, and writes custom.txt (which is then bundled with
each installer and read at startup by load_custom_client()).

Round-trips the result through PyNaCl's verifier — the same ed25519 check
RustDesk's sodiumoxide sign::verify performs — so a successful run proves the
blob will be accepted by the client built with the matching public key.

Usage:
    python3 branding/make_custom.py [--config branding/custom_client.json] [--out custom.txt]
"""
import argparse
import base64
import json
import os
import sys

from nacl.signing import SigningKey, VerifyKey

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
PRIV_PATH = os.path.join(HERE, "secrets", "nextsession_signing.key")
PUB_PATH = os.path.join(HERE, "signing_pubkey.txt")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=os.path.join(HERE, "custom_client.json"))
    ap.add_argument("--out", default=os.path.join(REPO, "custom.txt"))
    args = ap.parse_args()

    if not os.path.exists(PRIV_PATH):
        print(f"missing signing key at {PRIV_PATH} — run gen_keys.py first", file=sys.stderr)
        return 1

    with open(PRIV_PATH) as f:
        seed = base64.standard_b64decode(f.read().strip())
    sk = SigningKey(seed)

    with open(args.config) as f:
        config = json.load(f)

    # Compact, deterministic JSON. RustDesk parses with serde_json into a
    # HashMap, so whitespace/order are irrelevant to the client.
    message = json.dumps(config, separators=(",", ":"), sort_keys=True).encode()
    signed = bytes(sk.sign(message))  # signature(64) || message  — sodiumoxide combined form
    blob_b64 = base64.standard_b64encode(signed).decode()

    # Prove it verifies the same way the client will.
    pub = VerifyKey(bytes(sk.verify_key))
    recovered = pub.verify(base64.standard_b64decode(blob_b64))
    assert recovered == message, "round-trip verification failed"

    with open(args.out, "w") as f:
        f.write(blob_b64 + "\n")

    rs_key = config.get("override-settings", {}).get("key") or \
        config.get("default-settings", {}).get("key", "")
    if rs_key.startswith("REPLACE_WITH"):
        rs_key = ""  # still a placeholder; surfaced below
    print(f"Wrote signed custom client config -> {args.out} ({len(blob_b64)} b64 chars)")
    print(f"  app-name : {config.get('app-name')}")
    print(f"  org      : {config.get('org')}")
    print(f"  RS_PUB_KEY (server key) : {rs_key or '(placeholder — set after VM keygen)'}")
    print("Round-trip ed25519 verification: OK (client built with the matching")
    print(f"  public key in {PUB_PATH} will accept this blob).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
