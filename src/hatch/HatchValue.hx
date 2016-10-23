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
  PrimOpV( op : Array<HatchValue> -> HatchValue);
  HaxeV( v : Dynamic);
  HaxeOpV( op : Void -> HatchValue); 
}

