package;

class ListTest extends TestBase {
	public function list() {
		var proc = new Process('node', ['bin/switchx.js','list']);
		return assert(switchx(['list']).exitCode == 0);
	}
}