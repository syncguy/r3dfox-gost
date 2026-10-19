# Windows XP x86 PROPSYS remediation stage

Last updated: 2026-09-03

This document isolates the `PROPSYS.dll` compatibility problem as a separate Windows XP SP3 x86 remediation stage. It is subordinate to `XP_BUILD_CONTRACT.md` and complements `XP_IMPORT_REMEDIATION.md`. It is independent of GOST TLS runtime/handshake work.

## Evidence identity

The current `PROPSYS.dll` finding comes from the full XP x32 diagnostics associated with:

- experiment branch `agent/winrt-source-poc`;
- source-under-test `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `33638897692`, attempt `1`;
- job `100276666021`;
- diagnostics artifact `9855751471`, digest `sha256:bce0bbdbc778b0114b9d33e670a9bf687e4699cfda7353efebc6b92650f03eed`.

The available `xul.dll` import diagnostics show a hard `PROPSYS.dll` dependency containing at least:

- `VariantCompare`;
- `PropVariantToString`.

Because stock Windows XP does not provide `PROPSYS.dll`, resolving only one symbol is insufficient. The stage is complete only when the final XP `xul.dll` no longer depends on an unavailable `PROPSYS.dll`, or when a deliberately selected and physically proven app-local replacement supplies the exact required ABI and behavior.

## Firefox callers

### `VariantCompare`

Current Firefox source uses `VariantCompare` in:

`accessible/windows/uia/UiaTextRange.cpp`

The local helper `CompareVariants(const VARIANT&, const VARIANT&)` already contains an upstream MinGW fallback. On MinGW it converts both `VARIANT` values to `PROPVARIANT` and calls `PropVariantCompareEx`; on the normal MSVC path it calls `VariantCompare` directly.

This means `VariantCompare` is not intrinsically required by Firefox architecture. There is already an upstream source-level alternative that can be evaluated for the XP build independently of compiler choice.

Important qualification: simply switching the MSVC XP build from `VariantCompare` to `PropVariantCompareEx` does not by itself eliminate `PROPSYS.dll`, because `PropVariantCompareEx` is itself part of the property-system API unless its implementation is also supplied locally or through an app-local replacement.

### `PropVariantToString`

Current Firefox source uses `PropVariantToString` in:

`browser/components/shell/nsWindowsShellService.cpp`

The reviewed source contains four call sites. They occur in Windows shell/taskbar integration while reading stored shortcut property values such as `PKEY_AppUserModel_ID` and converting the returned `PROPVARIANT` to a string for comparison/use.

This is a narrow shell-integration use, not a general browser data-model dependency. On XP the relevant modern AppUserModelID/taskbar integration may be removable or degradable at source level. Before introducing a replacement DLL, determine the exact XP behavior required from these paths and whether they can be compiled out, skipped, or handled with a narrow local conversion for the actual property types encountered.

## One-Core source availability

The project already pins One-Core source for the selected `bcrypt.dll` implementation:

`shorthorn-project/One-Core-API-Source@9eb3c31de9460c1ccce3f6a10c9c4a704f032514`

The same pinned source tree contains a dedicated implementation under:

`oca/dependencies/propsys/`

Relevant files include `propvar.c`, `propstore.c`, `propsys_main.c`, `propsys.spec`, and its build definitions.

At this exact pinned commit:

- `PropVariantToString` is implemented in `oca/dependencies/propsys/propvar.c` and exported by `propsys.spec`;
- `PropVariantCompareEx` is implemented in `propvar.c`;
- exact `VariantCompare` is still marked as a stub in `propsys.spec`.

Therefore One-Core is a useful source of compatible property-system behavior, but the existing pinned `propsys` target cannot yet be assumed to provide the two currently imported Firefox functions as a complete drop-in solution without inspection/modification.

## Candidate solutions, in preferred evaluation order

### A. Remove the hard dependency at Firefox source level

Preferred if practical.

1. Reuse/adapt the existing `UiaTextRange.cpp` comparison fallback so the XP build does not require `VariantCompare`.
2. Trace the four `PropVariantToString` shell call sites and remove/disable the modern shell property path on XP when that functionality has no useful XP equivalent, or provide a narrow local conversion for the actual property type required.
3. Verify that `xul.dll` no longer imports `PROPSYS.dll` at all.

This is the cleanest outcome because it removes an entire unavailable system-DLL dependency rather than emulating it.

### B. Reuse selected One-Core implementation source inside the project

If the Firefox source paths need the semantics but a full `propsys.dll` is unnecessary, evaluate reusing the relevant One-Core implementation code, especially `PropVariantToString` and/or the comparison machinery behind `PropVariantCompareEx`, behind a narrow project-owned compatibility boundary.

Any copied/embedded implementation must preserve license/provenance and receive focused functional and physical-XP validation.

### C. Build and ship an app-local One-Core-derived `propsys.dll`

If removing the DLL dependency is less maintainable than satisfying it, build the pinned One-Core `propsys` source as a controlled app-local XP x86 dependency.

Acceptance would require:

- exact source/build provenance;
- PE subsystem 5.01 or lower;
- complete direct-import audit against stock XP;
- exact exports required by the browser;
- a real implementation for every imported symbol, not a spec stub;
- package-survival gate;
- exact-binary physical Windows XP execution through representative linked consumers;
- final browser validation.

Since One-Core currently marks `VariantCompare` as stub, that symbol would still need to be supplied by adapting existing implementation logic or another proven source before this option can satisfy the current Firefox import table.

### D. Minimal project-specific `propsys.dll`

A minimal Win32 DLL containing only the exact required exports is technically possible, including implementation with an XP-era compiler such as Delphi 7 if the ABI and semantics are reproduced correctly.

This remains a later option rather than the default because source removal or reuse of existing One-Core/Firefox implementation logic is less custom and easier to review. If selected, the DLL must use the exact x86 Windows calling convention/export names expected by `xul.dll` and pass the same provenance/import/package/physical-XP gates as any other app-local compatibility primitive.

## Focused experiment before choosing the production solution

The next PROPSYS-specific experiment should be low-cost and separate from the KERNEL32/YY synchronization work:

1. enumerate the exact `VariantCompare` call sites and the variant types observed/expected in Firefox UI Automation;
2. enumerate the four `PropVariantToString` call sites and the exact property types/path guards involved;
3. compile an XP-source variant that removes or locally replaces both direct calls;
4. require the resulting representative object/PE to have no `PROPSYS.dll` import;
5. if source removal is not sufficient, build a focused One-Core `propsys` probe and inventory its exports/import closure before considering full-browser integration.

Do not add `VariantCompare` alone to the production YY provider merely to reduce one API row: as long as `PropVariantToString` keeps a hard `PROPSYS.dll` dependency, the XP loader boundary remains unresolved.

## Stage status

**OPEN / separately staged.** The problem is well localized and multiple implementation paths exist, but no production remediation has yet been selected or physically proven.

Current preferred hypothesis: eliminate the hard `PROPSYS.dll` dependency at Firefox source level if the two narrow caller families can be handled without loss of useful XP behavior. One-Core is the preferred existing implementation source to evaluate if property-system semantics must be retained. A custom minimal DLL remains an available fallback, not the first choice.
