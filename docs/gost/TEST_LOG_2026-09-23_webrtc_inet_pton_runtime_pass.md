# 2026-09-23 — XP WebRTC `inet_pton` loader blocker physically closed

Track: Windows XP SP3 x86 compatibility / WebRTC startup boundary. Independent of GOST TLS handshake behavior and independent of clean `win-153-xp` release acceptance.

## Exact build identity

- implementation branch: `agent/winrt-source-poc`;
- source-under-test / Actions head SHA: `afee8c9e5ad2da729407ae06cda8d8029895ab06` (`fix(xp): add nICEr inet_pton fallback`);
- workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run: `35737946733`;
- job: `106779925555` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate result: **completed / success / GREEN**;
- package artifact `10707883013`, digest `sha256:3c0c130432521825a4c5961fe5c0f2b390b6a8f70731e32d4a8440477581d995`;
- runtime artifact `10707967905`, digest `sha256:39c55c4b6904a1f1fb5fad1c829da670a356c532e4aeb0ca08068338b7428ac2`;
- diagnostics artifact `10707868191`, digest `sha256:c4f3951d2358c4ef530013bedb3abc8e2d7368a4bdcc1981eb866441f9d136f5`.

The run completed every build/package/static step successfully, including the then-current broad XP PE/direct-import audit, runtime archive construction and all artifact uploads.

## Predecessor boundary and remediation

The first WebRTC-enabled source `75b4e8f052fb6fc09c723651938fde18f95af4ea`, run `35706851492`, job `106677750169`, built successfully but physically failed during XP loader resolution because `xul.dll` directly imported unavailable `WS2_32.dll!inet_pton`.

Matching diagnostics and `xul.pdb` localized both direct references to `nr_str_port_to_transport_addr()` in `dom/media/webrtc/transport/third_party/nICEr/src/net/transport_addr.cpp`.

Source `afee8c9e...` applies the narrow source-level remediation: under `MOZ_XP_COMPAT`, nICEr uses a local copy of the proven IPv4/IPv6 parser from the libwebrtc Windows implementation; non-XP builds retain native `inet_pton`.

## Physical Windows XP result

The user physically launched the browser from the build lineage above on Windows XP and confirmed that the previous missing-entry-point dialog no longer appears and the browser starts successfully.

User-reported local SHA-1 identities:

- `r3dfox.exe`: `b1e38de25a5212a54833ddcd4ca830318a10467c`;
- `xul.dll`: `266b8baea04e92d301fb6ffdd5ad87f492c398eb`.

These same local hashes had appeared in an earlier 2026-09-23 Page Info/runtime smoke whose clean-release CI provenance was unresolved. The current report identifies that pair with this later WebRTC/GOST implementation build rather than release candidate `win-153-xp @ 85863f23...`. Artifact-side rehash of run `35737946733` against the supplied local SHA-1 pair remains desirable before calling the pair independently artifact-correlated; the current association is user-reported.

Conclusion: **PHYSICAL XP STARTUP ADVANCES PAST THE nICEr `WS2_32!inet_pton` LOADER BLOCKER.** The blocker is closed for source `afee8c9e...` and the user-associated run `35737946733` binaries.

Evidence boundary: this is not yet a functional WebRTC PASS. `RTCPeerConnection`, `navigator.mediaDevices.getUserMedia`, RTCDataChannel, ICE/STUN, media capture and real-call behavior remain separate runtime tests. It also proves nothing new about GOST TLS handshake behavior.

## Regression gate follow-up

Later implementation commit `1ba6150ca58ea9da341f53374f9bf5dc8d0a4366` adds `inet_pton` to the broad forbidden direct-import audit. It postdates source-under-test `afee8c9e...`, so run `35737946733` did not exercise that hardened regression rule. A later build containing `1ba6150c...` or a successor must prove the permanent import gate.

The intentional duplicate parser remains deferred cleanup. After functional WebRTC runtime is established, extract a neutral shared Windows compatibility helper usable by libwebrtc and nICEr without creating a direct nICEr-to-libwebrtc GN/GYP dependency.

Status: **build/package/static GREEN + physical XP startup PASS past the former `inet_pton` boundary; WebRTC functionality still open.**
