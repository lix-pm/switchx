# switchx - Switch Haxe versions like a sir.

This little tool is based on [haxeshim](https://github.com/lix-pm/haxeshim) to switch between coexisting Haxe versions. As for usage, the command line doc pretty much says it all:

```
switchx - haxe version switcher

  Supported commands:

           install [<version>] : installs the version if specified, otherwise
                                 installs the currently configured version
            download <version> : downloads the specified version
              switch <version> : switches to the specified version
   libs [scoped|mixed|haxelib] : sets library resolution strategy
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

Note that in `switch` version aliases refer to the latest *installed* version of that kind while otherwise they refer to the latest version *found online*. Please refer to the [haxeshim doc for library resolution strategies](https://github.com/lix-pm/haxeshim#library-resolution)

## Installation

Not as smooth as it could be, but `npm install haxeshim -g && npm install switchx -g && switchx` basically kind of does it. 

## OS support

For the most parts, please refer to the [haxeshim documentation](https://github.com/lix-pm/haxeshim#os-support). Note though that currently on linux the 64 bit version is always installed. This is a matter of initializing `Switchx.PLATFORM` right.

### Building

Ah, here comes the fun part. The simplest way right now is to:
  
1. install `switchx` first (through npm)
2. clone the source recursively and then run `switchx install` in the checked out directory
3. build with `haxe all.hxml`.