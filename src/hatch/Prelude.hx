package hatch;

class Prelude {

  public static var coreFunctions =
    [
     {name: 'list', form: '(-> (rest&) rest&)'},
     {name: 'foldl', form: '(-> (f acc l) (if (empty? l) acc (foldl f (f acc (head l)) (tail l))))'},
     {name: 'foldr', form: '(-> (f acc l) (if (empty? l) acc (foldr f (f (head l) acc) (tail l))))'},
     {name: 'map', form: '(-> (f l) (if (empty? l) () (cons (f (head l)) (map f (tail l)))))'},
     {name: '<>', form: '(-> (f g) (-> (x) (f (g x))))'},
     {name: '>>', form: '(-> (a rest&) (foldr (-> (f acc) (f acc)) a rest&))'}
       
       ];

}