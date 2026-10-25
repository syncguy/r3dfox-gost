/* MPL 2.0 */
#ifndef GostTLSService_h
#define GostTLSService_h

class GostTLSService final {
 public:
  // Phase-1 allowlist. R3DFOX_GOST_HOSTS is comma/semicolon separated:
  //   fzs.roskazna.ru;*.example.test
  static bool ShouldUseForHost(const char* aHost);
};

#endif
