# switchx

The help kind of says it all.

```
switchx - haxe version switcher

  Supported commands:

     install [<version>] : installs the version if specified,
                           otherwise installs the currently configured version
      download <version> : downloads the specified version
        switch <version> : switches to the specified version
   scope [create|delete] : creates or deletes the current scope or
                           inspects it if no argument is supplied
                   list  : lists currently downloaded versions

  Supported switches:

                --silent : disables logging
                --global : performs operation on global scope
                 --force : forces re-download

  Version aliases:

           edge, nightly : latest nightly build from builds.haxe.org
                  latest : latest official release from haxe.org
                  stable : latest stable release from haxe.org
```

Note that in `switch` version aliases refer to the latest *installed* version of that kind while otherwise they refer to the latest version *found online*.

## Installation

Not as smooth as it could be, but `npm install switchx -g` basically kind of does it. May only work on Linux.

This is backed by [haxeshim](https://github.com/lix-pm/haxeshim) but installing it globally as a dependency seems to be a nono.


### Building

Ah, here comes the fun part. The simplest way right now is to clone recursively and then `switchx install && haxe all.xhml`.

