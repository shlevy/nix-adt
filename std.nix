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
# A standard library of ADTs and functions over them. This is added to
# opportunistically.

adt-lib:
  let inherit (adt-lib) make-type dict string list match;
  in { # | Polymorphic optional type.
       option = t: make-type "std.option ${t}"
         { some = t;
           none = null;
         };
       # | Polymorphic sum type.
       either = l: r: make-type "std.either ${l} ${r}"
         { left = l;
           right = r;
         };
       # | A type for efficiently incrementally building a set of a given
       #   type, i.e. the type expected by builtins.listToAttrs, i.e.
       #   name-value pairs.
       set-builder = ty: list (dict { name = string; value = ty; });
     }
