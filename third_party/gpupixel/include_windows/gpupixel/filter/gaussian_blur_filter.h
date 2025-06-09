/*
 * GPUPixel
 *
 * Created by PixPark on 2021/6/24.
 * Copyright © 2021 PixPark. All rights reserved.
 */

#pragma once

#include "gpupixel/filter/filter_group.h"
#include "gpupixel/filter/gaussian_blur_mono_filter.h"
#include "gpupixel/gpupixel_define.h"

namespace gpupixel {
class GPUPIXEL_API GaussianBlurFilter : public FilterGroup {
 public:
  virtual ~GaussianBlurFilter();

  static std::shared_ptr<GaussianBlurFilter> Create(int radius = 4,
                                                    float sigma = 2.0);
  bool Init(int radius, float sigma);
  void SetRadius(int radius);
  void setSigma(float sigma);

 protected:
  GaussianBlurFilter();

 private:
  std::shared_ptr<GaussianBlurMonoFilter> horizontal_blur_filter_;
  std::shared_ptr<GaussianBlurMonoFilter> vertical_blur_filter_;
};

}  // namespace gpupixel
