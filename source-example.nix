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
# An example of using the ADT lib for specifying source locations as data.
#
# The basic idea here is we want in one location to specify as data where
# our sources come from, and in another location consume that data to
# actually resolve the source. Since there are different kinds of sources,
# we really want sum types here. And now we have them!

let example = adt-lib:
      let inherit (adt-lib) make-type match string std;
          inherit (std) option;
          option-string = option string;
          # | The type of source specifications.
          source = make-type "test.source"
            { # | An ordinary nix path.
              path = string;
              # | A git repo.
              git = { # | The URL where the repo lives.
                      url = string;
                      # | The remote ref to fetch.
                      ref = string;
                      # | Optionally, the revision to check out.
                      rev = option-string;
                    };
              # | First look up in the nix path, falling back to a
              #   different path if the entry can't be found.
              nix-path-or-fallback = { # | The path to look up.
                                       path = string;
                                       # | The fallback source location.
                                       fallback = source;
                                     };
            };
          # | A smart constructor for git sources that sets a default value
          #   for the rev.
          git = args:
            source.git ({ rev = option-string.none; } // args);
          # | Convert a source specification to an actual store-path
          #   source.
          # source-to-intput : source → NixPath
          source-to-input = src: match src
            { # If we already have a path, we're happy.
              path = p: p;
              # Use fetchgit to, well, fetch git.
              git = { url, ref, rev }:
                builtins.fetchgit { inherit url ref;
                                    # Pass rev, if we had one.
                                    rev = match rev
                                      { none = "";
                                        some = r: r;
                                      };
                                  };
              # Try to lookup and fallback if need be
              nix-path-or-fallback = { path, fallback }:
                let # Safely try to lookup in path
                    try = builtins.tryEval
                      (builtins.findFile builtins.nixPath path);
                in if try.success
                     then try.value
                     else source-to-input fallback;
            };
          # An example of a source spec.
          source-example = { nixpkgs = source.nix-path-or-fallback
                               { # We'll try to use <nixpkgss>
                                 # The extra 's' is just so most users
                                 # will experience the fallback. Simply
                                 # add an entry for nixpkgss to your
                                 # NIX_PATH to illustrate the non-fallback
                                 # case.
                                 path = "nixpkgss";
                                 # If <nixpkgss> doesn't exist, pull from
                                 # github.
                                 fallback = git
                                   { url = "git://github.com/NixOS/nixpkgs.git";
                                     ref = "master";
                                     # Note we don't need to specify 'rev'.
                                   };
                               };
                           };
      in # An example of consuming a source spec
         source-to-input source-example.nixpkgs;
    inherit (import ./.) unchecked checked self-checked-checked;
   # Evaluate the example in all three variants of the adt interface.
in { unchecked = example unchecked;
     checked = example checked;
     self-checked-checked = example checked;
   }
