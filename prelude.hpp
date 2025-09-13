#include "stdlib.hpp"

template <typename val, typename ifval, typename elseval>
struct ifelse__actual {
  using __ret = elseval;
};

struct ifelse {

  template <typename val, typename ifval, typename elseval>
  using __apply = ifelse__actual<val, ifval, elseval>;
};

template <typename val, typename ifval, typename elseval>
  requires(GetValue<val>::val)
struct ifelse__actual<val, ifval, elseval> {
  using __ret = ifval;
};
