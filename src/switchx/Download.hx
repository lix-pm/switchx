package switchx;

import haxe.Timer;
import haxe.io.*;

import haxeshim.node.*;

import js.node.Buffer;
import js.node.Url;
import js.node.Http;
import js.node.http.ClientRequest;
import js.node.http.IncomingMessage;

using tink.CoreApi;
using StringTools;

typedef Directory = String;

class Download {

  static public function text(url:String):Promise<String>
    return bytes(url).next(function (b) return b.toString());
    
  static public function bytes(url:String):Promise<Bytes> 
    return download(url, function (r, cb) buffered(r).handle(cb));
    
  static function buffered(r:IncomingMessage):Promise<Bytes> 
    return Future.async(function (cb) {
      var ret = [];
      r.on('data', ret.push);
      r.on('end', function () {
        cb(Success(Buffer.concat(ret).hxToBytes()));
      });      
    });
    
  static public function archive(url:String, peel:Int, into:String) {
    return download(url, function (res, cb) {
      if (res.headers['content-type'] == 'application/zip')
        unzip(url, into, peel, res, cb);
      else
        untar(url, into, peel, res, cb);
    });
  }
    
  static function unzip(src:String, into:String, peel:Int, res:IncomingMessage, cb:Outcome<String, Error>->Void) {
    buffered(res).next(function (bytes)
      return Future.async(function (cb) {
        var count = 1;
        function done() 
          Timer.delay(function () {
            if (--count == 0) cb(Success(into));
          }, 100);
        Yauzl.fromBuffer(Buffer.hxFromBytes(bytes), function (err, zip) {
          
          if (err != null)
            cb(Failure(new Error(UnprocessableEntity, 'Failed to unzip $src')));
            
          zip.on("entry", function (entry) switch Fs.peel(entry.fileName, peel) {
            case None:
            case Some(f):
              var path = '$into/$f';
              if (!path.endsWith('/')) {
                Fs.ensureDir(path);
                zip.openReadStream(entry, function (e, stream) { 
                  count++;
                  var out = js.node.Fs.createWriteStream(path);
                  stream.pipe(out, { end: true } );
                  out.on('close', done);
                });
              }
              
          });
          zip.on("end", function () {
            zip.close();
            done();
          });
        });            
      })).handle(cb); 
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
  
  static public function tar(url:String, peel:Int, into:String):Promise<Directory>
    return download(url, untar.bind(url, into, peel));

    
  static public function zip(url:String, peel:Int, into:String):Promise<Directory>
    return download(url, unzip.bind(url, into, peel));
      
  static function download<T>(url:String, handler:IncomingMessage->(Outcome<T, Error>->Void)->Void):Promise<T>
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
        
        switch res.headers['location'] {
          case null:
            res.on('error', fail);
            
            handler(res, function (v) {
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