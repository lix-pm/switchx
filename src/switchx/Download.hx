package switchx;

import haxe.Timer;
import haxe.io.*;

import haxeshim.node.*;

import js.node.Buffer;
import js.node.Url;
import js.node.Http;
import js.Node.*;
import js.node.http.ClientRequest;
import js.node.http.IncomingMessage;

//using js.node.Readline;
using tink.CoreApi;
using StringTools;

typedef Directory = String;

private typedef Handler<T> = String->IncomingMessage->(Outcome<T, Error>->Void)->Void;

class Download {

  static public function text(url:String):Promise<String>
    return bytes(url).next(function (b) return b.toString());
    
  static public function bytes(url:String):Promise<Bytes> 
    return download(url, function (_, r, cb) buffered(r).handle(cb));
    
  static function buffered(r:IncomingMessage):Promise<Bytes> 
    return Future.async(function (cb) {
      var ret = [];
      r.on('data', ret.push);
      r.on('end', function () {
        cb(Success(Buffer.concat(ret).hxToBytes()));
      });      
    });
    
  static public function archive(url:String, peel:Int, into:String, ?message:String) {
    return download(url, withProgress(message, function (finalUrl:String, res, cb) {
      if (res.headers['content-type'] == 'application/zip' || url.endsWith('.zip') || finalUrl.endsWith('.zip'))
        unzip(url, into, peel, res, cb);
      else
        untar(url, into, peel, res, cb);
    }));
  }
    
  static function unzip(src:String, into:String, peel:Int, res:IncomingMessage, cb:Outcome<String, Error>->Void) {
    res
      .pipe(Unzip.Extract( { path: into, strip: peel } ))
    .on('error', function (e:js.Error) {
      cb(Failure(new Error(UnprocessableEntity, 'Failed to unzip $src into $into because $e')));
    }).on('close', function () {
      cb(Success(into));
    });
  }
  static function untar(src:String, into:String, peel:Int, res:IncomingMessage, cb:Outcome<String, Error>->Void) {
    res
      .pipe(js.node.Zlib.createGunzip())
      .pipe(Tar.Extract( { path: into, strip: peel } ))
    .on('error', function (e:js.Error) {
      cb(Failure(new Error(UnprocessableEntity, 'Failed to untar $src into $into because $e')));
    }).on('close', function () {
      cb(Success(into));
    });
  }
  
  static public function tar(url:String, peel:Int, into:String, ?message:String):Promise<Directory>
    return download(url, withProgress(message, untar.bind(_, into, peel)));

    
  static public function zip(url:String, peel:Int, into:String, ?message:String):Promise<Directory>
    return download(url, withProgress(message, unzip.bind(_, into, peel)));

  static function withProgress<T>(?message:String, handler:Handler<T>):Handler<T> {
    return 
      if (message == null || !process.stdout.isTTY) handler;
      else function (url:String, msg:IncomingMessage, cb:Outcome<T, Error>->Void) {
        var total = Std.parseInt(msg.headers.get('content-length')),
            loaded = 0;
        
        function progress(s:String)
          untyped {
            process.stdout.clearLine(0);
            process.stdout.cursorTo(0);
            process.stdout.write(message + s);
          }

        msg.on('data', function (buf) {
          loaded += buf.length;
          progress(Std.string(Math.round(1000 * loaded / total) / 10) + '%');
        });
        handler(url, msg, cb);
      }
  }
      
  static function download<T>(url:String, handler:Handler<T>):Promise<T>
    return Future.async(function (cb) {
      
      var options:HttpRequestOptions = cast Url.parse(url);
      
      options.agent = false;
      if (options.headers == null)
        options.headers = {};
      options.headers['user-agent'] = Download.USER_AGENT;
      
      function fail(e:js.Error)
        cb(Failure(tink.core.Error.withData('Failed to download $url because ${e.message}', e)));
        
      var req = 
        if (url.startsWith('https:')) js.node.Https.get(cast options);
        else js.node.Http.get(options);
      
      req.setTimeout(30000);
      req.on('error', fail);
      
      req.on(ClientRequestEvent.Response, function (res) {
        if (res.statusCode >= 400) 
          cb(Failure(Error.withData(res.statusCode, res.statusMessage, res)));
        else
          switch res.headers['location'] {
            case null:
              res.on('error', fail);
              
              handler(url, res, function (v) {
                switch v {
                  case Success(x): cb(Success(x));
                  case Failure(e): cb(Failure(e));
                }
              });
            case v:
              
              download(switch Url.parse(v) {
                case { protocol: null }:
                  options.protocol + '//' + options.host + v;
                default: v;
              }, handler).handle(cb);
          }
        });
    });
    
  static public var USER_AGENT = 'switchx';
}
