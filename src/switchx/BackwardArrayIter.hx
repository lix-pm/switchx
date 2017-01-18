package switchx;

class BackwardArrayIter<T> {
  var a:Array<T>;
  var pos:Int;
  
  public inline function new(a) {
    this.a = a;
    this.pos = a.length-1;
  }
  public inline function hasNext()
    return pos > -1;
    
  public inline function next()
    return a[pos--];
    
  static public inline function backwards<A>(a:Array<A>)
    return new BackwardArrayIter(a);
}