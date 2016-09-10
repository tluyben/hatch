
enum HatchValue {
  IntV(i:Int);
  FloatV(f:Float);
  StringV(s:String);
  FunctionV(f: HatchValue -> BindingStack -> HatchValue);
  ListV(a:Array<HatchValue>);
  SymbolV(a:String);
  BoolV(b:Bool);
  HaxeV(d:Dynamic);
    //  NilV;
}
