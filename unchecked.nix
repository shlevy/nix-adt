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
# This is the primitive implementation of the ADT interface, with no
# typechecking beyond that performed by nix's evaluator.

let self = { make-type =
               name: ctors: { __toString = _: name; } //
                 builtins.listToAttrs
                   (map (name:
                           { inherit name;
                             # Values of ADTs just select the right case
                             # and pass the right args.
                             value = if ctors.${name} == null
                                       then builtins.getAttr name
                                     else args: cases:
                                       cases.${name} args;
                           }) (builtins.attrNames ctors));
             match = scrutinee: scrutinee;
             # Types are just strings for nice messages.
             string = "string";
             set = ty: "set of ${ty}";
             list = ty: "list of ${ty}";
             dict = spec: "dictionary with key-type pairs { ${
               builtins.concatStringsSep 
                 ""
                 (map
                    (key: "${key} = ${spec.${key}}; ")
                    (builtins.attrNames spec))
             }}";
             int = "integer";
             float = "float";
             function = "function";
             any = "any";
             std = import ./std.nix self;
           };
in self
