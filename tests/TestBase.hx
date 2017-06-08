package;

class TestBase {
	public function new() {}
	
	function switchx(args:Array<String>) {
		return run('node', ['bin/switchx.js'].concat(args));
	}
	
	function run(cmd, args) {
		var proc = new Process(cmd, args);
		var stdout = proc.stdout.readAll().toString();
		var stderr = proc.stderr.readAll().toString();
		trace(stdout);
		trace(stderr);
		return {
			exitCode: proc.exitCode(),
			stdout: stdout,
			stderr: stderr,
		}
	}
}