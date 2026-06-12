#ifndef THIRD_PARTY_BLINK_RENDERER_MODULES_GLOBAL_PRIVACY_CONTROL_GLOBAL_PRIVACY_CONTROL_H_
#define THIRD_PARTY_BLINK_RENDERER_MODULES_GLOBAL_PRIVACY_CONTROL_GLOBAL_PRIVACY_CONTROL_H_

#include "third_party/blink/renderer/core/execution_context/navigator_base.h"

namespace blink {

class GlobalPrivacyControl final {
 public:
  static bool globalPrivacyControl(NavigatorBase&);
};

}  // namespace blink

#endif  // THIRD_PARTY_BLINK_RENDERER_MODULES_GLOBAL_PRIVACY_CONTROL_GLOBAL_PRIVACY_CONTROL_H_
