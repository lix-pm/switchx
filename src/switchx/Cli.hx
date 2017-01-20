package switchx;

import haxeshim.*;
import haxeshim.LibResolution;
import js.Node.*;
import Sys.*;
import switchx.Version;

using DateTools;
using tink.CoreApi;
using StringTools;

class Cli {

  static function main() {
    if (!Scope.exists(Scope.DEFAULT_ROOT)) {
      
      println("It seems you're running switchx for the first time.\nPlease wait for basic setup to finish ...");
      
      Fs.ensureDir(Scope.DEFAULT_ROOT + '/');
      
      Scope.create(Scope.DEFAULT_ROOT, {
        version: 'stable',
        resolveLibs: Mixed,
      });
      
      dispatch(['install', '--global'], function () {
        dispatch(args());
      });
      return;
    }
    dispatch(args());
  }
  
  static function dispatch(args:Array<String>, ?cb) {
    var global = args.remove('--global');
    
    var scope = Scope.seek({ cwd: if (global) Scope.DEFAULT_ROOT else null });
    
    var api = new Switchx(scope);
    
    var log =
      if (args.remove('--silent')) function (msg:String) {}
      else function (msg:String) Sys.println(msg);
    
    var force = args.remove('--force');
    
    function download(version:String) {
      log('Looking up Haxe version "$version"');
      return api.resolveOnline(version).next(function (r) {
        log('  Resolved to $r. Downloading ...');
        return api.download(r, { force: force }).next(function (wasDownloaded) {
          
          log(
            if (!wasDownloaded)
              '  ... already downloaded!'
            else
              '  ... download complete!'
          );
          
          return r;
        });
      });
    }
    
    function switchTo(version:ResolvedVersion)
      return api.switchTo(version).next(function (v) {
        log('Now using $version');
        return v;
      });
    
    Command.dispatch(args, 'switchx - haxe version switcher', [
      new Command('install', '[<version>]', 'installs the version if specified, otherwise\ninstalls the currently configured version', 
        function (args) return switch args {
          case [v]:
            download(v).next(switchTo);
          case []:
            download(scope.config.version).next(switchTo);
          case v:
            new Error('command `install` accepts one argument at most (i.e. the version)');
        }
      ),
      new Command('download', '<version>', 'downloads the specified version',
        function (args) return switch args {
          case [v]: download(v);
          case []: new Error('not enough arguments');
          case v: new Error('too many arguments');
        }
      ),
      new Command('switch', '<version>', 'switches to the specified version',
        function (args) return switch args {
          case [v]: api.resolveInstalled(v).next(switchTo);
          case []: new Error('not enough arguments');
          case v: new Error('too many arguments');
        }
      ),
      new Command('libs', '[scoped|mixed|haxelib]', 'sets library resolution strategy',
        function (args) return switch args {
          case []: new Error('not enough arguments');
          case [v]: 
            
            var options = [
              'scoped' => Scoped,
              'mixed' => Mixed,
              'haxelib' => Haxelib,
            ];
            
            if (options.exists(v)) {
              scope.reconfigure({
                version: scope.config.version,
                resolveLibs: options[v]
              });
              Noise;
            }
            else new Error('unknown strategy $v');
          case v: new Error('too many arguments');
        }
      ),
      new Command('scope', '[create|delete]', 'creates or deletes the current scope or\ninspects it if no argument is supplied',
        function (args) return switch args {
          case ['create']:
            Scope.create(scope.cwd, {
              version: scope.config.version,
              resolveLibs: if (scope.isGlobal) Scoped else scope.config.resolveLibs,
            });
            log('created scope in ${scope.cwd}');
            Noise;
          case ['delete']:
            if (scope.isGlobal)
              new Error('Cannot delete global scope');
            else {
              scope.delete();
              log('deleted scope in ${scope.scopeDir}');
              Noise;
            }
          case []: 
            println(
              (if (scope.isGlobal) '[global]'
              else '[local]') + ' ${scope.scopeDir}'
            );
            Noise;
          case v: 
            new Error('Invalid arguments');
        }
      ),
      new Command('list', '', 'lists currently downloaded versions',
        function (args) return switch args {
          case []:
            api.officialInstalled(IncludePrereleases).next(function (o) {
              return api.nightliesInstalled().next(function (n) {
                function highlight(s:String)
                  return
                    if (s == scope.config.version)
                      ' -> $s';
                    else
                      '    $s';
                
                println('');
                println('Official releases:');
                println('');
                
                for (v in o) 
                  println(highlight(v));
                
                if (n.iterator().hasNext()) {
                  println('');
                  println('Nightly builds:');
                  println('');
                  
                  for (v in n) 
                    println(highlight(v.hash) + v.published.format('  (%Y-%m-%d %H:%M)'));
                }
                
                println('');
                
                return Noise;
              });
            });
          default:
            new Error('command `list` does expect arguments');
        }
      )
    ], [
      new Named('Supported switches', [
        new Named('--silent', 'disables logging'),
        new Named('--global', 'performs operation on global scope'),
        new Named('--force', 'forces re-download'),
      ]),
      new Named('Version aliases', [
        new Named('edge, nightly', 'latest nightly build from builds.haxe.org'),
        new Named('latest', 'latest official release from haxe.org'),
        new Named('stable', 'latest stable release from haxe.org'),
      ])
    ]).handle(Command.reportError);
  }
  
}