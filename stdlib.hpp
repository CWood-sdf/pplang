template <typename V, V value> struct Value {
  static constexpr V val = value;
};

template <class V> struct GetValue {};

template <typename V, V value> struct GetValue<Value<V, value>> {
  static constexpr V val = value;
};

template <double value> using Float = Value<double, value>;
template <long value> using Int = Value<long, value>;
template <char value> using Char = Value<char, value>;
template <bool value> using Bool = Value<bool, value>;

template <typename... Val> struct Array {};

template <typename V> struct First {};

template <typename V, typename... Val> struct First<Array<V, Val...>> {
  typedef V __ret;
};

template <typename Left, typename Right> struct Add {};
template <long left, long right> struct Add<Int<left>, Int<right>> {
  typedef Int<left + right> __ret;
};
template <double left, double right> struct Add<Float<left>, Float<right>> {
  typedef Float<left + right> __ret;
};
template <typename Left, typename Right> struct Sub {};
template <long left, long right> struct Sub<Int<left>, Int<right>> {
  typedef Int<left - right> __ret;
};
template <double left, double right> struct Sub<Float<left>, Float<right>> {
  typedef Float<left - right> __ret;
};

template <typename Left, typename Right> struct Equals {};
template <long left, long right> struct Equals<Int<left>, Int<right>> {
  typedef Bool<left == right> __ret;
};
template <double left, double right> struct Equals<Float<left>, Float<right>> {
  typedef Bool<left == right> __ret;
};
template <bool left, bool right> struct Equals<Bool<left>, Bool<right>> {
  typedef Bool<left == right> __ret;
};

template <typename Arr, typename index> struct Index {};

template <typename V, typename... Other, long index>
  requires(index == 0)
struct Index<Array<V, Other...>, Int<index>> {
  typedef V __ret;
};

template <typename V, typename... Other, long index>
struct Index<Array<V, Other...>, Int<index>> {
  typedef typename Index<Array<Other...>, Int<index - 1>>::__ret __ret;
};

template <typename Arr> struct Sizeof {};

template <typename... Args> struct Sizeof<Array<Args...>> {
  typedef Int<sizeof...(Args)> __ret;
};

template <typename Left, typename Right> struct Merge {};

template <typename... Left, typename... Right>
struct Merge<Array<Left...>, Array<Right...>> {
  typedef Array<Left..., Right...> __ret;
};

using arr1 = Array<Int<1>, Int<2>>;
using arr2 = Array<Int<3>, Int<4>>;

using arr3 = Sizeof<arr1>::__ret;
