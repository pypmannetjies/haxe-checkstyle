package checkstyle;

import sys.io.File;

import haxe.macro.Expr;

import haxeparser.HaxeLexer;

import haxeparser.Data.Token;
import haxeparser.Data.TokenDef;

class TreeTokenizer {

	public static function makeTokenTree(tokens:Array<Token>):TokenTree {
		var root:TokenTree = new TokenTree(null, null);
		var stream:TokenStream = new TokenStream(tokens);
		walkTokens(stream, root);
		trace (root);
		return root;
	}

	//static function walkFile(stream:TokenStream, parent:TokenTree):TokenTree {
	//    var newChild:TokenTree = null;
	//    while (stream.hasMore()) {
	//        newChild = stream.consumeToken();
	//        parent.addChild(newChild);
	//        switch (newChild.tok) {
	//            case Kwd(KwdPackage), Kwd(KwdImport), Kwd(KwdClass), Kwd(KwdInterface):
	//            walkTokens(stream, newChild);
	//        }
	//    }
	//}

	static function walkTokens(stream:TokenStream, parent:TokenTree, ?stopAt:TokenDef) {
		var newChild:TokenTree = null;
		while (stream.hasMore()) {
			newChild = stream.consumeToken();
			parent.addChild(newChild);
			if ((stopAt != null) && (Type.enumEq(stopAt, newChild.tok))) {
				return;
			}
			
			switch (newChild.tok) {
				case Kwd(KwdPackage), Kwd(KwdImport):
					walkPackageImport(stream, newChild);
				case Kwd(KwdClass), Kwd(KwdInterface):
					walkTokens(stream, newChild);
				case Kwd(KwdFunction):
					walkFunction(stream, newChild);
				case Kwd(KwdReturn):
					walkTokens(stream, newChild, Semicolon);
					if (stopAt == Semicolon) return;
				case Const(CIdent(_)):
					//if (stream.is(POpen)) return walkTokens(stream, newChild, Semicolon);
				case BrOpen:
					return walkTokens(stream, newChild, BrClose);
				case BkOpen:
					return walkTokens(stream, newChild, BkClose);
				case POpen:
					walkTokens(stream, newChild, PClose);
					//return;
				case Kwd(KwdIf):
					walkIf(stream, newChild);
				case Kwd(KwdSwitch):
					walkSwitch(stream, newChild);
				case Kwd(KwdCase), Kwd(KwdDefault):
					walkCase(stream, newChild);
				case Kwd(KwdElse):
					return walkBlock(stream, newChild);
				case Kwd(KwdFor), Kwd(KwdWhile):
					walkFor(stream, newChild);
				case Semicolon:
				case BrClose, BkClose, PClose:
					return;
				default:
			}
			if (!stream.hasMore()) return;
			switch (stream.token()) {
				case BrOpen, BkOpen, POpen:
					return walkTokens(stream, newChild, stopAt);
				default:
			}
		}
		return;
	}

	static function walkPackageImport(stream:TokenStream, parent:TokenTree) {
		var newChild:TokenTree = null;
		newChild = stream.consumeToken();
		parent.addChild(newChild);
		if (Type.enumEq(Semicolon, newChild.tok)) return;
		walkPackageImport(stream, newChild);
	}

	static function walkBlock(stream:TokenStream, parent:TokenTree) {
		if (stream.is(BrOpen)) walkTokens(stream, parent);
		else {
			//trace ("xxx");
			//stream.printRemain();
			walkTokens(stream, parent, Semicolon);
			//trace ("yyy");
			//stream.printRemain();
		}
	}

	static function walkFunction(stream:TokenStream, parent:TokenTree) {

		var newChild:TokenTree = null;
		switch (stream.token()) {
			case Const(CIdent(_)):
				newChild = stream.consumeToken();
				parent.addChild(newChild);
			default:
		}
		walkPOpen(stream, parent);
		var prevChild:TokenTree = parent;
		while (!stream.is(BrOpen)) {
			newChild = stream.consumeToken();
			prevChild.addChild(newChild);
			prevChild = newChild;
		}
		walkTokens(stream, parent);
	}

	static function walkPOpen(stream:TokenStream, parent:TokenTree) {
		var newChild:TokenTree = null;
		if (!stream.is(POpen)) return;
		newChild = stream.consumeToken();
		parent.addChild(newChild);
		walkTokens(stream, newChild, PClose);
		//while (stream.hasMore()) {
		//    newChild = stream.consumeToken();
		//    parent.addChild(newChild);
		//}
	}

	static function walkIf(stream:TokenStream, parent:TokenTree) {
		// condition
		walkPOpen(stream, parent);
		// if-expr
		walkBlock(stream, parent);
		if (stream.is(Kwd(KwdElse))) {
			// else-expr
			walkTokens(stream, parent);
		}
	}

	static function walkSwitch(stream:TokenStream, parent:TokenTree) {
		walkPOpen(stream, parent);
		walkBlock(stream, parent);
	}

	static function walkCase(stream:TokenStream, parent:TokenTree) {
		walkTokens(stream, parent, DblDot);
		walkBlock(stream, parent);
	}

	static function walkFor(stream:TokenStream, parent:TokenTree) {
		walkPOpen(stream, parent);
		walkBlock(stream, parent);
	}

	public static inline var SINGLELINE_IF1:String = "
		package xxxx;
	import blah.fasel;
	@autobuild
	class Test {
		function test(childs:Array<Dynamic>) {
			if (true) { return; } else { return; }
			for (child in childs) { trace(child).lah(); }
			for (i in 0...10) { trace('xxx'); }
			while ((i > 10) && ((j < 100) || (j >1000))) { trace('xxx'); }
		}
	}";

	public static inline var SINGLELINE_IF:String = "
		function test(childs:Array<Dynamic>,text:String,?default:Float=10):Int {
			for (child in childs) { trace(child).lah(); }
			for (i in 0...10) { trace('xxx'); }
			while ((i > 10) && ((j < 100) || (j >1000))) { trace('xxx'); }
			if (true) { return; } else { return; 
				if (text == 'fdklfklgdk') return 1;
				else return 2;
			}
			return text == 'xx' || default > 100 && default <10;
		}
	";

	public static function main() {

		var code = File.getContent('checkstyle/TreeTokenizer.hx');
		//var code = SINGLELINE_IF;
		var tokens:Array<Token> = [];
		var lexer = new HaxeLexer(byte.ByteData.ofString(code), "TokenStream");
		var t:Token = lexer.token(HaxeLexer.tok);

		while (t.tok != Eof) {
			tokens.push(t);
			t = lexer.token(haxeparser.HaxeLexer.tok);
		}

		//var tokens:Array<Token> = [];
		//var pos:Position = {file:"file", min:0, max:1};

		//tokens.push(new Token(Kwd(KwdIf), pos));
		//tokens.push(new Token(POpen, pos));
		//tokens.push(new Token(Kwd(KwdTrue), pos));
		//tokens.push(new Token(PClose, pos));
		//tokens.push(new Token(BrOpen, pos));
		//tokens.push(new Token(Kwd(KwdReturn), pos));
		//tokens.push(new Token(Semicolon, pos));
		//tokens.push(new Token(BrClose, pos));
		//tokens.push(new Token(Kwd(KwdElse), pos));
		//tokens.push(new Token(BrOpen, pos));
		//tokens.push(new Token(Kwd(KwdReturn), pos));
		//tokens.push(new Token(Semicolon, pos));
		//tokens.push(new Token(Kwd(KwdIf), pos));
		//tokens.push(new Token(POpen, pos));
		//tokens.push(new Token(Const(CIdent('text')), pos));
		//tokens.push(new Token(Binop(OpEq), pos));
		//tokens.push(new Token(Const(CString('fdklfklgdk')), pos));
		//tokens.push(new Token(PClose, pos));
		//tokens.push(new Token(Kwd(KwdReturn), pos));
		//tokens.push(new Token(Const(CInt('1')), pos));
		//tokens.push(new Token(Semicolon, pos));
		//tokens.push(new Token(Kwd(KwdElse), pos));
		//tokens.push(new Token(Kwd(KwdReturn), pos));
		//tokens.push(new Token(Const(CInt('2')), pos));
		//tokens.push(new Token(Semicolon, pos));
		//tokens.push(new Token(BrClose, pos));

		var root:TokenTree = TreeTokenizer.makeTokenTree(tokens);
		//trace (root.filter([Kwd(KwdFunction)], All));
		//trace (root.filter([Kwd(KwdIf)], All));
		//trace (root.filter([DblDot], All));
	}
}