# Build notes

The initial CI intentionally injects the build-system entries instead of permanently editing `moz.build` while the interface is still expected to move during first compilation.

Pinned MSSPI revision:

```text
f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232
```

Applied local delta:

```diff
-#if !defined(USE_BOOST) && !defined(_MSVC_LANG) && __cplusplus < 201103L
+#if !defined(USE_BOOST) && !defined(_MSC_VER) && !defined(_MSVC_LANG) && __cplusplus < 201103L
```

The first CI target is Windows x64. x86 will be added after the x64 integration compiles and packages successfully.
