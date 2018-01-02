package switchx;

import haxeshim.*;
import haxeshim.LibResolution;
import js.Node.*;
import Sys.*;
import switchx.Version;

using DateTools;
using tink.CoreApi;
using StringTools;
using sys.FileSystem;

class Cli {
  
  var api:Switchx;
  var force:Bool;
  
  public function new(api, force) {
    this.api = api;
    this.force = force;
  }

  static function ensureGlobal() 
    return 
      Future.async(function (cb) {

        function done() 
          cb(Scope.seek());

        if (Scope.exists(Scope.DEFAULT_ROOT)) done();
        else {
          
          println("It seems you're running switchx for the first time.\nPlease wait for basic setup to finish ...");
          
          Fs.ensureDir(Scope.DEFAULT_ROOT + '/');
          
          Scope.create(Scope.DEFAULT_ROOT, {
            version: 'stable',
            resolveLibs: Mixed,
          });
          
          dispatch(['install', '--global'], function () {
            println('... done setting up global Haxe version');
            done();
          });
        }
      });

  static function ensureNeko(global:Scope) {

    var neko = Neko.PATH;

    return
      if (neko.exists()) 
        Future.sync(neko);
      else {
        
        println('Neko seems to be missing. Attempting download ...');

        (switch systemName() {
          case 'Windows': Download.zip.bind('https://github.com/HaxeFoundation/neko/releases/download/v2-2-0/neko-2.2.0-win.zip');
          case 'Mac': Download.tar.bind('https://github.com/HaxeFoundation/neko/releases/download/v2-2-0/neko-2.2.0-osx64.tar.gz');
          default: Download.tar.bind('https://github.com/HaxeFoundation/neko/releases/download/v2-2-0/neko-2.2.0-linux64.tar.gz');
        })(1, neko).recover(Command.reportError).map(function (x) {
          println('done');
          return x;
        });
      }
  }

  static function main() {
    ensureGlobal().flatMap(ensureNeko).handle(dispatch.bind(args()));
  }

  public function download(version:String) {

    return (switch ((version : UserVersion) : UserVersionData) {
      case UNightly(_) | UOfficial(_): 
        api.resolveInstalled(version);
      default: 
        Promise.lift(new Error('$version needs to be resolved online'));
    }).tryRecover(function (_) {
      log('Looking up Haxe version "$version" online');
      return api.resolveOnline(version).next(function (r) {
        log('  Resolved to $r.');
        return r;
      });
    }).next(function (r) {
      return api.download(r, { force: force }).next(function (wasDownloaded) {
        
        log(
          if (!wasDownloaded)
            '  ... already downloaded!'
          else
            ''
        );
        
        return r;
      });
    });
  }
  
  function log(s:String)
    if (!api.silent) Sys.println(s);

  public function switchTo(version:ResolvedVersion)
    return api.switchTo(version).next(function (v) {
      log('Now using $version');
      return v;
    });  

  public function makeCommands() {
    var scope = api.scope;

    return [
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
      new Command('use', '<version>', 'switches to the specified version',
        function (args) return switch args {
          case [v]: api.resolveInstalled(v).next(switchTo);
          case []: new Error('not enough arguments');
          case v: new Error('too many arguments');
        }
      ),
      new Command('scope', '[create|delete|set]\n[scoped|mixed|haxelib]', 'creates, deletes or configures\nthe current scope or inspects it\nif no argument is supplied',
        function (args) return switch args[0] {
          case 'set':
            switch args.slice(1) {
              case []: new Error('not enough arguments');
              case [v]: 
                
                LibResolution.parse(v).map(function (v) {
                  scope.reconfigure({
                    version: scope.config.version,
                    resolveLibs: v
                  });
                  return Noise;
                });

              case v: new Error('too many arguments');              
            }
          case 'create':
            Promise.lift(switch args.slice(1) {
              case []: if (scope.isGlobal) Scoped else scope.config.resolveLibs;
              case [v]: LibResolution.parse(v);
              default: new Error('too many arguments');
            }).next(function (resolution) return {
              Scope.create(scope.cwd, {
                version: scope.config.version,
                resolveLibs: if (scope.isGlobal) Scoped else scope.config.resolveLibs,
              });
              return Noise;
            });
          case 'delete':
            if (scope.isGlobal)
              new Error('Cannot delete global scope');
            else {
              scope.delete();
              log('deleted scope in ${scope.scopeDir}');
              Noise;
            }
          case null: 
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
                println('Using ${(scope.config.version:UserVersion)}');
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
    ];
  }

  static function dispatch(args:Array<String>, ?cb) {

    var scope = Scope.seek({ cwd: if (args.remove('--global')) Scope.DEFAULT_ROOT else null });
    
    var cli = new Cli(new Switchx(scope, args.remove('--silent')), args.remove('--force'));
    
    Command.dispatch(args, 'switchx - haxe version switcher', cli.makeCommands(), [
      new Named('Supported switches', [
        new Named('--silent', 'disables logging'),
        new Named('--global', 'performs operation on global scope'),
        new Named('--force', 'forces re-download'),
      ]),
      ALIASES,
    ]).handle(function (o) {
      Command.reportOutcome(o);
      if (cb != null) cb();
    });
  }
  
  static public var ALIASES = new Named('Version aliases', [
    new Named('edge, nightly', 'latest nightly build from builds.haxe.org'),
    new Named('latest', 'latest official release from haxe.org'),
    new Named('stable', 'latest stable release from haxe.org'),
  ]);
}