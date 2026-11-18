(defpackage #:sephirion-experiment-002
  (:use #:cl #:sephirion-acoustic)
  (:export #:pair-network #:chain-network #:chain-response #:distance
           #:run-experiments))
(in-package #:sephirion-experiment-002)

(defun pair-network (dt omega &key (coupling 0.5d0) (enabled t) (r 0.2d0)
                                  (r2 r) (m2 1d0) (k2 1d0) (driven t) (q1 0d0))
  (make-acoustic-network
   (list (make-acoustic-realm "a" :r r :q q1 :amplitude (if driven 1d0 0d0) :omega omega)
         (make-acoustic-realm "b" :m m2 :k k2 :r r2 :omega omega))
   (list (make-coupling "ab" "a" "b" coupling :enabled enabled)) :dt dt))

(defun chain-network (dt omega &key nested (enabled t) (r 0.2d0) (driven t) (q1 0d0))
  (make-acoustic-network
   (list (make-acoustic-realm "a" :r r :q q1 :amplitude (if driven 1d0 0d0) :omega omega)
         (make-acoustic-realm "b" :parent (when nested "a") :r r :omega omega)
         (make-acoustic-realm "c" :parent (when nested "a") :r r :omega omega))
   (list (make-coupling "ab" "a" "b" 0.5d0 :enabled enabled)
         (make-coupling "bc" "b" "c" 0.5d0 :enabled enabled)) :dt dt))

(defun chain-response (omega &optional (r 0.2d0))
  "Independent normal-mode expansion for the uniform reference chain."
  (let ((mode0 (/ 1d0 (complex (- 1d0 (* omega omega)) (* r omega))))
        (mode1 (/ 1d0 (complex (- 1.5d0 (* omega omega)) (* r omega))))
        (mode2 (/ 1d0 (complex (- 2.5d0 (* omega omega)) (* r omega)))))
    (vector (+ (/ mode0 3d0) (/ mode1 2d0) (/ mode2 6d0))
            (- (/ mode0 3d0) (/ mode2 3d0))
            (+ (/ mode0 3d0) (- (/ mode1 2d0)) (/ mode2 6d0)))))

(defun distance (a b)
  (unless (= (length a) (length b)) (error "Cannot compare vectors of different lengths."))
  (reduce #'max (map 'vector (lambda (x y) (abs (- x y))) a b) :initial-value 0d0))
