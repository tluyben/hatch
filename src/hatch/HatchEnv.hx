package hatch;

import hatch.HatchValue.HatchValue;

class HatchEnv {

  private var table : Map<String,HatchValue>;
  private var parent : HatchEnv;

  public function new ()
  {
    table = new Map();
    parent = null;
  }
  
  public function lookup ( s : String) : (HatchValue)
  {
    var v = table.get( s );
    if (v == null)
      {
        if (parent == null)
          {
            throw 'Error: $s unbound in this context';
          }
        else
          {
            return parent.lookup( s );
          }
      }
    return v;
  }

  public function bind ( s : String, v : HatchValue)
  {
    table.set( s, v );
  }

  public function extend ( vars : Array<String>, vals : Array<HatchValue> ) : (HatchEnv)
  {
    var env = new HatchEnv();
    for (i in 0...vars.length)
      {
        env.bind( vars[i], vals[i] ); 
      }
    env.parent = this;
    return env;    
  }
  
}