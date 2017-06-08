package;

using InstallTest;

@:asserts
class InstallTest extends TestBase {
	
	@:variant('ada466c')
	@:variant('c294a69')
	public function nightly(sha:String) {
		switchx(['install', sha]);
		asserts.assert(switchx(['use', sha]).exitCode == 0);
		asserts.assert(switchx(['list']).stdout.contains('-> $sha'));
		return asserts.done();
	}
	
	@:variant('3.4.0')
	@:variant('3.4.2')
	public function official(version) {
		asserts.assert(switchx(['install', version]).exitCode == 0);
		asserts.assert(switchx(['list']).stdout.contains('-> $version'));
		return asserts.done();
	}
	
	static function contains(arr:String, v:String)
		return arr.indexOf(v) != -1;
}