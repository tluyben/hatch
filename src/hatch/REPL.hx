package hatch;

import haxe.ds.StringMap;
import haxe.ds.IntMap;
import haxe.Http;
import hatch.Reader;
import hatch.Evaluator;
import hatch.Printer;

class REPL {

  private static var VERSION = '0.0.3';
  
  private static var HEADER : String = "
 _           _       _        __     __  
| |__   __ _| |_ ___| |__    / /     \\ \\ 
| '_ \\ / _` | __/ __| '_ \\  / /       \\ \\
| | | | (_| | || (__| | | | \\ \\   _   / /
|_| |_|\\__,_|\\__\\___|_| |_|  \\_\\ (_) /_/ 
";

  public static function main () {
    Reader.init();
    Evaluator.init();
    start();
  };

  // the repl does nothing on non-sys plaforms
  private static function start () {
#if sys
    Sys.stdout().writeString('$HEADER\nVersion $VERSION\n');
    while (true) {
      Sys.stdout().writeString("\n> ");
      Sys.stdout().flush();
      var input = Sys.stdin().readLine();
      switch (Reader.read(input)) {
      case Left(e): {
        Sys.stdout().writeString('\n $e');
        Sys.stdout().flush();
      }
      case Right(v): try {
	  Sys.stdout().writeString('\n ${Printer.show(Evaluator.eval(v))}');
          Sys.stdout().flush();
	} catch (e:Dynamic) {
	  Sys.stdout().writeString('\n ${e}');
          Sys.stdout().flush();
	}
      }
    }
#end
  }

}