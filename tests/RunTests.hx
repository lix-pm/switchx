package;

import tink.testrunner.*;
import tink.unit.*;

class RunTests {
	static function main() {
		Runner.run(TestBatch.make([
			new ListTest(),
			new InstallTest(),
			new UseTest(),
			new ScopeTest(),
		])).handle(Runner.exit);
	}
}