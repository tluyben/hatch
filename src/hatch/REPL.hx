package hatch;

#if neko
import haxe.Http;
import haxe.ds.StringMap;
#end

import hatch.Reader;
import hatch.Evaluator;
import hatch.HatchValue.HatchValue;

using hatch.HatchValueUtil;

class REPL {

  public static var VERSION = '0.0.4';
  
  public static var HEADER : String = "
 _           _       _        __     __  
| |__   __ _| |_ ___| |__    / /     \\ \\ 
| '_ \\ / _` | __/ __| '_ \\  / /       \\ \\
| | | | (_| | || (__| | | | \\ \\   _   / /
|_| |_|\\__,_|\\__\\___|_| |_|  \\_\\ (_) /_/ 
";


  public static var hist : Array<String>;
  private static var histIndex : Int;
  private static var inProgress : String;
  
  public static function main () {
    init();
    start();
  }

  public static function init () {    
    hist = [];
    histIndex = 0;
    inProgress = '';
    Reader.init();
    HaxeEnv.init();
    Evaluator.init();
    loadPrelude();
  }

  private static function loadPrelude () {
    for (def in Prelude.coreFunctions)
      {
        switch (Reader.read( def.form))
          {
          case Left(e): throw 'Read error loading prelude in form named ${def.name}';
          case Right(v): Evaluator.prelude.bind( def.name, Evaluator.eval( Evaluator.prelude, v));
          }
      }
  }
  
  public static function getHist () {
    return if (hist.length > 0 && histIndex != -1) hist[histIndex] else inProgress;
  }

  public static function addHist ( s : String ) {
    hist.unshift( s );
    histIndex = -1;
    inProgress = '';
  }

  public static function upOne () {
    if (histIndex < hist.length - 1) histIndex += 1;
    return getHist();
  }

  public static function downOne () {
    if (histIndex >= 0) histIndex -= 1;
    return getHist();
  }

  public static function setInProgress (s : String) {
    if (histIndex == -1) inProgress = s;
  }
  
  // public static function expose (s : String, d : Dynamic) {
  //   Evaluator.setCore( s, d);
  // }
  
  public static function repl( s : String) : (String) {
    switch (Reader.read( s )) {
    case Left(e): return 'READ ERROR $e';
    case Right(ListV([SymbolV('quit')])): {
      running = false;
      return '\nGOOD BYE!\n';
    }
    case Right(v): try {
        return Evaluator.eval( Evaluator.prelude, v ).show();
      } catch (e:Dynamic) {
        return 'EVAL ERROR for ${v.show()},  $e';
      }
    }
  }

  private static var running : Bool = true;
  // the repl does nothing on non-sys plaforms
  private static function start () {
#if sys
    Sys.stdout().writeString('$HEADER\nVersion $VERSION\n');
    while (running) {
      Sys.stdout().writeString("\n> ");
      Sys.stdout().flush();
      var input = Sys.stdin().readLine();
      Sys.stdout().writeString( repl( input ));
      Sys.stdout().flush();
    }
#end
  };
//       switch (Reader.read(input)) {
//       case Left(e): {
//         Sys.stdout().writeString('\n $e');
//         Sys.stdout().flush();
//       }
//       case Right(v): try {
// 	  Sys.stdout().writeString('\n ${Printer.show(Evaluator.eval(v))}');
//           Sys.stdout().flush();
// 	} catch (e:Dynamic) {
// 	  Sys.stdout().writeString('\n ${e}');
//           Sys.stdout().flush();
// 	}
//       }
//     }
// #end
//   }

}