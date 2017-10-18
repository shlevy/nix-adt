# Copyright 2017 Shea Levy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This is the typechecking implementation of the ADT interface,
# implemented using the adt interface itself. Note that we don't
# try to statically typecheck functions or all the branches of match
# statements, as that would be insane.

let eq-key = x: x; in # Hacky!!! Equality comparison key based on nix's
                      # by-address equality.
adt-lib:
let inherit (adt-lib)
      make-type string set list dict int float function any match std;
    inherit (std) option either set-builder;
    optional-fun = option function;

    # | Reserved keywords
    reserved = [ "_type" "_val" "_val-ty" "__toString" ];

    # | Value of the _type attribute for types generated by this lib.
    type-type = { inherit eq-key adt-lib;
                  __toString = _: "adt-type";
                };
    # | Check if a given value is a type generated by this lib.
    # is-type : any → bool
    is-type = val: (val._type or null) == type-type;

    # | Value of the _type attribute for values generated by ctors
    #   generated by this lib.
    value-type = { inherit eq-key adt-lib;
                   __toString = _: "adt-value";
                 };
    # | Check if a given value is a value generated by a ctor generated
    #   by this lib.
    # is-value : any → bool
    is-value = val: (val._type or null) == value-type;

    # | A user-friendly representation of the type of the given value,
    #   for error messages.
    #
    # !!! TODO Make more sophisticated.
    # type-of : any → string
    type-of = builtins.typeOf;

    ##################################################################
    # Types.                                                         #
    ##################################################################

    # | A type in this library.
    type = make-type "typechecker.type"
             { # | A user-defined type.
               user = { name = string; # ^ The name of the type.
                        ctors = set ctor-arity; # ^ The type's ctors.
                      };
               string = null; # ^ A nix string.
               set = type; # ^ A homogenous set of a given type.
               list = type; # ^ A homogenous list of a given type.
               dict = set type; # ^ A set of the given keys whose values
                                # have the given types.
               int = null; # ^ An integer.
               float = null; # ^ A float.
               function = null; # ^ A function.
               any = null; # ^ Any type.
             };

    # | Extract the name of a type.
    # type-name : type → string
    type-name = ty: match ty
      # We reuse the toString of the parent implementation, ultimately
      # bottoming out at the toString for the unchecked variant.
      { user = builtins.getAttr "name";
        string = toString string;
        set = ty: toString (set ty);
        list = ty: toString (list ty);
        dict = spec: toString (dict spec);
        int = toString int;
        float = toString float;
        function = toString function;
        any = toString any;
      };
    # | Extract the constructors of a type.
    # type-ctors : type → set ctor-arity
    type-ctors = ty: match ty
      { user = builtins.getAttr "ctors";
        string = {};
        set = _: {};
        list = _: {};
        dict = _: {};
        int = {};
        float = {};
        function = {};
        any = {};
      };

    # | Does the value have the given type?
    # has-type : type → any → bool
    has-type = ty: val: match ty
      { # Values of user-defined types have _val-ty set to their type.
        # Types are considered equal if their names are equal!
        user = args: is-value val &&
                     (type-name val._val-ty) == (type-name ty);
        string = let ty = builtins.typeOf val;
                 in ty == "string" || ty == "path";
        int = (builtins.typeOf val) == "int";
        float = (builtins.typeOf val) == "float";
        function = (builtins.typeOf val) == "lambda";
        any = true;
        set = ty:
          let # Values with the wrong type.
              bad-vals = builtins.filter
                (name: !(has-type ty val.${name}))
                (builtins.attrNames val);
          in builtins.isAttrs val && bad-vals == [];
        list = ty:
          let # Values with the wrong type.
              bad-vals = builtins.filter (x: !(has-type ty x)) val;
          in builtins.isList val && bad-vals == [];
        dict = spec:
          let # Values with the wrong type.
              bad-vals = builtins.filter
                (name: !(spec ? ${name} &&
                         has-type spec.${name} val.${name}
                        ))
                (builtins.attrNames val);
              # Values listed in the spec missing from the value.
              missing-vals = builtins.filter
                (name: !(val ? ${name}))
                (builtins.attrNames spec);
          in builtins.isAttrs val &&
             bad-vals == [] &&
             missing-vals == [];
      };

    ##################################################################
    # Constructors.                                                  #
    ##################################################################

    # | The arity of a constructor.
    ctor-arity = make-type "typechecker.ctor-arity"
                   { nullary = null; # ^ A nullary ctor.
                     unary = type; # ^ A unary ctor of the given type.
                     # | A ctor taking a specified set of arguments.
                     multiary = set type;
                   };

    # | Make a constructor (a nix function) corresponding to the
    #   constructor name, arity, and target type provided. The ctor args
    #   are type-checked at construction time.
    # make-ctor : Π (t : type)
    #           , string
    #           → Π (a : ctor-arity)
    #           , function-with-arity-to a t
    make-ctor = ty: name: arity:
      # In general, values of user-defined types are represented by:
      #   { _type = value-type;
      #     _val-ty = ty;
      #     _val = a function from a set of cases to the appropriate case.
      #   }
      # This makes the implementation of the match function trivial modulo
      # typechecking.
      let base = { _type = value-type; _val-ty = ty; }; in match arity
      { nullary = base // { # nullary cases don't take an argument.
                            _val = builtins.getAttr name;
                          };
        unary = arg-ty: arg: if has-type arg-ty arg
          then base // { _val = cases: cases.${name} arg;
                       }
        else throw "bad argument to constructor ${name} of type ${type-name ty}: ${type-name arg-ty} expected, ${type-of arg} found";
        multiary = arg-tys: args:
          let # Extra arguments to the constructor.
              leftovers = removeAttrs args (builtins.attrNames arg-tys);
              leftovers-error =
                throw "unexpected arguments to constructor ${name} of type ${type-name ty}: ${builtins.concatStringsSep ", " (builtins.attrNames leftovers)}";
          in if leftovers != {} then leftovers-error else
          let arg-names = builtins.attrNames args;
              # Missing arguments to the constructor.
              missing = removeAttrs arg-tys arg-names;
              missing-error =
                throw "missing arguments to constructor ${name} of type ${type-name ty}: ${builtins.concatStringsSep ", " (builtins.attrNames missing)}";
          in if missing != {} then missing-error else
          let # Arguments with the wrong types
              bad-args = builtins.filter
                (arg: !(has-type arg-tys.${arg} args.${arg}))
                arg-names;
              bad-args-errors = map
                 (arg: "${arg}: ${type-name arg-tys.${arg}} expected, ${type-of args.${arg}} found")
                 bad-args;
          in if bad-args-errors == []
            then base // { _val = cases: cases.${name} args;
                         }
          else
            throw "bad arguments to constructor ${name} of type ${type-name ty}: ${builtins.concatStringsSep "; " bad-args-errors}";
      };

    ##################################################################
    # Implementation of make-type.                                   #
    ##################################################################

    # | An error when parsing an individual constructor spec.
    check-ctor-error =
      make-type "typechecker.check-ctor-error"
        { no-arity = null; # ^ The arity of the ctor couldn't be
                           # determined;
          bad-arg-name = string; # ^ An argument to the ctor had an invalid
                                 # name.
          bad-arg-type = string; # ^ The argument of the given name had an
                                 # invalid type spec.
        };

    # | Check an individual constructor spec, returning the corresponding
    #   constructor arity if valid.
    # check-ctor : ctor-arity-interface-arg
    #            → either check-ctor-error ctor-arity
    check-ctor = ctor:
      let return-type = either check-ctor-error ctor-arity; in
        if ctor == null
          then return-type.right ctor-arity.nullary
        else if is-type ctor
          then return-type.right (ctor-arity.unary ctor._val)
        else if !(builtins.isAttrs ctor)
          then return-type.left check-ctor-error.no-arity
        else
          let acc-type = either check-ctor-error (set-builder type);
          in match
               (# Fold over each argument in the spec, checking that
                # its name is valid and its value is a type.
                builtins.foldl'
                  (acc: arg-name: match acc
                     { # We already failed, just keep failing.
                       left = _: acc;
                       right = args: let arg = ctor.${arg-name}; in
                         if builtins.elem arg-name reserved
                           then acc-type.left
                             (check-ctor-error.bad-arg-name arg-name)
                         else if is-type arg
                           then acc-type.right ([ { name = arg-name;
                                                    value = arg._val;
                                                  }
                                                ] ++ args)
                         else acc-type.left
                           (check-ctor-error.bad-arg-type arg-name);
                     })
                  (acc-type.right [])
                  (builtins.attrNames ctor))
               { left = return-type.left;
                 right = builder:
                   let arg-tys = builtins.listToAttrs builder; in
                   return-type.right (ctor-arity.multiary arg-tys);
               };

    # | An error when parsing a set of constructor specs passed to
    #   make-type.
    check-ctors-error = make-type "typechecker.check-ctors-error"
      { bad-name = string; # ^ A constructor had a bad name.
        # | A constructor had a bad spec.
        bad-ctor = { name = string; # ^ The constructor name.
                     err = check-ctor-error; # ^ The error when parsing
                                             # the spec.
                   };
      };
    # | Check a set of constructor specs, returning the corresponding set
    #   of constructor arities if valid.
    # check-ctors : ctors-interface-arg
    #             → either check-ctors-error (set ctor-arity)
    check-ctors = ctors:
      let return-type = either check-ctors-error (set ctor-arity);
          acc-type = either check-ctors-error (set-builder ctor-arity);
      in
         match
           (# Fold over each constructor in the spec, checking that its
            # name and arity spec are valid.
            builtins.foldl'
              (acc: ctor-name: match acc
                 { # We already failed, just keep failing.
                   left = _: acc;
                   right = arities: let ctor = ctors.${ctor-name}; in
                     if builtins.elem ctor-name reserved
                       then acc-type.left
                              (check-ctors-error.bad-name ctor-name)
                     else match (check-ctor ctor)
                       { left = err: acc-type.left
                           (check-ctors-error.bad-ctor
                              { name = ctor-name;
                                inherit err;
                              });
                         right = arity: acc-type.right
                           ([ { name = ctor-name;
                                value = arity;
                              }
                            ] ++ arities);
                       };
                 }) (acc-type.right []) (builtins.attrNames ctors))
           { left = return-type.left;
             right = builder:
               return-type.right (builtins.listToAttrs builder);
           };

    self =
      { make-type = name: ctors':
          # This is lazier than might be desirable to enable recursive
          # types. The upshot is you may be able to define and force
          # an invalid call to make-type, and only fail if/when you
          # actually use a constructor.
          let ctors = match (check-ctors ctors')
                { right = ctors: ctors;

                  left = err: throw
                    (match err
                       { bad-name = ctor-name:
                           "type ${name} has bad constructor name ${ctor-name}";
                         bad-ctor = arg: match arg.err
                           { no-arity = "constructor ${arg.name} of type ${name} has no known arity (the value provided is not null, a type, or a set of types)";
                             bad-arg-name = arg-name: "constructor ${arg.name} of type ${name} has bad argument name ${arg-name}";
                             bad-arg-type = arg-name: "argument ${arg-name} of constructor ${arg.name} of type ${name} has a bad type";
                           };
                       });
                };
              ty = type.user { inherit name ctors; };
          in
              { _type = type-type;
                _val = ty;
                __toString = _: name;
              } // (builtins.listToAttrs
                      (map (name:
                              { inherit name;
                                value = make-ctor ty name ctors.${name};
                              }) (builtins.attrNames ctors')));
        match = scrutinee: cases:
          let # We can only pattern match on an ADT value.
              valid-scrutinee = is-value scrutinee;
              ctors = type-ctors scrutinee._val-ty;
              # Cases without corresponding constructors.
              extra-cases =
                removeAttrs cases (builtins.attrNames ctors);
              # Constructors without corresponding cases.
              missing-cases =
                removeAttrs ctors (builtins.attrNames cases);
          in if valid-scrutinee
               then if extra-cases == {}
                 then if missing-cases == {}
                   then scrutinee._val cases
                 else throw "missing cases in match: ${builtins.concatStringsSep ", " (builtins.attrNames missing-cases)}"
               else throw "extra cases in match: ${builtins.concatStringsSep ", " (builtins.attrNames extra-cases)}"
             else throw "non-ADT scrutinee in match";
        string = { _type = type-type;
                   _val = type.string;
                   __toString = self: type-name self._val;
                 };
        set = ty: { _type = type-type;
                    _val = type.set ty;
                    __toString = self: type-name self._val;
                  };
        list = ty: { _type = type-type;
                     _val = type.list ty;
                     __toString = self: type-name self._val;
                   };
        dict = spec: { _type = type-type;
                       _val = type.list spec;
                       __toString = self: type-name self._val;
                     };
        int = { _type = type-type;
                _val = type.int;
                __toString = self: type-name self._val;
              };
        float = { _type = type-type;
                  _val = type.float;
                  __toString = self: type-name self._val;
                };
        function = { _type = type-type;
                     _val = type.function;
                     __toString = self: type-name self._val;
                   };
        any = { _type = type-type;
                _val = type.any;
                __toString = self: type-name self._val;
              };
        std = import ./std.nix self;
      };
in self
