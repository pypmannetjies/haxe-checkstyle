import haxe.Json;
import sys.io.File;
import sys.io.FileOutput;
import checks.CheckTestCase;
import token.TokenTreeBuilderTest;
import mcover.coverage.client.PrintClient;
import mcover.coverage.data.CoverageResult;
import mcover.coverage.data.Statement;
import mcover.coverage.MCoverage;

using StringTools;

class TestMain {

	public function new() {
		CompileTime.importPackage("checks");

		var runner = new haxe.unit.TestRunner();
		runner.add(new TokenTreeBuilderTest());

		var tests = CompileTime.getAllClasses(CheckTestCase);
		for (testClass in tests) runner.add(Type.createInstance(testClass, []));

		var success = runner.run();
		setupCoverageReport();
		Sys.exit(success ? 0 : 1);
	}

	static function setupCoverageReport() {
		var client:PrintClient = new PrintClient();
		var logger = MCoverage.getLogger();
		logger.addClient(client);
		logger.report();

		var report = { coverage: {} };
		var classes = logger.coverage.getClasses();
		for (cls in classes) {
			var coverageData = [null];
			var results:CoverageResult = cls.getResults();
			for (i in 1 ... results.l) coverageData[i] = true;
			var c = cls.name.replace(".", "/") + ".hx";

			var missingStatements:Array<Statement> = cls.getMissingStatements();
			for (stmt in missingStatements) {
				for (line in stmt.lines) coverageData[line] = false;
			}

			Reflect.setField(report.coverage, c, coverageData);
		}

		var file:FileOutput = File.write("coverage.json");
		file.writeString(Json.stringify(report));
		file.close();
	}

	static function main() {
		new TestMain();
	}
}