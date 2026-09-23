# WebRTC on Windows XP SP3 x86 — Current Status

Last updated: 2026-09-23

This document records the exact build/runtime boundary for WebRTC in the Windows XP SP3 x86 line. Keep build success, physical-XP startup, WebRTC core/DataChannel behavior, media capture/transport, codec execution, and NAT-discovery evidence as separate evidence levels.

**Publication/privacy rule:** raw ICE candidates, local/private addresses, public/NAT-mapped addresses, and ephemeral NAT/ICE ports from physical-host testing are intentionally not recorded in this repository. Network evidence is documented only by candidate type, transport role, and PASS/NOT TESTED status.

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

A manually created `RTCPeerConnection` plus `RTCDataChannel` successfully generated an SDP offer and local description containing:

- `m=application ... UDP/DTLS/SCTP webrtc-datachannel`
- SHA-256 DTLS fingerprint
- ICE username fragment/password
- SCTP port 5000
- UDP host ICE candidates on both available IPv4 interfaces
- TCP active/passive host ICE candidates
- end-of-candidates

Raw candidate addresses and ports are deliberately omitted from published documentation.

Two local `RTCPeerConnection` instances then exchanged offer/answer and ICE candidates. Observed behavior:

- both ICE states reached `connected`;
- both PeerConnection `connectionState` values reached `connected`;
- both DataChannels reached OPEN;
- application payload `Hello from Windows XP WebRTC` was delivered to the receiving channel.

**Result: PeerConnection PASS; ICE local connectivity PASS; DTLS PASS; SCTP/DataChannel PASS; payload transfer PASS.**

### 4.4 Physical media-device boundary

The physical XP test host has no camera and no microphone.

Observed with real-device capture:

- `enumerateDevices()` returned an empty device list;
- real audio `getUserMedia` returned `NotFoundError`;
- real video `getUserMedia` returned `NotFoundError`.

These are **EXPECTED** results for this hardware configuration and are not treated as WebRTC failures.

**Result: real camera/microphone capture NOT TESTABLE on this host.**

### 4.5 Fake media capture

With:

`media.navigator.streams.fake = true`

`getUserMedia` successfully produced:

- one audio `MediaStreamTrack`, label `Default Audio Device`;
- one video `MediaStreamTrack`, label `Default Video Device`;
- combined audio+video stream with both tracks in `readyState="live"`.

**Result: fake audio capture PASS; fake video capture PASS; combined A/V capture PASS.**

### 4.6 Local RTP media negotiation and connection

The fake audio/video tracks were attached to a sender PeerConnection and negotiated to a second local PeerConnection.

After offer/answer exchange:

- sender ICE state: `connected`;
- sender connection state: `connected`;
- receiver ICE state: `connected`;
- receiver connection state: `connected`.

**Result: media PeerConnection negotiation/connection PASS.**

### 4.7 Outbound RTP and actual sender codecs

A sender-side stats snapshot reported:

- audio: `packetsSent=2761`, `bytesSent=444681`;
- video: `packetsSent=2855`, `bytesSent=2110323`.

Codec stats resolved the active outbound codecs as:

- audio: `audio/opus`, 48 kHz, 2 channels;
- video: `video/VP8`, 90 kHz RTP clock.

**Result: Opus sender/encode path PASS; VP8 sender/encode path PASS; outbound RTP PASS.**

### 4.8 Inbound RTP and actual receiver codecs

A receiver-side stats snapshot reported:

- audio: `packetsReceived=26197`, `bytesReceived=4217877`;
- video: `packetsReceived=21735`, `bytesReceived=18129438`.

Codec stats resolved the active inbound codecs as:

- audio: `audio/opus`, 48 kHz, 2 channels;
- video: `video/VP8`, 90 kHz RTP clock.

A later audio snapshot reported:

- `packetsReceived=28951`;
- `packetsLost=0`;
- `concealedSamples=1920`;
- `silentConcealedSamples=0`.

A later video decode snapshot reported:

- `framesReceived=17335`;
- `framesDecoded=17334`;
- `framesDropped=0`.

The receiver also exposed two active tracks:

- audio: `readyState="live"`, `enabled=true`, `muted=false`;
- video: `readyState="live"`, `enabled=true`, `muted=false`.

**Result: inbound RTP PASS; Opus receive/decode path PASS; VP8 receive/decode path PASS; live remote audio/video tracks PASS.**

### 4.9 External STUN / server-reflexive candidate gathering

External STUN tests were performed without publishing raw ICE candidates.

Observed:

- Cloudflare STUN on UDP/3478 produced a `typ srflx` candidate;
- Yandex `stun.rtc.yandex.net` on UDP/3478 produced a `typ srflx` candidate;
- Yandex on port 443 did not produce a `srflx` candidate in this environment;
- a Google public STUN test did not produce a `srflx` candidate in this environment.

The unsuccessful individual endpoints are not treated as browser failures because public STUN reachability can be affected by network/operator filtering. The successful `srflx` results prove that the XP WebRTC stack can perform external STUN transaction/NAT discovery and gather a server-reflexive candidate.

No local/private address, public/NAT-mapped address, or ephemeral candidate/NAT port is retained in this document.

**Result: external STUN PASS; server-reflexive candidate gathering PASS; UDP NAT discovery PASS.**

### 4.10 IPv6 and TURN boundaries

- IPv6 was not tested because the physical XP host does not have IPv6 available.
- TURN/relay was not tested because no controlled TURN credentials were used.
- External peer-to-peer media connectivity was not tested; successful STUN gathering alone is not equivalent to a full Internet peer connection.

**Result: IPv6 NOT TESTED; TURN NOT TESTED; external remote peer NOT TESTED.**

## 5. Current evidence summary

For source `afee8c9e5ad2da729407ae06cda8d8029895ab06` / run `35737946733` on physical Windows XP SP3 x86:

| Area | Result |
| --- | --- |
| Physical XP browser startup | PASS |
| `RTCPeerConnection` API | PASS |
| ICE host gathering | PASS |
| Local ICE connectivity | PASS |
| DTLS | PASS |
| SCTP / DataChannel | PASS |
| DataChannel payload transfer | PASS |
| Real camera/microphone capture | NOT TESTABLE on this host |
| Fake audio capture | PASS |
| Fake video capture | PASS |
| Audio/video media negotiation | PASS |
| Outbound RTP | PASS |
| Inbound RTP | PASS |
| Opus send/receive/decode | PASS |
| VP8 send/receive/decode | PASS |
| Video frame decode | PASS (`17334` decoded, `0` dropped in sampled stats) |
| Live remote audio/video tracks | PASS |
| External STUN | PASS |
| `srflx` candidate gathering | PASS |
| UDP NAT discovery | PASS |
| H.264 runtime | NOT PROVEN / not advertised in tested SDP |
| VP9 runtime encode/decode | NOT TESTED |
| AV1 runtime encode/decode | NOT TESTED |
| IPv6 | NOT TESTED (not available on host) |
| TURN/relay | NOT TESTED |
| External remote peer | NOT TESTED |

## 6. Evidence boundary

Do not over-promote this result.

- Run `35706851492` is build-only evidence and failed the physical-XP startup boundary.
- Run `35737946733` is the first WebRTC-enabled build in this sequence proven to start and execute WebRTC on physical XP.
- Local DataChannel tests prove WebRTC core transport through ICE + DTLS + SCTP inside the physical XP browser.
- Local fake-media tests prove actual Opus and VP8 RTP send/receive paths, including VP8 frame decoding, but do not substitute for physical camera/microphone capture.
- Successful external `srflx` gathering proves STUN/NAT discovery, not TURN relay and not a complete external peer session.
- H.264 capability exposure is not runtime proof; H.264 was absent from the tested SDP.
- VP9 and AV1 were advertised but were not selected for the executed media session.

## 7. Artifact-selection rule

Artifact names repeat between workflow runs. The internal portable package name (`r3dfox-v153.0.3.win32.portable`) is also reused. Never identify an XP test build by filename alone.

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
