package switchx;
import js.node.Buffer;
import js.node.stream.Readable.IReadable;

@:jsRequire("yauzl")
extern class Yauzl {

  static function fromBuffer(buf:Buffer, cb:js.Error->YauzlArchive->Void):Void;
  
}

extern interface YauzlArchive extends js.node.events.EventEmitter.IEventEmitter {
  function openReadStream(entry:Dynamic, cb:js.Error->IReadable-> Void):Void;
  function close():Void;
}