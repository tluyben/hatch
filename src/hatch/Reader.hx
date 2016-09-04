

import farcek.Parser;
import farcek.Parser as P;

enum Term {
  IntT(i:Int);
  FloatT(i:Float);
  StringT(i:String);
  VarT(i:String);
  BlankT;
  SymbolT(a:String);
  ListT(a:Array<Term>);
  NilT;
}


class Reader {

  // TERM  PARSERS //
  public static var intP : Parser<Term>;
  public static var floatP : Parser<Term>;
  public static var stringP : Parser<Term>;
  public static var varP : Parser<Term>;
  public static var blankP : Parser<Term>;
  public static var operatorP : Parser<Term>;
  public static var symbolP : Parser<Term>;
  public static var nilP : Parser<Term>;
  public static var listP : Parser<Term>;  

  public static var termP : Parser<Term>;

  public static function init() {
    if (termP == null) {
      // HELPER DEFINITIONS
      var specialCharsP = P.oneOf("!#$%&|*+-/:<=>?@^_~'");
      var whitespaceP = P.oneOf(" \n\t\r").many().fmap(function (a) {return a.join('');});
      var notQuoteP = P.sat(function (s) {return s.charAt(0) != '"';});
      var openP = P.bracket(whitespaceP, P.char('('), whitespaceP);
      var closeP = P.bracket(whitespaceP, P.char(')'), whitespaceP);
      
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
      
      operatorP = P.oneOf("*'&^%$#@!<>+-/?.:~=").many1().fmap(function (a) {
	  return SymbolT( a.join(''));
	});
      
      symbolP = P.lower().bind(function (first) {
	  return (P.lower().or(specialCharsP)).many().fmap(function (rest) {
	      return SymbolT( first + rest.join('') );
	    });
	});
      
      nilP = P.string('nil').or(openP.then(whitespaceP).then(closeP)).thento(NilT);
      
      var consing = function (exps : Array<Term>) {
	return ListT(exps);
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
      
      listP = P.nested( openP, closeP, P.spaceBracket(atomicP), consing);
      termP = atomicP.or(listP);
    }
  }

  public static function read (s : String) {
    return P.runE( termP, s);
  }
  
}