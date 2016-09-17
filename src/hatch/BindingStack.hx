package hatch;

import haxe.ds.Option;
import hatch.HatchValue.HatchValue;

typedef Bindings = Map<String,HatchValue>;

class BindingStack {

  var stack : Array<Bindings>;

  public function new (bs : Array<Bindings>) {
    stack = bs;
  }

  public function lookup ( s : String ) : Option<HatchValue> {
    for (bs in stack) if (bs.exists( s )) return Some( bs.get( s ));
    return None;
  }

  public function bindSymbol (s : String, v : HatchValue) {
    if (!stack[0].exists(s) || isMutable(s)) {
      stack[0].set(s, v);
      return v;
    } else throw 'cannot rebind symbol $s';
  }
  
  public function newScope (b : Bindings) {
    var copy = stack.copy();
    copy.unshift( b );
    return new BindingStack( copy );
  }

  public function prependTo (bs : BindingStack) {
    return new BindingStack(stack.concat(bs.stack));
  }

  private static function isMutable (s : String) : (Bool) {
    return s.length > 1 && s.charAt(s.length - 1) == '.';
  }

}