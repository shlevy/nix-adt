nix-adt
========

A library for using [algebraic data types][adt-wiki] in the [Nix
expression language][nix-home].

Motivation
-----------

Algebraic data types let you give more structure to your data. In
particular, they enable the use of sum types, safely capturing different
kinds of data into a single data type. For many use cases, ADTs better
reflect the structure of your data than the nix builtin types and it is
easier to reason about how you manipulate and act on your data. Moreover,
ADTs allow a bit more typechecking than you can easily get with nix.

One potential big win for this library is enabling separating out data
from code while keeping both well-structured. See the
[example use case][source-example] for more details.

Interface
-----------

The ADT interface exposes the following:

### make-type

`make-type` takes a type name and a set of constructor specifications,
and returns a value representing the corresponding ADT and allowing
access to the constructors.

The type name is used for type equality computations in typechecking, so
you should probably namespace your types. Be sure to reflect any type
parameters in the type name! See the definition of `option` in the
[standard library][stdlib] for an example.

In a constructor specification, the name gives the constructor a name and
the value specifies the type of the arguments to the constructor. There
are three kinds of values you might use here:

* For nullary constructors, i.e. constructors that take no arguments,
  simply use `null` here.
* For unary constructors, i.e. constructors that take a single argument,
  use a value representing a type here. That could be the result of a
  previous call to `make-type`, or an expression involving one of the
  [primitive type constructors][prim] exposed through the interface.
* For multiary constructors, i.e. constructors that take multiple
  arguments, pass a set whose names are the argument names and whose
  values are the types of the given arguments.

In addition to being usable as a type argument to further calls to `make-type`,
the return value of `make-type` also includes the constructors for the newly-
made type as attributes.

Some names are not allowed as constructor or argument names. The current
list is `[ "_type" "_val" "_val-ty" "__toString" ]`, but to be safe you
should avoid names starting with a leading underscore.

Examples of `make-type` can be found in the [example use case][source-example],
the [standard library][stdlib], and in the
[typechecked implementation][checked] of the ADT interface itself.

### match

`match` lets you [pattern match][match-wiki] on values of ADT types. The
first argument to `match` is the value you want to match on, and the
second argument is a set of cases to handle the different options for that
value.

You must have a single attribute corresponding to each constructor
that the type of the value has (enforced in the typechecking
implementation). If the relevant constructor is nullary, then the value
for that case should simply be a value of the return type of the `match`.
If it is unary or multiary, the value should be a function, either from
the relevant type if unary or from a set of values of the relevant types
if multiary, to a value of the return type of the `match.

The return value of a `match` call depends on how the value passed as
the first argument was constructed. The case corresponding to that
constructor is evaluated, and if the constructor takes any arguments they
are passed to the value. This lets you consume the data stored in values
of an ADT while safely covering all the cases.

Examples of `match` can be found in the [example use case][source-example],
the [standard library][stdlib], and in the
[typechecked implementation][checked] of the ADT interface itself.

### Primitive type constructors

The ADT interface also exposes a number of type constructors corresponding
to various built-in nix types. These can be used in constructor
specifications wherever types are needed.

* `string`: The type of strings and paths.
* `set`: A function from a type to the type of sets whose values are that
         type.
* `list`: A function from a type to the type of lists whose values are that
          type.
* `dict`: A function from a set of types to the type of sets whose keys
          are those given in the input set and whose values have the
	  corresponding types.
* `int`: The type of integers.
* `float`: The type of floating point numbers.
* `function`: The type of functions, irrespective of domain and codomain.
* `any`: A type covering any nix value whatsoever.

Note that, when using the typechecking implementation, no conversions
are performed. So you may need to call `toString` or similar explicit
conversion functions on your values.

### Standard library

The `std` attribute exposes a standard library of ADTs that may be useful.
It is quite sparse for now. See the [implementation][stdlib] for more
details.

Implementations
-----------------

`nix-adt` comes with three implementations of the ADT interface:

* `unchecked` does no typechecking at all beyond what nix does already.
  This results in a more efficient evaluation and requires less
  bookkeeping, at the cost of letting more errors through potentially.
* `checked` does typechecking. Note that neither functions nor match
  statement bodies are statically checked, so the coverage is much less
  useful than you would have with a true static type system. Nevertheless,
  some bugs can be caught this way, at the cost of more computation and
  overhead.
* `self-checked-checked` does typechecking, and additionally the
  typechecking implementation itself (which uses the ADT library under
  the hood) is also typechecked. This can theoretically detect bugs in
  the ADT library.

The real utility of the typechecking modes is yet to be seen, but I
suspect there may be enough value to justify switching to the `checked`
mode when doing final tests before committing, and/or in continuous
integration testing systems.

[adt-wiki]: https://en.wikipedia.org/wiki/Algebraic_data_type
[nix-home]: https://nixos.org/nix/
[source-example]: source-example.nix
[stdlib]: std.nix
[prim]: #primitive-type-constructors
[checked]: checked.nix
[match-wiki]: https://en.wikipedia.org/wiki/Pattern_matching
