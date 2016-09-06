

import farcek.Parser;
import farcek.Parser as P;


enum HatchValue {
  IntV(i:Int);
  FloatV(f:Float);
  StringV(s:String);
  FunctionV(f: HatchValue -> HatchValue);
  ListV(a:Array<HatchValue>);
  SymbolV(a:String);
  NilV;
}

class Reader {

  // TERM  PARSERS //
  public static var intP : Parser<HatchValue>;
  public static var floatP : Parser<HatchValue>;
  public static var stringP : Parser<HatchValue>;
  //  public static var varP : Parser<HatchValue>;
  //  public static var blankP : Parser<HatchValue>;
  public static var operatorP : Parser<HatchValue>;
  public static var symbolP : Parser<HatchValue>;
  public static var nilP : Parser<HatchValue>;
  public static var listP : Parser<HatchValue>;  

  public static var termP : Parser<HatchValue>;

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
	  return IntV(Std.parseInt(a.join('')));
	});
      
      floatP = P.digit().many1().bind(function (wholes) {
	  return P.char('.').then(P.digit().many()).fmap(function (decimal) {
	      return FloatV(Std.parseFloat(wholes.join('') + '.' + decimal.join('')));
	    });
	});
      
      stringP = P.char('"').then(notQuoteP.many()).bind(function (contents) {
	  return P.char('"').fmap(function (ignore) {
	      return StringV(contents.join(''));
	    });
	});
      
      // varP = P.upper().bind(function (first) {
      // 	  return (P.alphanum().or(specialCharsP)).many().fmap(function (rest) {
      // 	      return VarT(first + rest.join(''));
      // 	    });
      // 	});
      
      //      blankP = P.char('_').thento(BlankT);
      
      operatorP = P.oneOf("*&^%$#@!<>+-/?.:~=").many1().fmap(function (a) {
	  return SymbolV( a.join(''));
	});
      
      symbolP = P.lower().bind(function (first) {
	  return (P.lower().or(specialCharsP)).many().fmap(function (rest) {
	      return SymbolV( first + rest.join('') );
	    });
	});
      
      nilP = P.string('nil').or(openP.then(whitespaceP).then(closeP)).thento(NilV);
      
      var consing = function (exps : Array<HatchValue>) {
	return ListV(exps);
      };
      
      var atomicP = P.choice([
			      floatP,
			      intP,
			      stringP,
			      //			      varP,
			      //			      blankP,
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