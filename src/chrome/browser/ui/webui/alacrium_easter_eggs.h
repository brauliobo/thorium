// Copyright 2026 The Thorium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CHROME_BROWSER_UI_WEBUI_ALACRIUM_EASTER_EGGS_H_
#define CHROME_BROWSER_UI_WEBUI_ALACRIUM_EASTER_EGGS_H_

#include "chrome/common/webui_url_constants.h"
#include "content/public/browser/web_ui_controller.h"
#include "content/public/browser/webui_config.h"

class AlacriumWebUILoadUIConfig
    : public content::DefaultWebUIConfig<content::WebUIController> {
 public:
  AlacriumWebUILoadUIConfig()
      : DefaultWebUIConfig(content::kChromeUIScheme,
                           chrome::kChromeUIEggsHost) {}
};

#endif  // CHROME_BROWSER_UI_WEBUI_ALACRIUM_EASTER_EGGS_H_
