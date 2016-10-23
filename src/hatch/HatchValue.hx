package hatch;

enum HatchValue {
  SymbolV(a : String);
  ListV(l : Array<HatchValue>);
  IntV(i : Int);
  FloatV(f : Float);
  StringV(s : String);
  BoolV(b : Bool);
  FunctionV( parameters : Array<String>,
             body : HatchValue,
             env : HatchEnv);
  MacroV( parameters : Array<String>,
	  body : HatchValue,
	  defEnv : HatchEnv,
	  callEnv : HatchEnv);
  PrimOpV( op : Array<HatchValue> -> HatchValue);
  HaxeV( v : Dynamic);
  HaxeOpV( op : Void -> HatchValue); 
}

