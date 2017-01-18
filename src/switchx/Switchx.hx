package switchx;

import haxe.io.Bytes;
import haxe.io.Path;
import switchx.Version;
import sys.io.File;

using switchx.BackwardArrayIter;
using tink.CoreApi;
using DateTools;
using StringTools;
using sys.FileSystem;
using haxe.Json;

@:forward(iterator, length)
abstract Nightlies(Array<Pair<String, Date>>) {
  
  public function new(v:Array<Pair<String, Date>>) {
    v = v.copy();
    v.sort(function (a, b) return Reflect.compare(b.b.getTime(), a.b.getTime()));
    this = v;
  }
  
  @:arrayAccess public inline function get(index:Int)
    return this[index];
}

class Switchx {
  
  var scope:haxeshim.Scope;
  var haxelibs:String;
  var versions:String;
  var downloads:String;
  
  var root(get, never):String;
    function get_root() return scope.haxeshimRoot;
    
  public function new(scope) {
    this.scope = scope;
    
    Fs.ensureDir(this.versions = '$root/versions/');
    Fs.ensureDir(this.downloads = '$root/downloads/');
    Fs.ensureDir(this.haxelibs = '$root/haxelibs/');
  }
  
  static var VERSION_INFO = 'version.json';  
  static var NIGHTLIES = 'http://hxbuilds.s3-website-us-east-1.amazonaws.com/builds/haxe';
  static var PLATFORM =
    switch Sys.systemName() {
      case 'Windows': 'windows';
      case 'Mac': 'mac';
      default: 'linux64';
    } 
  
  static function linkToNightly(hash:String, date:Date)
    return date.format('$NIGHTLIES/$PLATFORM/haxe_%Y-%m-%d_development_$hash.tar.gz');
    
  static public function officialOnline():Promise<Array<String>>
    return Download.text('https://raw.githubusercontent.com/HaxeFoundation/haxe.org/staging/downloads/versions.json')
      .next(function (s) {
        return (s.parse().versions : Array<{ version: String }>).map(function (v) return v.version);
      });
    
  static public function nightliesOnline():Promise<Nightlies> {
    return Download.text('$NIGHTLIES/$PLATFORM/').next(function (s:String) {
      var lines = s.split('------------------\n').pop().split('\n');
      var ret = [];
      for (l in lines) 
        switch l.trim() {
          case '':
          case v:
            if (v.indexOf('_development_') != -1)
              switch v.indexOf('   ') {
                case -1: //whatever
                case v.substr(0, _).split(' ') => [_.split('-').map(Std.parseInt) => [y, m, d], _.split(':').map(Std.parseInt) => [hh, mm]]:
                  
                  ret.push(new Pair(
                    v.split('_development_').pop().split('.').shift(),
                    new Date(y, m - 1, d, hh, mm, 0)
                  ));
                  
                default:
                  
              }
            
        }      
      return new Nightlies(ret);
    });
  } 
  
  
  function resolve(version:UserVersion, getOfficial:Void->Promise<Array<String>>, getNightlies:Void->Promise<Nightlies>):Promise<ResolvedVersion>
    return switch version {
      case UEdge: 
        
        getNightlies().next(function (v) return RNightly(v[0].a, v[0].b));
        
      case ULatest:
        
        getOfficial().next(function (v) return ROfficial(v[v.length - 1]));
        
      case UStable: 
        
        getOfficial().next(function (v) {
          for (v in v.backwards())
            if (v.indexOf('-') == -1)
              return ROfficial(v);
          throw 'assert';
        });
        
      case UNightly(hash): 

        getNightlies().next(function (v) {
          for (n in v)
            if (n.a == hash)
              return Success(RNightly(n.a, n.b));
              
          return Failure(new Error(NotFound, 'Unknown nightly $version'));
        });
        
      case UOfficial(version): 
        
        getOfficial().next(function (v)
          return switch v.indexOf(version) {
            case -1: Failure(new Error(NotFound, 'Unknown version $version'));
            default: Success(ROfficial(version));
          }
        );
    }  
    
  function isDownloaded(r:ResolvedVersion)
    return '$versions/${r.id}'.exists();
    
  function linkToOfficial(version)
    return 
      'http://haxe.org/website-content/downloads/$version/downloads/haxe-$version-' + switch Sys.systemName() {
        case 'Windows': 'win.zip';
        case 'Mac': 'osx.tar.gz';
        default: 'linux64.tar.gz';
      }
  
  function replace(target:String, replacement:String, archiveAs:String)
    if (target.exists()) {
      var old = '$downloads/$archiveAs${Math.floor(target.stat().ctime.getTime())}';
      target.rename(old);
      replacement.rename(target);
    }
    else {
      replacement.rename(target);
    }
      
  public function download(version:UserVersion, options:{ force: Bool }):Promise<ResolvedVersion>
    return resolve(version, officialOnline, nightliesOnline).next(function (r) return switch r {
      case isDownloaded(_) => true if (options.force != true):
        trace('Version ${r.id} is already downloaded'); 
        Future.sync(Success(r));
        
      case RNightly(hash, date):
        
        Download.tar(linkToNightly(hash, date), 1, '$downloads/$hash@${Math.floor(Date.now().getTime())}').next(function (dir) {
          File.saveContent('$dir/$VERSION_INFO', haxe.Json.stringify({
            published: Date.now().toString(),
          }));
          
          replace('$versions/$hash', dir, hash);
          return r;
        });
        
      case ROfficial(version):
        
        var url = linkToOfficial(version),
            tmp = '$downloads/$version@${Math.floor(Date.now().getTime())}';
            
        var ret = 
          switch Path.extension(url) {
            case 'zip': 
              Download.zip(url, 1, tmp);
            default:
              Download.tar(url, 1, tmp);
          }
          
        ret.next(function (dir) {
          replace('$versions/$version', dir, version);
          return r;          
        });
    });  
  
}