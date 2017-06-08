package;

class TestBase {
	public function new() {}
	
	function switchx(args:Array<String>) {
		return run('node', ['bin/switchx.js'].concat(args));
	}
	
	function run(cmd, args) {
		var proc = new Process(cmd, args);
		return {
			exitCode: proc.exitCode(),
			stdout: proc.stdout.readAll().toString(),
			stderr: proc.stderr.readAll().toString(),
		}
	}
}