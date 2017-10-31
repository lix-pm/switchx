package switchx;

import js.node.stream.Writable.IWritable;

@:jsRequire('unzipper')
extern class Unzip {
  static function Extract(options: { path:String, ?strip:Int } ):IWritable;  
}