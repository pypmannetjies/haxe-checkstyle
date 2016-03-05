package checkstyle;

@:enum
@SuppressWarnings('checkstyle:MemberName')
abstract SeverityLevel(String) from String {
	var INFO = "INFO";
	var WARNING = "WARNING";
	var ERROR = "ERROR";
	var IGNORE = "IGNORE";
}

typedef LintMessage = {
	var fileName:String;
	var message:String;
	var line:Int;
	var startColumn:Int;
	var endColumn:Int;
	var severity:SeverityLevel;
	var moduleName:String;
}