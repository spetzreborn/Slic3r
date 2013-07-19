#ifndef _myinit_h_
#define _myinit_h_

extern "C" {
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#undef do_open
#undef do_close
}

namespace Slic3r {}
using namespace Slic3r;

#define av_store_point_xy(AV, X, Y)              \
  av_store(AV, 0, newSVnv(X));                   \
  av_store(AV, 1, newSVnv(Y))

#endif
