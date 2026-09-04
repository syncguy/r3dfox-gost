/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include <oleauto.h>
#include <wchar.h>

#ifdef MOZ_XP_COMPAT

namespace {

bool IsEmptyOrNull(const VARIANT& aVariant) {
  return V_VT(&aVariant) == VT_EMPTY || V_VT(&aVariant) == VT_NULL;
}

int Sign(int aValue) { return aValue < 0 ? -1 : aValue > 0 ? 1 : 0; }

template <typename T>
int CompareScalar(T aFirst, T aSecond) {
  return (aFirst > aSecond) - (aFirst < aSecond);
}

}  // namespace

// XP has OLE Automation VARIANT support but no PROPSYS!VariantCompare.
// Keep this implementation local to the XP compatibility build. Its behavior
// was validated against the native VariantCompare oracle on a modern Windows
// runner by variantcompare-xp-x86-smoke.yml.
extern "C" int WINAPI CompareVariantsXP(REFVARIANT aFirst,
                                         REFVARIANT aSecond) {
  if (IsEmptyOrNull(aFirst)) {
    return IsEmptyOrNull(aSecond) ? 0 : -1;
  }
  if (IsEmptyOrNull(aSecond)) {
    return 1;
  }

  VARIANT converted;
  VariantInit(&converted);
  const VARIANT* second = &aSecond;

  if (V_VT(&aFirst) != V_VT(&aSecond)) {
    HRESULT hr = VariantChangeType(&converted,
                                   const_cast<VARIANT*>(&aSecond), 0,
                                   V_VT(&aFirst));
    if (FAILED(hr)) {
      VariantClear(&converted);
      return -1;
    }
    second = &converted;
  }

  int result = -1;
  switch (V_VT(&aFirst)) {
    case VT_I1:
      result = CompareScalar(V_I1(&aFirst), V_I1(second));
      break;
    case VT_UI1:
      result = CompareScalar(V_UI1(&aFirst), V_UI1(second));
      break;
    case VT_I2:
      result = CompareScalar(V_I2(&aFirst), V_I2(second));
      break;
    case VT_UI2:
      result = CompareScalar(V_UI2(&aFirst), V_UI2(second));
      break;
    case VT_I4:
      result = CompareScalar(V_I4(&aFirst), V_I4(second));
      break;
    case VT_UI4:
      result = CompareScalar(V_UI4(&aFirst), V_UI4(second));
      break;
    case VT_I8:
      result = CompareScalar(V_I8(&aFirst), V_I8(second));
      break;
    case VT_UI8:
      result = CompareScalar(V_UI8(&aFirst), V_UI8(second));
      break;
    case VT_R4:
      result = CompareScalar(V_R4(&aFirst), V_R4(second));
      break;
    case VT_R8:
      result = CompareScalar(V_R8(&aFirst), V_R8(second));
      break;
    case VT_BOOL:
      // VARIANT_TRUE is -1 and VARIANT_FALSE is 0. Native VariantCompare
      // compares the stored VARIANT_BOOL values with this ordering.
      result = CompareScalar(V_BOOL(&aFirst), V_BOOL(second));
      break;
    case VT_BSTR: {
      const wchar_t* first = V_BSTR(&aFirst) ? V_BSTR(&aFirst) : L"";
      const wchar_t* rhs = V_BSTR(second) ? V_BSTR(second) : L"";
      result = Sign(wcscmp(first, rhs));
      break;
    }
    default:
      // Match the conservative failure ordering used by the compatibility
      // reference implementation for unsupported VARTYPEs.
      result = -1;
      break;
  }

  VariantClear(&converted);
  return result;
}

#endif  // MOZ_XP_COMPAT
