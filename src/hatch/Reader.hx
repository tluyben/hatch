package hatch;

import farcek.Parser;
import farcek.Parser as P;
import hatch.HatchValue.HatchValue;


class Reader {

  // TERM  PARSERS //
  public static var intP : Parser<HatchValue>;
  public static var floatP : Parser<HatchValue>;
  public static var stringP : Parser<HatchValue>;
  public static var boolP : Parser<HatchValue>;

  public static var operatorP : Parser<HatchValue>;
  public static var symbolP : Parser<HatchValue>;

  public static var listP : Parser<HatchValue>;  

  public static var termP : Parser<HatchValue>;

  //  public static var exprsP : Parser<Array<HatchValue>>;

  public static function init() {

    if (termP == null) {
      // HELPER DEFINITIONS
      var specialCharsP = P.oneOf("~@$:[]%^&*+=-_?><./\\");
      var whitespaceP = P.oneOf(" \n\t\r").many().thento('');
      var notQuoteP = P.sat(function (s) {return s.charAt(0) != '"';});
      var openP = P.bracket(whitespaceP, P.char('('), whitespaceP);
      var closeP = P.bracket(whitespaceP, P.char(')'), whitespaceP);
      
      // TERM DEFINITIONS 
      intP = P.char('-').ornot().bind(function (neg) {
          return P.digit().many1().fmap(function(a) {
              var i = switch (neg) {
              case None: Std.parseInt(a.join(''));
              case Some(_): Std.parseInt('-' + a.join(''));
              };
              return IntV(i);
            });
        });
      
      floatP = P.char('-').ornot().bind(function (neg) {
          return P.digit().many1().bind(function (wholes) {
              return P.char('.').then(P.digit().many()).fmap(function (decimal) {
                  var f = switch (neg) {
                  case None: Std.parseFloat(wholes.join('') + '.' + decimal.join(''));
                  case Some(_):  Std.parseFloat('-' + wholes.join('') + '.' + decimal.join(''));
                  };
                  return FloatV(f);
                });
            });
        });
      
      stringP = P.char('"').then(notQuoteP.many()).bind(function (contents) {
	  return P.char('"').fmap(function (ignore) {
	      return StringV(contents.join(''));
	    });
	});
      
      operatorP = specialCharsP.many1().fmap(function (a) {
	  return SymbolV( a.join(''));
	});
      
      symbolP = P.letter().bind(function (first) {
      	  return (P.letter().or(specialCharsP)).or(P.digit()).many().fmap(function (rest) {
      	      return SymbolV( first + rest.join('') );
      	    });
      	});

      boolP = P.stringTo('#f', BoolV(false)).or(P.stringTo('#t', BoolV(true)));
      
      var consing = function (exps : Array<HatchValue>) {
	return ListV(exps);
      };
      
      var atomicP = P.choice([
			      floatP,
			      intP,
			      stringP,
			      operatorP,
			      boolP,
			      symbolP,
			      ]);

      var quoted = function (p : Parser<HatchValue>) {
	return P.string("'").then(p).fmap(function (parsed) {
	    return ListV([SymbolV('quote'), parsed]);
	  });
      };      

      listP = P.nested( openP, closeP,
			P.bracket(whitespaceP,
				  quoted(atomicP).or(atomicP)
				  , whitespaceP),
			consing);
      
      var listP2 = P.nested( openP, closeP,
			     P.bracket(whitespaceP,
				       quoted(listP).or(listP).or(quoted(atomicP)).or(atomicP),
				       whitespaceP),
			     consing);
      
      var rawTermP = P.bracket( whitespaceP, atomicP.or(listP2).or(listP), whitespaceP );

      termP = quoted(rawTermP).or(rawTermP);
    }
  }

  public static function read (s : String) {
    return P.runE( termP, s);
  }

  // public static function readMany (s : String) : haxe.ds.Either<Dynamic,Array<HatchValue>> {
  //   return P.runE( exprsP, s);
  // }


  public static function main () {
    init();
    var assert = function (s : String, v : HatchValue ) {
      switch ( read(s) ) {
      case Right(v0) if (HatchValueUtil.equal(v0,v)): trace('[PASS] $s : $v');
      case Right(v0): trace('[FAIL] $s : $v0');
      case Left(e): P.traceError(e);
      }
    };

    assert('5', IntV(5));
    assert('3.44',FloatV(3.44));
    assert('0.32',FloatV(0.32));
    assert('-1', IntV(-1));
    assert('-0.332',FloatV(-0.332));
    assert('"a string"',StringV('a string'));
    assert('#f',BoolV(false));
    assert('#t',BoolV(true));
    assert('    5    ',IntV(5));
    assert('   #f   ',BoolV(false));
    assert('@@%$', SymbolV('@@%$'));
    assert('  -3445.32   ',FloatV(-3445.32));
    assert('(1 2 3 4)', ListV([IntV(1),IntV(2),IntV(3),IntV(4)]));
    assert('(1 (2 foo)       3 4)    ',
           ListV([IntV(1),ListV([IntV(2), SymbolV('foo')]),IntV(3),IntV(4)]));
    assert('(1
 2
 3)', ListV([IntV(1), IntV(2), IntV(3)]));


    assert('(1)', ListV([IntV(1)]));
    assert('((+ 1) (* 2 3))', ListV([ListV([SymbolV('+'), IntV(1)]),
                                     ListV([SymbolV('*'), IntV(2), IntV(3)])]));
  }
  
}