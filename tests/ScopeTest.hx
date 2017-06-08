package;

import haxe.crypto.*;

using haxe.io.Path;
using haxe.Json;
using sys.io.File;
using sys.FileSystem;
using tink.CoreApi;

@:asserts
class ScopeTest extends TestBase {
	
	var dir:String;
	
	@:before
	public function mkdir() {
		dir = Sha1.encode(Std.string(Std.random(999999))).substr(0, 12); // fancy way to make a random folder name
		dir.createDirectory();
		Sys.setCwd(dir);
		return Noise;
	}
	
	@:after
	public function rmrf() {
		Sys.setCwd(TestBase.CWD);
		deleteDirectory(dir);
		return Noise;
	}
	
	public function create() {
		asserts.assert(switchx(['scope', 'create']).exitCode == 0);
		var haxerc = '.haxerc'.getContent().parse();
		asserts.assert(haxerc.version == '3.4.2');
		asserts.assert(haxerc.resolveLibs == 'mixed');
		return asserts.done();
	}
	
	public function delete() {
		switchx(['scope', 'create']);
		asserts.assert(switchx(['scope', 'delete']).exitCode == 0);
		asserts.assert(!'.haxerc'.exists());
		return asserts.done();
	}
	
	public function display() {
		switchx(['scope', 'create']);
		var display = switchx(['scope']);
		asserts.assert(display.exitCode == 0);
		asserts.assert(display.stdout == '[local] ${Sys.getCwd().removeTrailingSlashes()}\n');
		return asserts.done();
	}
}