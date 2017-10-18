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
# This is the entry point to the ADT library. See the README for details.

rec { # An implementation of the ADT interface with no typechecking.
      unchecked = import ./unchecked.nix;
      # An implementation of the ADT interface with typechecking.
      checked = import ./checked.nix unchecked;
      # An implementation of the ADT interface with typechecking, which
      # is itself type-checked.
      self-checked-checked = import ./checked.nix checked;
    }
