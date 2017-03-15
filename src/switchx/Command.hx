package switchx;

import js.Node.*;
import Sys.*;

using StringTools;
using tink.CoreApi;

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
  
  static public function reportError(e:Error):Dynamic {
    stderr().writeString(e.message + '\n\n');
    Sys.exit(e.code);    
    return null;
  }

  static public function reportOutcome(o:Outcome<Noise, Error>)
    switch o {
      case Failure(e): reportError(e);
      default:
    }
  
  static public function dispatch(args:Array<String>, title:String, commands:Array<Command>, extras:Array<Named<Array<Named<String>>>>):Promise<Noise> 
    return 
      switch args.shift() {
        case null:
          println(title);
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
          
          for (e in extras) {
            println('');
            println('  ${e.name}');
            println('');
            for (e in e.value)
              println(pad('${e.name} : ') + e.value);
          }
          println('');
          Noise;
          
        case command:
          
          for (canditate in commands)
            if (canditate.name == command) 
              return canditate.exec(args);
          
          return new Error(NotFound, 'unknown command $command');
      }        
}