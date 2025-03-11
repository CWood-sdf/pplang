template <typename V, V value> struct Value {
  static constexpr V val = value;
};

template <double value> using Float = Value<double, value>;
template <long value> using Int = Value<long, value>;
template <char value> using Char = Value<char, value>;

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
