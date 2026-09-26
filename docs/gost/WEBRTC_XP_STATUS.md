# WebRTC on Windows XP SP3 x86 — Current Status

Last updated: 2026-09-23

This document records the exact build/runtime boundary for WebRTC in the Windows XP SP3 x86 line. Canonical documentation lives on `agent/gost-tls-poc`; the tested implementation source remains on `agent/winrt-source-poc`. Keep build success, physical-XP startup, WebRTC core/DataChannel behavior, media capture/transport, codec execution, and NAT-discovery evidence as separate evidence levels.

**Publication/privacy rule:** raw ICE candidates, local/private addresses, public/NAT-mapped addresses, and ephemeral NAT/ICE ports from physical-host testing are intentionally not recorded in this repository. Network evidence is documented only by candidate type, transport role, and PASS/NOT TESTED status.

## Scope

- Repository: `syncguy/r3dfox-gost`
- Canonical documentation branch: `agent/gost-tls-poc`
- Tested implementation branch: `agent/winrt-source-poc`
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
- package artifact: `10691966451` (`r3dfox-gost-xp-x32-package`), SHA-256 `465d2458f93e142bb544b744b8d9c3f40e343525af35248cea619aa776e7185e`
- physical-test runtime artifact: `10692226247` (`r3dfox-gost-xp-x32-runtime`), SHA-256 `a84d42c5111a99c1fff2e60e2f7b237471396ee8e5ede2ead7e12ce32e72e85e`
- diagnostics artifact: `10691613026` (`r3dfox-gost-xp-x32-diagnostics`), SHA-256 `5dc5249923c52fc8f0010b3e93b4830d87f4ea8aa87d8cdffaaa1b7c62380b43`

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
- package artifact: `10707883013` (`r3dfox-gost-xp-x32-package`), SHA-256 `3c0c130432521825a4c5961fe5c0f2b390b6a8f70731e32d4a8440477581d995`
- physical-test runtime artifact: `10707967905` (`r3dfox-gost-xp-x32-runtime`), SHA-256 `39c55c4b6904a1f1fb5fad1c829da670a356c532e4aeb0ca08068338b7428ac2`
- diagnostics artifact: `10707868191` (`r3dfox-gost-xp-x32-diagnostics`), SHA-256 `c4f3951d2358c4ef530013bedb3abc8e2d7368a4bdcc1981eb866441f9d136f5`

This build was successfully started on physical Windows XP SP3 x86.

Identity of the physically tested portable tree:

- `application.ini`: `BuildID=20260922143445`
- `platform.ini`: `BuildID=20260922164908`
- `application.ini` / `platform.ini` SourceStamp: `afee8c9e5ad2da729407ae06cda8d8029895ab06`
- `r3dfox.exe` SHA-1: `b1e38de25a5212a54833ddcd4ca830318a10467c`
- `xul.dll` SHA-1: `266b8baea04e92d301fb6ffdd5ad87f492c398eb`

## 4. Physical-XP WebRTC runtime evidence for `afee8c9e...`

The following tests were performed in the physically running browser on Windows XP SP3 x86.

### 4.1 API availability

- `typeof RTCPeerConnection` -> `"function"`
- `typeof navigator.mediaDevices?.getUserMedia` -> `"function"`
- `about:webrtc` is available and reports real PeerConnection instances.

**Result: PASS.**

### 4.2 SDP and codec advertisement

An offer created with audio and video transceivers advertised:

Audio:

- Opus (`audio/opus`, 48 kHz, 2 channels)
- G.722
- PCMU
- PCMA
- telephone-event

Video:

- VP8
- VP9
- AV1
- RTX
- RED / ULPFEC

The tested offer did **not** advertise H.264. Therefore H.264 must not be claimed as a runtime-supported codec from this test, even though the media capability context exposed `hasH264Hardware: true`.

Other observed media-context capability/configuration values included AV1 enabled, VP9 enabled but not preferred, video frame-rate limit 60, REMB enabled, transport-cc enabled, audio FEC enabled, and RED/ULPFEC enabled.

**Result: SDP media negotiation surface PASS; H.264 runtime proof NOT PRESENT.**

### 4.3 Local ICE gathering and DataChannel transport

A manually created `RTCPeerConnection` plus `RTCDataChannel` successfully generated an SDP offer and local description containing UDP/DTLS/SCTP, SHA-256 DTLS fingerprint, ICE credentials, SCTP port, UDP/TCP host candidates and end-of-candidates.

Two local `RTCPeerConnection` instances then exchanged offer/answer and ICE candidates. Both ICE and PeerConnection states reached `connected`; both DataChannels reached OPEN; application payload was delivered to the receiving channel.

**Result: PeerConnection PASS; ICE local connectivity PASS; DTLS PASS; SCTP/DataChannel PASS; payload transfer PASS.**

### 4.4 Physical media-device boundary

The physical XP test host has no camera and no microphone. `enumerateDevices()` returned an empty device list; real audio/video `getUserMedia` returned `NotFoundError`.

These are expected results for this hardware configuration and are not treated as WebRTC failures.

**Result: real camera/microphone capture NOT TESTABLE on this host.**

### 4.5 Fake media capture

With `media.navigator.streams.fake = true`, `getUserMedia` successfully produced live fake audio and video tracks, including combined A/V.

**Result: fake audio capture PASS; fake video capture PASS; combined A/V capture PASS.**

### 4.6 Local RTP media negotiation and connection

The fake audio/video tracks were attached to a sender PeerConnection and negotiated to a second local PeerConnection. Sender and receiver ICE/connection states reached `connected`.

**Result: media PeerConnection negotiation/connection PASS.**

### 4.7 Opus / VP8 runtime

Sender-side stats proved active `audio/opus` and `video/VP8` outbound RTP. Receiver-side stats proved active `audio/opus` and `video/VP8` inbound RTP. A sampled VP8 decode snapshot reported `framesReceived=17335`, `framesDecoded=17334`, `framesDropped=0`; receiver audio/video tracks remained live.

**Result: Opus send/receive/decode PASS; VP8 encode/send/receive/decode PASS.**

### 4.8 External STUN / server-reflexive candidate gathering

Cloudflare STUN on UDP/3478 and Yandex `stun.rtc.yandex.net` on UDP/3478 produced server-reflexive (`typ srflx`) candidates. Raw addresses and ports are intentionally omitted.

**Result: external STUN PASS; server-reflexive candidate gathering PASS; UDP NAT discovery PASS.**

### 4.9 Forced VP9 runtime

The same physical XP browser session forced VP9 for a fake-video local PeerConnection. `RTCRtpSender.getCapabilities("video")` exposed `video/VP9`; `getStats()` then proved actual VP9 execution rather than advertisement only.

Outbound snapshot:

- codec: `video/VP9`
- `packetsSent=6546`
- `framesEncoded=3359`

Inbound snapshot:

- codec: `video/VP9`
- `packetsReceived=9928`
- `framesDecoded=5049`
- `framesDropped=0`

**Result: VP9 encode/send/receive/decode PASS on physical XP.**

### 4.10 Environmental and remaining boundaries

- Physical camera/microphone: **NOT TESTABLE on this host** because the test machine has neither device.
- IPv6 ICE: **NOT TESTABLE on this host** because IPv6 is not available on the test machine.
- H.264 runtime: **NOT PROVEN**; H.264 was absent from the tested SDP.
- AV1 runtime encode/decode: **NOT TESTED**.
- TURN/relay: **NOT TESTED**; no controlled TURN credentials were used.
- External remote peer session: **NOT TESTED**.

## 5. Current evidence summary

For source `afee8c9e5ad2da729407ae06cda8d8029895ab06` / run `35737946733` on physical Windows XP SP3 x86:

| Area | Result |
| --- | --- |
| Physical XP browser startup | PASS |
| `RTCPeerConnection` API | PASS |
| ICE host gathering / local connectivity | PASS |
| DTLS | PASS |
| SCTP / DataChannel payload | PASS |
| Real camera/microphone capture | NOT TESTABLE on this host |
| Fake audio/video capture | PASS |
| Audio/video media negotiation | PASS |
| Opus send/receive/decode | PASS |
| VP8 encode/send/receive/decode | PASS |
| VP9 encode/send/receive/decode | PASS |
| External STUN / `srflx` / UDP NAT discovery | PASS |
| H.264 runtime | NOT PROVEN / not advertised in tested SDP |
| AV1 runtime encode/decode | NOT TESTED |
| IPv6 ICE | NOT TESTABLE on this host |
| TURN/relay | NOT TESTED |
| External remote peer | NOT TESTED |

## 6. Evidence boundary

- Run `35706851492` is build-only evidence and failed the physical-XP startup boundary.
- Run `35737946733` is the first WebRTC-enabled build in this sequence proven to start and execute WebRTC on physical XP.
- Local tests prove ICE + DTLS + SCTP/DataChannel and real RTP execution for Opus, VP8 and forced VP9.
- Successful external `srflx` gathering proves STUN/NAT discovery, not TURN relay and not a complete external peer session.
- Physical-device and IPv6 coverage are environmental exclusions on this host, not browser failures.
- H.264 capability exposure is not runtime proof; H.264 was absent from the tested SDP.

## 7. Artifact-selection rule

Artifact names repeat between workflow runs. Never identify an XP test build by filename alone.

Always record at minimum:

`run -> source SHA -> artifact ID -> SourceStamp -> binary hashes`

For the current WebRTC physical-runtime evidence, the canonical identity is:

- run `35737946733`
- source `afee8c9e5ad2da729407ae06cda8d8029895ab06`
- physical-test runtime artifact `10707967905`
- `application.ini` BuildID `20260922143445`
- `platform.ini` BuildID `20260922164908`
- `r3dfox.exe` SHA-1 `b1e38de25a5212a54833ddcd4ca830318a10467c`
- `xul.dll` SHA-1 `266b8baea04e92d301fb6ffdd5ad87f492c398eb`
