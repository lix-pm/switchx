package;

using StringTools;

@:asserts
class UseTest extends TestBase {
	public function official() {
		switchx(['install', '3.4.0']);
		asserts.assert(switchx(['use', '3.4.0']).exitCode == 0);
		asserts.assert(haxeVer() == '3.4.0');
		switchx(['install', '3.4.2']);
		asserts.assert(switchx(['use', '3.4.2']).exitCode == 0);
		asserts.assert(haxeVer() == '3.4.2');
		return asserts.done();
	}
	
	function contains(arr:String, v:Array<String>) {
		for(v in v) if(arr.indexOf(v) == -1) return false;
		return true;
	}
	
	function haxeVer() {
		var proc = run('haxe', ['-version']);
		var ver = proc.stdout + proc.stderr; // HACK: haxe prints to stderr?!
		return ver.replace('\n', '');
	}
}