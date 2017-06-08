package;

@:asserts
class InstallTest extends TestBase {
	public function official() {
		asserts.assert(switchx(['install', '3.4.0']).exitCode == 0);
		
		var list = switchx(['list']).stdout;
		asserts.assert(contains(list, ['3.4.0', '3.4.2']));
		return asserts.done();
	}
	
	function contains(arr:String, v:Array<String>) {
		for(v in v) if(arr.indexOf(v) == -1) return false;
		return true;
	}
}