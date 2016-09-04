
import Reader;

typedef Bindings = Map<String,Dynamic>;

class Evaluator {


  private static var bindingStack : Array<Bindings>;
  
  public static function main () {
    trace( eval( IntT(10) ) );
  }
  
  public static function init () {
    if (bindingStack = null) bindingStack = [];
  }
  
  private static function evalList( a : Array<Term>) {
    if (a.length == 0) return eval(NilT);
    var head = a[0];

  }
  
  public static function eval (exp : Term) : Dynamic {
    return switch (exp) {
    case IntT(i): i;
    case FloatT(f): f;
    case StringT(s): s;
    case NilT: null;
    case VarT(v): null;
    case BlankT: null;
    case SymbolT(a): a;
    case ListT(a): evalList( a );
    };
  }

					     
					     
  
}