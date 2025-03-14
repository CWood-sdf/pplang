#include "stdlib.hpp"
using value  = typename Add<Int<1> , typename Add<Int<5> , Int<4> >::__ret >::__ret ;
using value2  = Array<Array<Int<0> >, Array<value >>;
using thing  = Array<Int<1> , Int<2> , Int<3> , typename Add<Int<4> , Int<5> >::__ret , Int<5> , Int<6> , Int<7> >;
using access  = typename Index<thing , typename Add<Int<4> , Int<1> >::__ret >::__ret ;
using asdfasdf  = typename Add<Int<1> , Int<4> >::__ret ;
using asdfasdf2  = typename Sub<Int<1> , Int<4> >::__ret ;
using thing2  = thing ;
using other  = typename Add<asdfasdf , Int<6> >::__ret ;
struct otherFn {
using __ret = Float<4e0> ;
};
template<typename param>
struct addOne {
using __ret = typename Add<param , Int<1> >::__ret ;
};
template<typename param>
struct subOne {
using __ret = typename Sub<param , Int<1> >::__ret ;
};
template<typename p1, typename p2>
struct twoParams {
using __ret = typename Add<p1 , p2 >::__ret ;
};
template<typename param>
struct equalsOne {
using __ret = typename Equals<param , Int<1> >::__ret ;
};
template<template<typename > typename param, typename value>
struct yeetWith {
using __ret = typename param<value >::__ret ;
};
template<template<typename > typename param, typename value>
requires (GetValue<typename equalsOne<value >::__ret >::val)
struct yeetWith<param, value>{
using __ret = typename Add<value , Int<10> >::__ret ;
};
template<template<typename > typename asdf, template<template<typename > typename , typename > typename otherFn, typename v>
struct yofn {
using __ret = typename otherFn<asdf , v >::__ret ;
};
using idrkanymore  = typename yofn<addOne , yeetWith , Int<1> >::__ret ;
using idrkanymore2  = typename yofn<subOne , yeetWith , Int<2> >::__ret ;
template<typename param>
struct firstFunction {
using __ret = typename Sub<param , typename Add<Float<3e0> , typename Add<Float<1e0> , typename Sub<typename otherFn::__ret , Float<2e0> >::__ret >::__ret >::__ret >::__ret ;
};
using yo  = typename firstFunction<Float<1e0> >::__ret ;
