package hatch;

import hatch.HatchValue.HatchValue;

class HatchEnv {

  private var table : Map<String,HatchValue>;
  private var parents : Array<HatchEnv>;

  public function new ()
  {
    table = new Map();
    parents = [];
  }

  public function defined (s : String) : (Bool)
  {
    return table.exists( s );
  }
  
  public function lookup ( s : String) : (HatchValue)
  {
    var v = table.get( s );
    if (v == null)
      {
	for (p in parents)
	  {
	    v = p.lookup( s );
	    if (v != null)
	      {
		return v;
	      }
	  }
	if (v == null)
	  {
	    throw 'Unbound symbol $s';
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
    env.parents = [this];
    return env;    
  }

  public function join (env : HatchEnv) : (HatchEnv)
  {
    var newEnv = new HatchEnv();
    newEnv.parents = env.parents.concat(this.parents);
    return newEnv;
  }
  
}