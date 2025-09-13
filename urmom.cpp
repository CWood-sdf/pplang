#include "prelude.hpp"

template <typename left, typename right>
struct mergeArrays__actual {
    using __ret = Array<>;

    __ret __INSTANCE_OF_ret;
};

struct mergeArrays {

    template <typename left, typename right>
    using __apply = mergeArrays__actual<left, right>;
};

template <typename... left, typename... right>
    requires(GetValue<Bool<true>>::val)
struct mergeArrays__actual<Array<left...>, Array<right...>> {
    using __ret = Array<left..., right...>;

    __ret __INSTANCE_OF_ret;
};

template <typename v>
struct sumAllArr__actual {
    using __ret = Int<0>;

    __ret __INSTANCE_OF_ret;
};

struct sumAllArr {

    template <typename v>
    using __apply = sumAllArr__actual<v>;
};

template <typename v, typename... rest>
    requires(GetValue<Bool<true>>::val)
struct sumAllArr__actual<Array<v, rest...>> {
    using __ret = typename Add<
        v, typename sumAllArr::template __apply<Array<rest...>>::__ret>::__ret;

    __ret __INSTANCE_OF_ret;
};

using arrayLeft = Array<Int<1>, Int<2>, Int<3>>;

arrayLeft _____INSTANCE_OF_arrayLeft;

using arrayRight = Array<Int<4>, Int<5>, Int<6>>;

arrayRight _____INSTANCE_OF_arrayRight;

using res =
    typename sumAllArr::template __apply<typename mergeArrays::template __apply<
        arrayLeft, arrayRight>::__ret>::__ret;

res _____INSTANCE_OF_res;

using printRes =
    typename print::template __apply<res, Char<10>,
                                     Array<Int<1>, Int<2>, Int<3>>>::__ret;

printRes _____INSTANCE_OF_printRes;

using value = typename Add<Int<1>, typename Add<Int<5>, Int<4>>::__ret>::__ret;

value _____INSTANCE_OF_value;

using value2 = Array<Array<Int<0>>, Array<value>>;

value2 _____INSTANCE_OF_value2;

using thing = Array<Int<1>, Int<2>, Int<3>, typename Add<Int<4>, Int<5>>::__ret,
                    Int<5>, Int<6>, Int<7>>;

thing _____INSTANCE_OF_thing;

using access =
    typename Index<thing, typename Add<Int<4>, Int<1>>::__ret>::__ret;

access _____INSTANCE_OF_access;

using asdfasdf = typename Add<Int<1>, Int<4>>::__ret;

asdfasdf _____INSTANCE_OF_asdfasdf;

using asdfasdf2 = typename Sub<Int<1>, Int<4>>::__ret;

asdfasdf2 _____INSTANCE_OF_asdfasdf2;

using thing2 = thing;

thing2 _____INSTANCE_OF_thing2;

using other = typename Add<asdfasdf, Int<6>>::__ret;

other _____INSTANCE_OF_other;

struct otherFn__actual {
    using __ret = Float<(double)4>;

    __ret __INSTANCE_OF_ret;
};

struct otherFn {

    using __apply = otherFn__actual;
};

template <typename param>
struct addOne__actual {
    using __ret = typename Add<param, Int<1>>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct addOne {

    template <typename param>
    using __apply = addOne__actual<param>;
};

template <typename param>
struct subOne__actual {
    using __ret = typename Sub<param, Int<1>>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct subOne {

    template <typename param>
    using __apply = subOne__actual<param>;
};

template <typename p1, typename p2>
struct twoParams__actual {
    using __ret = typename Add<p1, p2>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct twoParams {

    template <typename p1, typename p2>
    using __apply = twoParams__actual<p1, p2>;
};

template <typename param>
struct equalsOne__actual {
    using __ret = typename Equals<param, Int<1>>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct equalsOne {

    template <typename param>
    using __apply = equalsOne__actual<param>;
};

template <typename param, typename value>
struct yeetWith__actual {
    using __ret = typename param::template __apply<value>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct yeetWith {

    template <typename param, typename value>
    using __apply = yeetWith__actual<param, value>;
};

template <typename param, typename value>
    requires(GetValue<typename equalsOne::template __apply<value>::__ret>::val)
struct yeetWith__actual<param, value> {
    using __ret = typename Add<value, Int<10>>::__ret;

    __ret __INSTANCE_OF_ret;
};

template <typename asdf, typename otherFn, typename v>
struct yofn__actual {
    using __ret = typename otherFn::template __apply<asdf, v>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct yofn {

    template <typename asdf, typename otherFn, typename v>
    using __apply = yofn__actual<asdf, otherFn, v>;
};

using idrkanymore =
    typename yofn::template __apply<addOne, yeetWith, Int<1>>::__ret;

idrkanymore _____INSTANCE_OF_idrkanymore;

using idrkanymore2 =
    typename yofn::template __apply<subOne, yeetWith, Int<2>>::__ret;

idrkanymore2 _____INSTANCE_OF_idrkanymore2;

template <typename param>
struct firstFunction__actual {
    using __ret = typename Sub<
        param,
        typename Add<Float<(double)3>,
                     typename Add<Float<(double)1>,
                                  typename Sub<typename otherFn::__apply::__ret,
                                               Float<(double)2>>::__ret>::
                         __ret>::__ret>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct firstFunction {

    template <typename param>
    using __apply = firstFunction__actual<param>;
};

template <typename param>
struct plus1__actual {
    using __ret = typename Add<param, Int<1>>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct plus1 {

    template <typename param>
    using __apply = plus1__actual<param>;
};

template <typename param>
struct returnsFunction__actual {
    using printed = typename print::template __apply<Int<69>>::__ret;

    printed _____INSTANCE_OF_printed;

    using __ret = param;

    __ret __INSTANCE_OF_ret;
};

struct returnsFunction {

    template <typename param>
    using __apply = returnsFunction__actual<param>;
};

template <typename param>
struct returnsFnFn__actual {
    using __ret = param;

    __ret __INSTANCE_OF_ret;
};

struct returnsFnFn {

    template <typename param>
    using __apply = returnsFnFn__actual<param>;
};

template <typename param>
struct closureTest__actual {
    template <typename param2>
    struct closure__actual {
        using __ret = typename Add<param, param2>::__ret;

        __ret __INSTANCE_OF_ret;
    };

    struct closure {

        template <typename param2>
        using __apply = closure__actual<param2>;
    };

    using __ret = closure;

    __ret __INSTANCE_OF_ret;
};

struct closureTest {

    template <typename param>
    using __apply = closureTest__actual<param>;
};

using array = Array<closureTest, plus1>;

array _____INSTANCE_OF_array;

using closureTestArr = typename Index<array, Int<0>>::__ret;

closureTestArr _____INSTANCE_OF_closureTestArr;

using plus1Arr = typename Index<array, Int<1>>::__ret;

plus1Arr _____INSTANCE_OF_plus1Arr;

using f2 = typename closureTestArr::template __apply<Int<2>>::__ret;

f2 _____INSTANCE_OF_f2;

using fukyo = typename f2::template __apply<Int<4>>::__ret;

fukyo _____INSTANCE_OF_fukyo;

using plus1omgomg = typename plus1Arr::template __apply<Int<3>>::__ret;

plus1omgomg _____INSTANCE_OF_plus1omgomg;

using f = typename closureTest::template __apply<Int<6>>::__ret;

f _____INSTANCE_OF_f;

using fuk = typename f::template __apply<Int<7>>::__ret;

fuk _____INSTANCE_OF_fuk;

using idk = typename print::template __apply<fuk>::__ret;

idk _____INSTANCE_OF_idk;

using returned = typename returnsFunction::template __apply<plus1>::__ret;

returned _____INSTANCE_OF_returned;

using returned2 =
    typename returnsFnFn::template __apply<returnsFunction>::__ret;

returned2 _____INSTANCE_OF_returned2;

using omg = typename returned2::template __apply<plus1>::__ret;

omg _____INSTANCE_OF_omg;

using out = typename returned::template __apply<Int<1>>::__ret;

out _____INSTANCE_OF_out;

using out2 = typename omg::template __apply<Int<1>>::__ret;

out2 _____INSTANCE_OF_out2;

using yo = typename firstFunction::template __apply<Float<(double)1>>::__ret;

yo _____INSTANCE_OF_yo;

template <typename param>
struct printParam__actual {
    using idk = typename print::template __apply<param>::__ret;

    idk _____INSTANCE_OF_idk;

    using __ret = typename Add<param, Int<1>>::__ret;

    __ret __INSTANCE_OF_ret;
};

struct printParam {

    template <typename param>
    using __apply = printParam__actual<param>;
};

using ooga = typename printParam::template __apply<Int<3>>::__ret;

ooga _____INSTANCE_OF_ooga;

using printed = typename print::template __apply<Char<10>>::__ret;

printed _____INSTANCE_OF_printed;

template <typename... args>
struct sumAll__actual {
    using __ret = Int<0>;

    __ret __INSTANCE_OF_ret;
};

struct sumAll {

    template <typename... args>
    using __apply = sumAll__actual<args...>;
};

template <typename v, typename... rest>
    requires(GetValue<Bool<true>>::val)
struct sumAll__actual<v, rest...> {
    using __ret =
        typename Add<v,
                     typename sumAll::template __apply<rest...>::__ret>::__ret;

    __ret __INSTANCE_OF_ret;
};

int main() {
}
