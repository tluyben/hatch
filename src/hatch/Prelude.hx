package hatch;

class Prelude {
private static var prelude = '

(define list
  (lambda (rest&) rest&)
  "(list a b ...) => (a b ...)")

(define map
  (lambda (f l)
    (if (empty? l) l
	(cons (f (head l))
	      (map f (tail l)))))
  "(map f (a b ...)) => ((f a) (f b) ...)")

(define fold
  (lambda (f acc l)
    (if (empty? l) acc
	(fold f (f (head l) acc) (tail l)))) 
  "(fold f acc (a b ... n)) => (f a (f b (f .... (f n acc))))"  )

(define filter
  (lambda (p l) 
    (reverse (fold (-> (v acc) (if (p v) (cons v acc) acc)) 
		   () 
		   l)))
  "(filter p l) returns sublist of x in l for which (p x) is true")

(define <>
  (lambda (f g) (lambda (x) (f (g x))))
  "(<> f g) applied to x is (f (g x))")

(define reverse
  (lambda ( l ) (fold cons () l))
  "(reverse (list 1 2 3)) returns (3 2 1)")

(define length (lambda ( l )
		 (fold (lambda (ignore acc) (+ 1 acc)) 0 l)))

(define <$
  (-> (x) (-> (f) (f x)))
  "((<$ 10) ($ + 1)) returns 11. I.e. (<$ x) returns a function that 
that accepts a function as an argument. The argument is supplied x as
its argument.")


(define begin (macro (rest&) 
  (let ((forms (map (-> (x) (list or x #t)) rest&))) (eval (cons and forms)))))

(define >>= (-> (a rest&) (fold (-> (f acc) (f acc)) a rest&))
  "(>>= x f1 f2 ... fn) returns (fn (... (f2 (f1 x))))")

(define zip
  (-> (ls)
      (if (some? empty? ls) ()
	  (cons (map head ls)
		(zip (map tail ls)))))
  "(zip ((a1 a2 ...) (b1 b2 ...) (c1 c2 ...))) returns (((a1 b1 c1 ...) (a2 b2 c2 ...) ...))") 


(define some? (-> (p l) 
  (if (empty? l) #f
      (or (p (head l) (some? p (tail l))))))
  "(some? p l) returns the first non-falsey value in l, otherwise returns #f")

(define all? (-> (p l) 
  (if (empty? l) #t 
      (and (p (head l) (and? p (tail l))))))
  "(all? p l) returns #f if any of the values in l are falsy, 
otherwise returns the last value in l")


(define cond (macro (rest&) (eval (cons or (map ($ cons and) rest&))))
  "
 (cond (p1 e1)
       (p2 e2)
       (p3 e3)
       ...)
 returns e1 if p1 is true, else e2 if p2, else ... #f
")

(define < (-> (a b) (= -1 (. Reflect.compare a b)))
  "(< a b) returns true of a < b else false")

(define > (-> (a b) (not (or (= a b) (< a b))))
  "(> a b) returns true a > b, else false" )

(define rep (-> (n f x) (if (> n 1) (f (rep (- n 1) f x)) (f x)))
  "(rep n f x) nests calls to f starting with x n times.  
E.g. (rep 2 tail (list 1 2 3 4 5)) returns (3 4 5)" )

;; (define last (<> head reverse)) ;; this should be fine but is not for some reason 

(define last (-> (l) (head (reverse l))))

(define butlast (-> (l) (reverse (tail (reverse l)))) "returns all but the last element of a list")

(define monadic-method
  (macro (symbol)
    (-> (rest&)
	(and (eval (+ (list (quote .) symbol) (cons (last rest&) (butlast rest&))))
	     (last rest&))))
  "(monadic-method symbol) returns a function that evokes a method on
a haxe object, the object being the very last argument. The method
will always return the same object argument.  For use with >>=")

(define method
  (macro (symbol)
    (-> (rest&)
	(eval (+ (list (quote .) symbol) rest&))))
  "wraps a haxe method call as a function")


';


  public static function getPrelude () {return prelude;}
  
}








