#!/usr/bin/env python3
"""Generate the NextSession custom-client signing keypair (ed25519).

The PUBLIC key is compiled into the client (the `KEY` constant in
src/common.rs) and used to verify custom.txt. The PRIVATE seed signs
custom.txt (see make_custom.py) and MUST be kept secret — store it in a
podman secret / vault, never commit it.

Compatible with RustDesk's verifier: hbb_common uses sodiumoxide 0.2
crypto::sign (ed25519); sign::verify expects a combined signature||message
blob and a 32-byte public key, base64 (standard alphabet). PyNaCl ed25519
produces byte-identical output.

Usage:
    python3 branding/gen_keys.py            # refuses to overwrite an existing key
    python3 branding/gen_keys.py --force    # overwrite (rotates the key!)
"""
import base64
import os
import sys

from nacl.signing import SigningKey

HERE = os.path.dirname(os.path.abspath(__file__))
SECRETS = os.path.join(HERE, "secrets")
PRIV_PATH = os.path.join(SECRETS, "nextsession_signing.key")  # gitignored
PUB_PATH = os.path.join(HERE, "signing_pubkey.txt")           # safe to commit


def main() -> int:
    force = "--force" in sys.argv[1:]
    if os.path.exists(PRIV_PATH) and not force:
        print(f"refusing to overwrite existing key at {PRIV_PATH} (use --force to rotate)")
        return 1

    os.makedirs(SECRETS, exist_ok=True)
    sk = SigningKey.generate()
    seed_b64 = base64.standard_b64encode(bytes(sk)).decode()
    pub_b64 = base64.standard_b64encode(bytes(sk.verify_key)).decode()

    fd = os.open(PRIV_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(seed_b64 + "\n")
    with open(PUB_PATH, "w") as f:
        f.write(pub_b64 + "\n")

    print("Generated NextSession signing keypair.")
    print(f"  private seed -> {PRIV_PATH} (mode 600, gitignored — back this up securely)")
    print(f"  public key   -> {PUB_PATH}")
    print()
    print("Paste this PUBLIC key into the KEY constant in src/common.rs:")
    print(f"  {pub_b64}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
