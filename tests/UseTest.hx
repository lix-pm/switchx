package;

using StringTools;

@:asserts
class UseTest extends TestBase {
	
	@:variant('ada466c', '3.4.2')
	@:variant('c294a69', '4.0.0')
	public function nightly(sha:String, version:String) {
		switchx(['install', sha]);
		asserts.assert(switchx(['use', sha]).exitCode == 0);
		asserts.assert(haxeVer() == '$version (git build development @ $sha)');
		return asserts.done();
	}
	
	@:variant('3.4.0')
	@:variant('3.4.2')
	public function official(version:String) {
		switchx(['install', version]);
		asserts.assert(switchx(['use', version]).exitCode == 0);
		asserts.assert(haxeVer() == version);
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