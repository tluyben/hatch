
//import Parse.Term;
import Reader;
import farcek.Parser as P;

using Lambda;


class Printer {

  public static function show(t : Term) {
    return switch (t) {
    case IntT(i) : '$i';
    case FloatT(f) : '$f';
    case StringT(s) : '"$s"';
    case VarT(v) : '$v';
    case BlankT : '_';
    case SymbolT(s) : '$s';
    case NilT : 'nil';
    case ListT(a) : '(' + a.map(show).join(' ') + ')';
    };
  }

  public static function main () {
    Reader.init();
    var test = function (s) {
      trace(s);
      switch (Reader.read( s )) {
      case Left(e): P.traceError(e);
      case Right(p): trace('${show(p)}\n\n');
      }

      // var parsed = Reader.read( s );
      // trace(parsed);
      // switch (parsed) {
      // case None: trace('...\n\n');
      // case Some( p ): trace(show(p) + '\n\n');
      // };
    }

    test('(+ 1 2 3)');
    test('()');
    test('(/ 1 (* 2 3))');
    test('(=> (foo X Y) (+ X X Y Y))');
    test('(=>? (foo X Y) (zoo X) (+ X X Y Y))');
    test('(\'(1 2 3 4))');
  }
  
}