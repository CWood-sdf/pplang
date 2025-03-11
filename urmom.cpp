#include "stdlib.hpp"
typedef typename Add<Int<1> , typename Add<Int<5> , Int<4> >::__ret >::__ret value ;
typedef Array<Array<Int<0> >, Array<value >>value2 ;
typedef Array<Int<1> , Int<2> , Int<3> , typename Add<Int<4> , Int<5> >::__ret >thing ;
typedef typename Index<thing , Int<3> >::__ret access ;
typedef typename Add<Int<1> , Int<4> >::__ret asdfasdf ;
typedef thing thing2 ;
typedef typename Add<asdfasdf , Int<6> >::__ret other ;
