# Bundled certificate authorities

This directory contains pinned public root CA certificates bundled with r3dfox-gost for portable trust integration.

Current intended trust anchors:

* `russian_trusted_root_ca_rsa.cer` — Russian Trusted Root CA, RSA;
* `russian_trusted_root_ca_gost.cer` — Russian Trusted Root CA, GOST.

Only root CA certificates belong here. Intermediate / Sub CA certificates are intentionally not bundled unless a future runtime test proves they are required.

Certificate files must be taken from an official source and kept byte-for-byte unchanged. Their exact SHA-256 hashes and expected X.509 identities are verified by the project trust-integration CI.

These files are public trust anchors and contain no private keys or credentials.
