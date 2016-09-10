
//import Parse.Term;
import Reader;
import farcek.Parser as P;

using Lambda;


class Printer {

  public static function show(t : HatchValue) {
    return switch (t) {
    case   IntV(i): '$i';
    case   FloatV(f): '$f';
    case   StringV(s): '"$s"';
    case   FunctionV(f): '#<function>';
    case   ListV(a): '(' + a.map(show).join(' ') + ')';
    case   SymbolV(a): a;
    case   BoolV(b): if (b) '#t' else '#f';
    case HaxeV(d): '$d';
    };
  }
  
}