package switchx;

import js.node.stream.Writable.IWritable;

@:jsRequire('tar')
extern class Tar {
  static function Extract(options: { path:String, ?strip:Int } ):IWritable;
}
