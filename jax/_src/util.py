# Copyright 2018 The JAX Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import annotations

import abc
from collections.abc import Callable, Iterable, Iterator, Sequence
import functools
from functools import partial
import itertools as it
import logging
import math
import operator
from typing import (Any, Generic, SupportsIndex, TypeVar, overload, TYPE_CHECKING, cast)
import weakref

import numpy as np

from jax._src import config
from jax._src.lib import weakref_lru_cache as _weakref_lru_cache
from jax._src.lib import utils as jaxlib_utils

logger = logging.getLogger(__name__)

Seq = Sequence

# TODO(jakevdp): fix import cycles and import Array.
Array = Any

T = TypeVar("T")
T1 = TypeVar("T1")
T2 = TypeVar("T2")
T3 = TypeVar("T3")


if TYPE_CHECKING:
  # safe_zip cannot yet be fully annotated, so we use a strategy similar
  # to that used for builtins.zip in python/typeshed. This supports
  # return types matching input types for up to three arguments.
  @overload
  def safe_zip(__arg1: Iterable[T1]) -> list[tuple[T1]]: ...
  @overload
  def safe_zip(__arg1: Iterable[T1], __arg2: Iterable[T2]) -> list[tuple[T1, T2]]: ...
  @overload
  def safe_zip(__arg1: Iterable[T1], __arg2: Iterable[T2], __arg3: Iterable[T3]) -> list[tuple[T1, T2, T3]]: ...
  @overload
  def safe_zip(__arg1: Iterable[Any], __arg2: Iterable[Any], __arg3: Iterable[Any], __arg4: Iterable[Any], *args) -> list[tuple[Any, ...]]: ...

  def safe_zip(*args):
    """
    Like builtin :func:`zip`, but with additional safety checks.

    The differences from :func:`zip` are:

    - :func:`safe_zip` checks that at least one argument is provided.
    - :func:`safe_zip` checks that all arguments have the same length.
    - :func:`safe_zip` returns an eagerly-evaluated list instead of a
      lazily-evaluated iterator.
    """
    if not args:
      raise TypeError("safe_zip requires at least 1 argument.")
    return list(zip(*args, strict=True))
else:
  safe_zip = jaxlib_utils.safe_zip


if TYPE_CHECKING:
  # safe_map cannot yet be fully annotated, so we use a strategy similar
  # to that used for builtins.map in python/typeshed. This supports
  # checking input types for the callable with up to three arguments.
  @overload
  def safe_map(f: Callable[[T1], T], __arg1: Iterable[T1]) -> list[T]: ...

  @overload
  def safe_map(f: Callable[[T1, T2], T], __arg1: Iterable[T1], __arg2: Iterable[T2]) -> list[T]: ...

  @overload
  def safe_map(f: Callable[[T1, T2, T3], T], __arg1: Iterable[T1], __arg2: Iterable[T2], __arg3: Iterable[T3]) -> list[T]: ...

  @overload
  def safe_map(f: Callable[..., T], __arg1: Iterable[Any], __arg2: Iterable[Any], __arg3: Iterable[Any], __arg4: Iterable[Any], *args) -> list[T]: ...

  def safe_map(f, *args):
    args = list(map(list, args))
    n = len(args[0])
    for arg in args[1:]:
      assert len(arg) == n, f'length mismatch: {list(map(len, args))}'
    return list(map(f, *args))

else:
  safe_map = jaxlib_utils.safe_map

if TYPE_CHECKING:
  @overload
  def foreach(f: Callable[[T1], Any], __arg1: Iterable[T1]) -> None: ...

  @overload
  def foreach(f: Callable[[T1, T2], Any], __arg1: Iterable[T1], __arg2: Iterable[T2]) -> None: ...

  @overload
  def foreach(f: Callable[[T1, T2, T3], Any], __arg1: Iterable[T1], __arg2: Iterable[T2], __arg3: Iterable[T3]) -> None: ...

  @overload
  def foreach(f: Callable[..., Any], __arg1: Iterable[Any], __arg2: Iterable[Any], __arg3: Iterable[Any], __arg4: Iterable[Any], *args) -> None: ...

  def foreach(f, *args):
    safe_map(f, *args)
    return None

else:
  foreach = jaxlib_utils.foreach


def unzip2(xys: Iterable[tuple[T1, T2]]
    ) -> tuple[tuple[T1, ...], tuple[T2, ...]]:
  """Unzip sequence of length-2 tuples into two tuples."""
  # Note: we deliberately don't use zip(*xys) because it is lazily evaluated,
  # is too permissive about inputs, and does not guarantee a length-2 output.
  xs: list[T1] = []
  ys: list[T2] = []
  for x, y in xys:
    xs.append(x)
    ys.append(y)
  return tuple(xs), tuple(ys)

def unzip3(xyzs: Iterable[tuple[T1, T2, T3]]
    ) -> tuple[tuple[T1, ...], tuple[T2, ...], tuple[T3, ...]]:
  """Unzip sequence of length-3 tuples into three tuples."""
  # Note: we deliberately don't use zip(*xyzs) because it is lazily evaluated,
  # is too permissive about inputs, and does not guarantee a length-3 output.
  xs: list[T1] = []
  ys: list[T2] = []
  zs: list[T3] = []
  for x, y, z in xyzs:
    xs.append(x)
    ys.append(y)
    zs.append(z)
  return tuple(xs), tuple(ys), tuple(zs)

def subvals(lst: Sequence[T], replace: Iterable[tuple[int, T]]) -> tuple[T, ...]:
  """Substitute values within a list."""
  lst = list(lst)
  for i, v in replace:
    lst[i] = v
  return tuple(lst)

def split_list(args: Sequence[T], ns: Sequence[int]) -> list[list[T]]:
  """Split list into sublists of the specified sizes."""
  args = list(args)
  lists = []
  for n in ns:
    lists.append(args[:n])
    args = args[n:]
  lists.append(args)
  return lists

def split_list_checked(args: Sequence[T], ns: Sequence[int]) -> list[list[T]]:
  """Split list into sublists of the specified sizes."""
  args = list(args)
  assert sum(ns) == len(args) and all(n >= 0 for n in ns)
  lists = []
  for n in ns:
    lists.append(args[:n])
    args = args[n:]
  return lists

def partition_list(bs: Sequence[bool], l: Sequence[T]) -> tuple[list[T], list[T]]:
  """Partition a list into two based on a mask."""
  assert len(bs) == len(l)
  lists: tuple[list[T], list[T]] = ([], [])
  for b, x in zip(bs, l):
    lists[b].append(x)
  return lists

def merge_lists(bs: Sequence[bool],
                l0: Sequence[T1],
                l1: Sequence[T2]
                ) -> list[T1 | T2]:
  """Merge the elements of two lists based on a mask."""
  assert sum(bs) == len(l1) and len(bs) - sum(bs) == len(l0)
  i0, i1 = iter(l0), iter(l1)
  out: list[T1 | T2] = [next(i1) if b else next(i0) for b in bs]
  sentinel = object()
  assert next(i0, sentinel) is next(i1, sentinel) is sentinel
  return out

def subs_list(
    subs: Sequence[int | None], src: Sequence[T], base: Sequence[T],
) -> list[T]:
  base_ = iter(base)
  out = [src[i] if i is not None else next(base_) for i in subs]
  sentinel = object()
  assert next(base_, sentinel) is sentinel
  return out

def subs_list2(
    subs1: Sequence[int | None], subs2: Sequence[int | None],
    src1: Sequence[T], src2: Sequence[T], base: Sequence[T],
) -> list[T]:
  assert len(subs1) == len(subs2)
  base_ = iter(base)
  out = [src1[f1] if f1 is not None else src2[f2] if f2 is not None else
         next(base_) for f1, f2, in zip(subs1, subs2)]
  sentinel = object()
  assert next(base_, sentinel) is sentinel
  return out

def split_dict(dct: dict[T1, T2], names: Sequence[T1]) -> list[T2]:
  dct = dict(dct)
  lst = [dct.pop(name) for name in names]
  assert not dct
  return lst

def concatenate(xs: Iterable[Sequence[T]]) -> list[T]:
  """Concatenates/flattens a list of lists."""
  return list(it.chain.from_iterable(xs))

flatten = concatenate

_unflatten_done = object()

def unflatten(xs: Iterable[T], ns: Sequence[int]) -> list[list[T]]:
  """Splits `xs` into subsequences of lengths `ns`.

  Unlike `split_list`, the `sum(ns)` must be equal to `len(xs)`."""
  xs_iter = iter(xs)
  unflattened = [[next(xs_iter) for _ in range(n)] for n in ns]
  assert next(xs_iter, _unflatten_done) is _unflatten_done
  return unflattened


def curry(f):
  """Curries arguments of f, returning a function on any remaining arguments.

  For example:
  >>> f = lambda x, y, z, w: x * y + z * w
  >>> f(2,3,4,5)
  26
  >>> curry(f)(2)(3, 4, 5)
  26
  >>> curry(f)(2, 3)(4, 5)
  26
  >>> curry(f)(2, 3, 4, 5)()
  26
  """
  return wraps(f)(partial(partial, f))

toposort: Callable[[Iterable[Any]], list[Any]]
toposort = partial(jaxlib_utils.topological_sort, "parents")


def split_merge(
    predicate: Callable[[T], bool],
    xs: Sequence[T]
) -> tuple[list[T], list[T], Callable[[Sequence[T], Sequence[T]], list[T]]]:
  sides = list(map(predicate, xs))
  lhs = [x for x, s in zip(xs, sides) if s]
  rhs = [x for x, s in zip(xs, sides) if not s]
  def merge(new_lhs, new_rhs):
    out = []
    for s in sides:
      if s:
        out.append(new_lhs[0])
        new_lhs = new_lhs[1:]
      else:
        out.append(new_rhs[0])
        new_rhs = new_rhs[1:]
    assert not new_rhs
    assert not new_lhs
    return out

  return lhs, rhs, merge


def cache(max_size=4096, trace_context_in_key=True):
  if trace_context_in_key:
    def wrap(f):
      @functools.lru_cache(max_size)
      def cached(_, *args, **kwargs):
        return f(*args, **kwargs)

      @functools.wraps(f)
      def wrapper(*args, **kwargs):
        if config.check_tracer_leaks.value:
          return f(*args, **kwargs)
        return cached(config.trace_context(), *args, **kwargs)

      wrapper.cache_clear = cached.cache_clear
      wrapper.cache_info = cached.cache_info
      register_cache(wrapper, str(f))
      return wrapper
  else:
    def wrap(f):
      wrapper = functools.lru_cache(max_size)(f)
      register_cache(wrapper, str(f))
      return wrapper
  return wrap

# Maps caches to the name of the callable they apply to. All caches in
# this dictionary support `cache_clear()`.
_caches: weakref.WeakKeyDictionary[Any, str] = weakref.WeakKeyDictionary()

def register_cache(cache: Any, for_what: str):
  """Registers a cache with JAX's cache management.

  Args:
    cache: an object supporting `cache_clear()`, `cache_info()`, and
    `cache_keys()`, like the result of `functools.lru_cache()`.
    for_what: a string to identify what this cache is used for. This is
     used for debugging.
"""
  _caches[cache] = for_what

def clear_all_caches():
  for cache in _caches.keys():
    cache.cache_clear()

memoize = cache(max_size=None)

def _ignore(): return None

def weakref_lru_cache(call: Callable, maxsize=2048,
                      trace_context_in_key: bool = True):
  """
  Least recently used cache decorator with weakref support.

  The cache will take a weakref to the first argument of the wrapped function
  and strong refs to all subsequent operations. In all other respects it should
  behave similar to `functools.lru_cache`.
  """
  cached_call = _weakref_lru_cache.weakref_lru_cache(
      config.trace_context if trace_context_in_key else _ignore, call, maxsize
  )
  register_cache(cached_call, str(call))
  return cached_call


class Unhashable:
  __slots__ = ["val"]

  def __init__(self, val):
    self.val = val

  def __eq__(self, other):
    return self.val == other.val

class Hashable:
  __slots__ = ["val"]

  def __init__(self, val):
    self.val = val

  def __hash__(self):
    return hash(self.val)

  def __eq__(self, other):
    return self.val == other.val

class WrapKwArgs:
  __slots__ = ["val"]

  def __init__(self, val):
    self.val = val

  def __hash__(self):
    return hash(tuple((k, v) for k, v in sorted(self.val.items())))

  def __eq__(self, other):
    return self.val == other.val

def wrap_name(transform_name: str, name: str) -> str:
  return f"{transform_name}({name})"


def fun_name(fun: Callable, default_name: str = "<unnamed function>") -> str:
  name = getattr(fun, "__name__", None)
  if name is not None:
    return name
  if isinstance(fun, partial):
    return fun_name(fun.func)
  else:
    return default_name


def fun_qual_name(fun: Callable) -> str:
  qual_name = getattr(fun, "__qualname__", None)
  if qual_name is not None:
    return qual_name
  if isinstance(fun, partial):
    return fun_qual_name(fun.func)
  return fun_name(fun)

def canonicalize_axis(axis: SupportsIndex, num_dims: int) -> int:
  """Canonicalize an axis in [-num_dims, num_dims) to [0, num_dims)."""
  axis = operator.index(axis)
  if not -num_dims <= axis < num_dims:
    raise ValueError(f"axis {axis} is out of bounds for array of dimension {num_dims}")
  if axis < 0:
    axis = axis + num_dims
  return axis

def canonicalize_axis_tuple(axis: int | Sequence[int] | None, ndim: int, allow_duplicate: bool = False) -> tuple[int, ...]:
  if axis is None:
    return tuple(range(ndim))
  if isinstance(axis, Sequence):
    axis = tuple(canonicalize_axis(i, ndim) for i in axis)
    if not allow_duplicate and len(set(axis)) != len(axis):
      raise ValueError(f"repeated axis: {axis}")
    return axis
  else:
    return (canonicalize_axis(axis, ndim),)

def moveaxis(x: Array, src: int | Sequence[int], dst: int | Sequence[int]) -> Array:
  if src == dst:
    return x
  if isinstance(src, int):
    src = (src,)
  if isinstance(dst, int):
    dst = (dst,)
  src = [canonicalize_axis(a, x.ndim) for a in src]
  dst = [canonicalize_axis(a, x.ndim) for a in dst]
  perm = [i for i in range(np.ndim(x)) if i not in src]
  for d, s in sorted(zip(dst, src)):
    perm.insert(d, s)
  return x.transpose(perm)

def ceil_of_ratio(x: int, y: int) -> int:
  return -(-x // y)


def wraps(
    wrapped: Callable,
    namestr: str | None = None,
    docstr: str | None = None,
    **kwargs,
) -> Callable[[T], T]:
  """
  Like functools.wraps, but with finer-grained control over the name and docstring
  of the resulting function.
  """
  def wrapper(fun: T) -> T:
    try:
      name = fun_name(wrapped)
      doc = getattr(wrapped, "__doc__", "") or ""
      fun.__dict__.update(getattr(wrapped, "__dict__", {}))
      fun.__annotations__ = getattr(wrapped, "__annotations__", {})
      fun.__name__ = name if namestr is None else namestr.format(fun=name)
      fun.__module__ = getattr(wrapped, "__module__", "<unknown module>")
      fun.__doc__ = (doc if docstr is None
                     else docstr.format(fun=name, doc=doc, **kwargs))
      fun.__qualname__ = getattr(wrapped, "__qualname__", fun.__name__)
      fun.__wrapped__ = wrapped
    except Exception:
      pass
    return fun
  return wrapper


# NOTE: Ideally we would annotate both the argument and return type as NoReturn
#       but it seems like pytype doesn't support that...
def assert_unreachable(x):
  raise AssertionError(f"Unhandled case: {type(x).__name__}")

def tuple_insert(t: tuple[T, ...], idx: int, val: T) -> tuple[T, ...]:
  assert 0 <= idx <= len(t), (idx, len(t))
  return t[:idx] + (val,) + t[idx:]

def tuple_delete(t: tuple[T, ...], idx: int) -> tuple[T, ...]:
  assert 0 <= idx < len(t), (idx, len(t))
  return t[:idx] + t[idx + 1:]

def tuple_update(t: tuple[T, ...], idx: int, val: T) -> tuple[T, ...]:
  assert 0 <= idx < len(t), (idx, len(t))
  return t[:idx] + (val,) + t[idx+1:]

class HashableFunction:
  """Decouples function equality and hash from its identity.

  Local lambdas and function defs are reallocated on each function call, making
  the functions created on different calls compare as unequal. This breaks our
  caching logic, which should really only care about comparing the semantics and
  not actual identity.

  This class makes it possible to compare different functions based on their
  semantics. The parts that are taken into account are: the bytecode of the
  wrapped function (which is cached by the CPython interpreter and is stable
  across the invocations of the surrounding function), and `closure` which
  should contain all values in scope that affect the function semantics. In
  particular `closure` should contain all elements of the function closure, or
  it should be possible to derive the relevant elements of the true function
  closure based solely on the contents of the `closure` argument (e.g. in case
  some closed-over values are not hashable, but are entirely determined by
  hashable locals).
  """

  def __init__(self, f, closure):
    self.f = f
    self.closure = closure

  def __eq__(self, other):
    return (type(other) is HashableFunction and
            self.f.__code__ == other.f.__code__ and
            self.closure == other.closure)

  def __hash__(self):
    return hash((self.f.__code__, self.closure))

  def __call__(self, *args, **kwargs):
    return self.f(*args, **kwargs)

  def __repr__(self):
    return f'<hashable {self.f.__name__} with closure={self.closure}>'

def as_hashable_function(closure):
  return lambda f: HashableFunction(f, closure)

class HashablePartial:
  def __init__(self, f, *args, **kwargs):
    self.f = f
    self.args = args
    self.kwargs = kwargs

  def __eq__(self, other):
    return (type(other) is HashablePartial and
            self.f.__code__ == other.f.__code__ and
            self.args == other.args and self.kwargs == other.kwargs)

  def __hash__(self):
    kwargs = tuple(sorted(self.kwargs.items(), key=lambda kv: kv[0]))
    return hash((self.f.__code__, self.args, kwargs))

  def __call__(self, *args, **kwargs):
    return self.f(*self.args, *args, **self.kwargs, **kwargs)

def maybe_named_axis(axis, if_pos, if_named):
  try:
    pos = operator.index(axis)
    named = False
  except TypeError:
    named = True
  return if_named(axis) if named else if_pos(pos)

def distributed_debug_log(*pairs):
  """Format and log `pairs` if config.jax_distributed_debug is enabled.

  Args:
    pairs: A sequence of label/value pairs to log. The first pair is treated as
    a heading for subsequent pairs.
  """
  if config.distributed_debug.value:
    lines = ["\nDISTRIBUTED_DEBUG_BEGIN"]
    try:
      lines.append(f"{pairs[0][0]}: {pairs[0][1]}")
      for label, value in pairs[1:]:
        lines.append(f"  {label}: {value}")
    except Exception as e:
      lines.append("DISTRIBUTED_DEBUG logging failed!")
      lines.append(f"{e}")
    lines.append("DISTRIBUTED_DEBUG_END")
    logger.warning("\n".join(lines))


def stable_unique(it: Iterable[T]) -> Iterable[T]:
  """Returns unique elements from `it` in the order of occurrence.

  The elements must be hashable.
  """
  return dict.fromkeys(it).keys()


class OrderedSet(Generic[T]):
  elts_set: set[T]
  elts_list: list[T]

  def __init__(self):
    self.elts_set = set()
    self.elts_list = []

  def add(self, elt: T) -> None:
    if elt not in self.elts_set:
      self.elts_set.add(elt)
      self.elts_list.append(elt)

  def update(self, elts: Seq[T]) -> None:
    for e in elts:
      self.add(e)

  def __iter__(self) -> Iterator[T]:
    return iter(self.elts_list)

  def __len__(self) -> int:
    return len(self.elts_list)

  def __contains__(self, elt: T) -> bool:
    return elt in self.elts_set


class HashableWrapper:
  x: Any
  hash: int | None
  def __init__(self, x):
    self.x = x
    try: self.hash = hash(x)
    except: self.hash = None
  def __hash__(self):
    return self.hash if self.hash is not None else id(self.x)
  def __eq__(self, other):
    if not isinstance(other, HashableWrapper):
      return False
    return self.x == other.x if self.hash is not None else self.x is other.x


def _original_func(f: Callable) -> Callable:
  if isinstance(f, property):
    return cast(property, f).fget
  elif isinstance(f, functools.cached_property):
    return f.func
  return f


def set_module(module: str) -> Callable[[T], T]:
  def wrapper(func: T) -> T:
    if module is not None:
      func.__module__ = module
    return func
  return wrapper


def use_cpp_class(cpp_cls: type[Any]) -> Callable[[type[T]], type[T]]:
  """A decorator replacing a Python class with its C++ version at runtime."""

  def wrapper(cls):
    if cpp_cls is None:
      return cls

    exclude_methods = {'__module__', '__dict__', '__doc__'}

    for attr_name, attr in cls.__dict__.items():
      if attr_name not in exclude_methods:
        if not hasattr(_original_func(attr), "_use_cpp"):
          setattr(cpp_cls, attr_name, attr)

    cpp_cls.__doc__ = cls.__doc__
    return cpp_cls

  return wrapper

def use_cpp_method(is_enabled: bool = True) -> Callable[[T], T]:
  """A decorator excluding methods from the set that are forwarded to C++ class."""
  if not isinstance(is_enabled, bool):
    raise TypeError("``is_enabled`` must be a bool")
  def decorator(f):
    if is_enabled:
      original_func = _original_func(f)
      original_func._use_cpp = True
    return f
  return decorator


class StrictABCMeta(abc.ABCMeta):
  """A variant of `abc.ABCMeta` which does not allow virtual subclasses.

  Virtual subclasses support require `abc.ABCMeta` to roundtrip through
  pure Python when doing instance/subclass checking. This if fine for ABCs
  which need virtual subclasses, but is wasteful for the ones which don't.
  """
  def register(cls, subclass):
    del subclass  # Unused.
    raise NotImplementedError(f"{cls} does not support virtual subclasses")

  __instancecheck__ = type.__instancecheck__  # type: ignore[assignment]
  __subclasscheck__ = type.__subclasscheck__  # type: ignore[assignment]


class StrictABC(metaclass=StrictABCMeta):
  __slots__ = ()


test_event_listener: Callable | None = None

def test_event(name: str, *args) -> None:
  if not test_event_listener:
    return
  test_event_listener(name, *args)

if hasattr(jaxlib_utils, "Mutex"):
  Mutex = jaxlib_utils.Mutex


def pprint_bytes(num_bytes: int | float) -> str:
  prefixes = ("", "K", "M", "G", "T")
  if num_bytes <= 0:
    return "0.00B"
  exponent = min(math.floor(math.log(num_bytes, 1000)), len(prefixes) - 1)
  scaled_value = num_bytes / (1000**exponent)
  return f"{scaled_value:.2f}{prefixes[exponent]}B"
