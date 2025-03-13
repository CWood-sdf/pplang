#include "stdlib.hpp"
typedef typename Add<Int<1> , typename Add<Int<5> , Int<4> >::__ret >::__ret value ;
typedef Array<Array<Int<0> >, Array<value >>value2 ;
typedef Array<Int<1> , Int<2> , Int<3> , typename Add<Int<4> , Int<5> >::__ret , Int<5> , Int<6> , Int<7> >thing ;
typedef typename Index<thing , typename Add<Int<4> , Int<1> >::__ret >::__ret access ;
typedef typename Add<Int<1> , Int<4> >::__ret asdfasdf ;
typedef typename Sub<Int<1> , Int<4> >::__ret asdfasdf2 ;
typedef thing thing2 ;
typedef typename Add<asdfasdf , Int<6> >::__ret other ;
struct otherFn {
typedef Float<4e0>  __ret;
};
template<typename param>
struct addOne {
typedef typename Add<param , Int<1> >::__ret  __ret;
};
template<typename param>
struct subOne {
typedef typename Sub<param , Int<1> >::__ret  __ret;
};
template<typename p1, typename p2>
struct twoParams {
typedef typename Add<p1 , p2 >::__ret  __ret;
};
template<typename param>
struct equalsOne {
typedef typename Equals<param , Int<1> >::__ret  __ret;
};
template<template<typename > typename param, typename value>
struct yeetWith {
typedef typename param<value >::__ret  __ret;
};
template<template<typename > typename param, typename value>
requires (GetValue<typename equalsOne<value >::__ret >::val)
struct yeetWith<param, value>{
typedef typename Add<value , Int<10> >::__ret  __ret;
};
template<template<typename > typename asdf, template<template<typename > typename , typename > typename otherFn, typename v>
struct yofn {
typedef typename otherFn<asdf , v >::__ret  __ret;
};
typedef typename yofn<addOne , yeetWith , Int<1> >::__ret idrkanymore ;
typedef typename yofn<subOne , yeetWith , Int<2> >::__ret idrkanymore2 ;
template<typename param>
struct firstFunction {
typedef typename Sub<param , typename Add<Float<3e0> , typename Add<Float<1e0> , typename Sub<typename otherFn::__ret , Float<2e0> >::__ret >::__ret >::__ret >::__ret  __ret;
};
typedef typename firstFunction<Float<1e0> >::__ret yo ;
template<typename asdf>
struct retFun {
template<typename p>
struct ret {
typedef typename Add<p , Int<1> >::__ret  __ret;
};
typedef ret  __ret;
};
typedef typename retFun<Int<1> >::__ret fun ;
