

import farcek.Parser;
import farcek.Parser as P;

enum Term {
  IntT(i:Int);
  FloatT(i:Float);
  StringT(i:String);
  VarT(i:String);
  BlankT;
  SymbolT(a:String);
  ConsT(h:Term,t:Term);
  NilT;
}


class Parse {

  // TERM  PARSERS //
  public static var intP : Parser<Term>;
  public static var floatP : Parser<Term>;
  public static var stringP : Parser<Term>;
  public static var varP : Parser<Term>;
  public static var blankP : Parser<Term>;
  public static var operatorP : Parser<Term>;
  public static var symbolP : Parser<Term>;
  public static var nilP : Parser<Term>;
  public static var consP : Parser<Term>;

  public static var termP : Parser<Term>;

  public static function init() {
    // HELPER DEFINITIONS
    var specialCharsP = P.oneOf("!#$%&|*+-/:<=>?@^_~'");
    var whitespaceP = P.oneOf(" \n\t\r").many();
    // var eofP = new Parser(function (s) {
    //  	return if (s.length == 0) [{parsed: true, leftOver: ''}] else [];
    //   });
    var notQuoteP = P.sat(function (s) {return s.charAt(0) != '"';});
    var openP = P.spaceBracket(P.char('('));
    var closeP = P.spaceBracket(P.char(')'));

    // TERM DEFINITIONS 
    intP = P.digit().many1().fmap(function(a) {
	return IntT(Std.parseInt(a.join('')));
      });

    floatP = P.digit().many1().bind(function (wholes) {
	return P.char('.').then(P.digit().many()).fmap(function (decimal) {
	    return FloatT(Std.parseFloat(wholes.join('') + '.' + decimal.join('')));
	  });
      });

    stringP = P.char('"').then(notQuoteP.many()).bind(function (contents) {
	return P.char('"').fmap(function (ignore) {
	    return StringT(contents.join(''));
	  });
      });

    varP = P.upper().bind(function (first) {
	return (P.alphanum().or(specialCharsP)).many().fmap(function (rest) {
	    return VarT(first + rest.join(''));
	  });
      });

    blankP = P.char('_').thento(BlankT);

    operatorP = P.oneOf("*&^%$#@!<>+-/?.:~").many1().fmap(function (a) {
	return SymbolT( a.join(''));
      });

    symbolP = P.lower().bind(function (first) {
	return (P.lower().or(specialCharsP)).many().fmap(function (rest) {
	    return SymbolT( first + rest.join('') );
	  });
      });

    nilP = P.string('nil').or(openP.then(whitespaceP).then(closeP)).thento(NilT);
    
    var consing = function (exps : Array<Term>) {
      var e = NilT;
      while (exps.length > 0) e = ConsT(exps.pop(), e);
      return e;
    };

    var atomicP = P.choice([
			    floatP,
			    intP,
			    stringP,
			    varP,
			    blankP,
			    operatorP,
			    nilP,
			    symbolP,
			    ]);
    
    consP = P.nested( openP, closeP, P.spaceBracket(atomicP), consing);

    termP = atomicP.or(consP);
    
  }

  public static function main () {
    init();
    var test = function (s) {
      switch (P.run(termP, s)) {
      case None: trace('$s : NO PARSE\n');
      case Some(p): trace('$s : $p\n');
      }
    };

    test('1');
    test('001.3400');
    test('"hello there"');
    test('X_is_VAR');
    test('_');
    test('*');
    test('hello#');
    test('nil');
    test('(  )');
    test('(1 2.33 3)');
    test('(())');
    test('(/ 1 (+ 2 3.444 "hello" nil))');
    test('(/ 1 (+ 2 3.444 nil))');
  }

}