package switchx;

import haxeshim.*;
import js.Node.*;
import switchx.Version;

using DateTools;
using tink.CoreApi;

class Cli {

  static function main() {
    if (!Scope.exists(Scope.DEFAULT_ROOT)) {
      Fs.ensureDir(Scope.DEFAULT_ROOT+'/');
      Scope.create(Scope.DEFAULT_ROOT, {
        version: 'dummy',
        resolveLibs: Mixed,
      });
    }
    dispatch(Sys.args());
  }
  
  static function dispatch(args:Array<String>) {
    var scope = Scope.seek();
    var api = new Switchx(scope);
    var log =
      if (args.remove('--silent')) function (msg:String) {}
      else function (msg:String) console.log(msg);
    
    log('');
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
        log('Switched to $version');
        return v;
      });
    
    var commands = [
      new Command('install', '[<version>]', 'installs the version if specified, otherwise installs the currently configured version', 
        function (args) return switch args {
          case [v]:
            download(v).next(switchTo);
          case []:
            download(scope.config.version);
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
                
                var lines = ['Official releases:', ''].concat([
                  for (v in o) highlight(v)   
                ]).concat(['', 'Nightly builds:', '']).concat([
                  for (v in n) highlight(v.hash) + v.published.format('  (%Y-%m-%d %H:%M)')
                ]);
                
                process.stdout.write(lines.join('\n'));
                return Noise;
              });
            });
          default:
            new Error('command `list` does expect arguments');
        }
      )
    ];
    
    var command = args.shift();
    
    for (canditate in commands)
      if (canditate.name == command) {
        canditate.exec(args).handle(function (o) Sys.exit(switch o {
          case Failure(e):
            process.stderr.write(e.message);
            e.code;
          default:
            0;
        }));
        return;
      }
      
    process.stderr.write('unknown command $command');
    Sys.exit(404);    
  }
  
}

class Command {
  
  public var name(default, null):String;
  public var args(default, null):String;
  public var doc(default, null):String;
  public var exec(default, null):Array<String>->Promise<Noise>;
  
  public function new(name, args, doc, exec) {
    this.name = name;
    this.args = args;
    this.doc = doc;
    this.exec = exec;
  }
}

//class Install {
  //static public function run(args:Array<String>)
//}