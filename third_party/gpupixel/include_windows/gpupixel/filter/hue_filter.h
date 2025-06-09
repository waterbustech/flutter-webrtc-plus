/*
 * GPUPixel
 *
 * Created by PixPark on 2021/6/24.
 * Copyright © 2021 PixPark. All rights reserved.
 */

#pragma once

#include "gpupixel/filter/filter.h"
#include "gpupixel/gpupixel_define.h"

namespace gpupixel {
class GPUPIXEL_API HueFilter : public Filter {
 public:
  static std::shared_ptr<HueFilter> Create();
  bool Init();
  virtual bool DoRender(bool updateSinks = true) override;

  void setHueAdjustment(float hue_adjustment);

 protected:
  HueFilter() {};

  float hue_adjustment_;
};

}  // namespace gpupixel
