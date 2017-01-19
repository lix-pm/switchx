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
    
    var commands = [
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
    ];
    
    switch args.shift() {
      case null:
        println('switchx - haxe version switcher');
        println('');
        var prefix = 0;
        
        for (c in commands) {
          var cur = c.name.length + c.args.length;
          if (cur > prefix)
            prefix = cur;
        }
        
        prefix += 7;
        
        var prefix = [for (i in 0...prefix) ' '].join('');
        
        function pad(s:String)
          return s.lpad(' ', prefix.length);
          
        println('  Supported commands:');
        println('');
        
        for (c in commands) {
          var s = '  ' + c.name+' ' + c.args + ' : ';
          println(pad(s) + c.doc.replace('\n', '\n$prefix'));
        }
        
        println('');
        println('  Supported switches:');
        println('');
        println(pad('--silent : ') + 'disables logging');
        println(pad('--global : ') + 'performs operation on global scope');
        println(pad('--force : ') + 'forces re-download');
        println('');
        println('  Version aliases:');
        println('');
        println(pad('edge, nightly : ') + 'latest nightly build from builds.haxe.org');
        println(pad('latest : ') + 'latest official release from haxe.org');
        println(pad('stable : ') + 'latest stable release from haxe.org');
        println('');
        exit(0);
        
      case command:
        
        for (canditate in commands)
          if (canditate.name == command) {
            canditate.exec(args).handle(function (o) switch o {
              case Failure(e):
                process.stderr.write(e.message + '\n\n');
                exit(e.code);
              default:
                if (cb != null) {
                  cb();
                  return;
                }
                exit(0);
            });
            return;
          }
          
        process.stderr.write('unknown command $command\n\n');
        exit(404);    
    }    
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