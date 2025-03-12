#include "stdlib.hpp"
typedef typename Add<Int<1>, typename Add<Int<5>, Int<4>>::__ret>::__ret value;
typedef Array<Array<Int<0>>, Array<value>> value2;
typedef Array<Int<1>, Int<2>, Int<3>, typename Add<Int<4>, Int<5>>::__ret>
    thing;
typedef typename Index<thing, Int<3>>::__ret access;
typedef typename Add<Int<1>, Int<4>>::__ret asdfasdf;
typedef typename Sub<Int<1>, Int<4>>::__ret asdfasdf2;
typedef thing thing2;
typedef typename Add<asdfasdf, Int<6>>::__ret other;
struct otherFn {
  typedef Float<4e0> __ret;
};
template <typename param> struct firstFunction {
  typedef typename Sub<
      param, typename Add<
                 Float<3e0>,
                 typename Add<Float<1e0>, typename Sub<typename otherFn::__ret,
                                                       Float<2e0>>::__ret>::
                     __ret>::__ret>::__ret __ret;
};
typedef typename firstFunction<Float<1e0>>::__ret yo;
