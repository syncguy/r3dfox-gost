# WebRTC on Windows XP SP3 x86 — Current Status

Last updated: 2026-09-23

This document records the exact build/runtime boundary for WebRTC in the Windows XP SP3 x86 line. Keep build success, physical-XP startup, WebRTC core/DataChannel behavior, and media capture/transport as separate evidence levels.

## Scope

- Repository: `syncguy/r3dfox-gost`
- Branch: `agent/winrt-source-poc`
- Browser line: r3dfox / Firefox 153 x86
- Target OS: physical Windows XP SP3 x86
- Workflow: `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`

## 1. First WebRTC-enabled full build — build GREEN, physical XP BLOCKED

The first full XP x86 build with WebRTC compilation enabled is:

- source-under-test: `75b4e8f052fb6fc09c723651938fde18f95af4ea`
- commit: `ci(xp): enable WebRTC in full x86 build`
- Actions run: `35706851492`
- job: `106677750169`
- run result: `completed / success`
- package artifact: `10691966451` (`r3dfox-gost-xp-x32-package`)
- physical-test runtime artifact: `10692226247` (`r3dfox-gost-xp-x32-runtime`)
- diagnostics artifact: `10691613026` (`r3dfox-gost-xp-x32-diagnostics`)

The only intended WebRTC build-policy change at this source was:

`ac_add_options --disable-webrtc` -> `ac_add_options --enable-webrtc`

The full compile/link/package/static XP gates were GREEN.

**Important physical-runtime boundary:** this artifact did **not** successfully start on physical Windows XP. Physical XP startup was blocked before WebRTC runtime testing could begin. Therefore run `35706851492` must never be cited as a WebRTC runtime PASS, `RTCPeerConnection` PASS, DataChannel PASS, or even a browser-startup PASS on XP.

The blocker was in the newly included WebRTC/nICEr path: `dom/media/webrtc/transport/third_party/nICEr/src/net/transport_addr.cpp` used `inet_pton`, which is not available on the Windows XP Winsock surface used by this target. The next commit introduced an XP-local address parser/fallback for this exact path.

Correct conclusion for run `35706851492`:

**WebRTC-enabled full build/package/static XP gates: PASS. Physical Windows XP startup: BLOCKED. WebRTC runtime: NOT TESTED.**

## 2. XP nICEr `inet_pton` fix

The immediately following commit is:

- source: `afee8c9e5ad2da729407ae06cda8d8029895ab06`
- commit: `fix(xp): add nICEr inet_pton fallback`
- relative to `75b4e8f...`: exactly one commit ahead
- production source delta: `dom/media/webrtc/transport/third_party/nICEr/src/net/transport_addr.cpp`

For `MOZ_XP_COMPAT`, this commit adds local IPv4/IPv6 parsing and routes nICEr address conversion through that fallback instead of the unavailable XP `inet_pton` path. Non-XP builds retain the native `inet_pton` calls.

## 3. First physically runnable WebRTC build on XP

The corrected full build is:

- source-under-test: `afee8c9e5ad2da729407ae06cda8d8029895ab06`
- Actions run: `35737946733`
- job: `106779925555`
- run result: `completed / success`
- package artifact: `10707883013` (`r3dfox-gost-xp-x32-package`)
- physical-test runtime artifact: `10707967905` (`r3dfox-gost-xp-x32-runtime`)
- diagnostics artifact: `10707868191` (`r3dfox-gost-xp-x32-diagnostics`)

This build was successfully started on physical Windows XP SP3 x86.

Identity of the physically tested portable tree:

- `application.ini` / `platform.ini` SourceStamp: `afee8c9e5ad2da729407ae06cda8d8029895ab06`
- `r3dfox.exe` SHA-1: `b1e38de25a5212a54833ddcd4ca830318a10467c`
- `xul.dll` SHA-1: `266b8baea04e92d301fb6ffdd5ad87f492c398eb`

## 4. Physical-XP WebRTC runtime evidence for `afee8c9e...`

The following tests were performed in the physically running browser on Windows XP SP3 x86.

### API availability

- `typeof RTCPeerConnection` -> `"function"`
- `typeof navigator.mediaDevices?.getUserMedia` -> `"function"`
- `about:webrtc` is available and reports real PeerConnection instances.

### SDP / ICE gathering

A manually created `RTCPeerConnection` plus `RTCDataChannel` successfully generated an SDP offer and local description containing:

- `m=application ... UDP/DTLS/SCTP webrtc-datachannel`
- SHA-256 DTLS fingerprint
- ICE username fragment/password
- SCTP port 5000
- UDP host ICE candidates on the machine's IPv4 interfaces
- TCP active/passive host ICE candidates
- `a=end-of-candidates`

This proves successful PeerConnection construction, SDP generation and ICE candidate gathering on physical XP.

### Local two-peer DataChannel loopback

Two local `RTCPeerConnection` instances exchanged offer/answer and ICE candidates in the browser. Observed state progression:

- `pc1 ICE: checking`
- `pc2 ICE: checking`
- `pc1 ICE: connected`
- `pc2 ICE: connected`
- `pc1 connection: connected`
- `pc2 connection: connected`
- `dc1 OPEN`
- `dc2 OPEN`
- payload received: `Hello from Windows XP WebRTC`

Current conclusion for source `afee8c9e...` / run `35737946733`:

**Physical Windows XP browser startup: PASS. WebRTC PeerConnection/ICE/DataChannel core: PASS. ICE connectivity: PASS. DTLS/SCTP DataChannel transport and payload transfer: PASS.**

## Evidence boundary

Do not over-promote this result.

- Run `35706851492` is build-only evidence and failed the physical-XP startup boundary.
- Run `35737946733` is the first WebRTC-enabled build in this sequence proven to start on physical XP.
- The local DataChannel loopback proves WebRTC core transport through ICE + DTLS + SCTP inside the physical XP browser, but does not prove NAT traversal through STUN/TURN or an external peer.
- Audio/video media capture and RTP/RTCP codec paths remain separate tests.
- `getUserMedia` API presence alone is not camera/microphone runtime proof.
- H.264/VP9/AV1 capability exposure is not proof of successful encode/decode or RTP media transport on XP.

## Artifact-selection rule

Artifact names repeat between workflow runs. The internal portable package name (`r3dfox-v153.0.3.win32.portable`) is also reused. Never identify an XP test build by filename alone.

Always record at minimum:

`run -> source SHA -> artifact ID -> SourceStamp -> binary hashes`

For the current WebRTC physical-runtime evidence, the canonical identity is:

- run `35737946733`
- source `afee8c9e5ad2da729407ae06cda8d8029895ab06`
- physical-test runtime artifact `10707967905`
- `r3dfox.exe` SHA-1 `b1e38de25a5212a54833ddcd4ca830318a10467c`
- `xul.dll` SHA-1 `266b8baea04e92d301fb6ffdd5ad87f492c398eb`
