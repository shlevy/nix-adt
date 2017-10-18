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
# Pure nix tests of the ADT lib. Intended to exercise all of the type
# checks in the checked variant. These should all throw different errors.

let inherit (import ./.) unchecked checked self-checked-checked;
    tests = adt-lib:
      let inherit (adt-lib) make-type int match;
          test-type = make-type "test.test"
            { unary = int;
              multiary = { foo = int; };
            };
          test-val = test-type.unary 1;
      in { bad-unary = test-type.unary 1.1;
           extra-multiary = test-type.multiary { foo = 1; bar = true; };
           missing-multiary = test-type.multiary {};
           bad-multiary = test-type.multiary { foo = 1.1; };
           bad-ctor-name = make-type "test.bad-ctor-name" { _val = null; };
           bad-arity = make-type "test.bad-arity" { foo = 1; };
           bad-arg-name = make-type "test.bad-arg-name" { foo = { _val = int; }; };
           bad-arg-type = make-type "test.bard-arg-type" { foo = { bar = 1; }; };
           invalid-scrutinee = match 1 {};
           extra-cases = match test-val { unary = _: null; multiary = _: null; extra = true; };
           missing-cases = match test-val { unary = _: null; };
         };
in { tests =
       { unchecked = tests unchecked;
         checked = tests checked;
         self-checked-checked = tests checked;
       };
   }
