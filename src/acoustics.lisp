(in-package #:sephirion)

;; q = volume displacement, u = volume velocity. Coefficients are
;; acoustic inertance M, resistance R, inverse compliance K, and Kc.
(defstruct (acoustic-pair (:constructor %make-acoustic-pair))
  m1 m2 r1 r2 k1 k2 coupling)

(defun make-acoustic-pair (&key (m1 1d0) (m2 1d0) (r1 0.2d0) (r2 0.2d0)
                               (k1 1d0) (k2 1d0) (coupling 0.5d0))
  "Create a passive pair. Inertance and inverse compliance must be positive."
  (loop for value in (list m1 m2 k1 k2)
        do (assert (and (realp value) (< 0 value))))
  (loop for value in (list r1 r2 coupling)
        do (assert (and (realp value) (<= 0 value))))
  (%make-acoustic-pair :m1 (float m1 1d0) :m2 (float m2 1d0)
                      :r1 (float r1 1d0) :r2 (float r2 1d0)
                      :k1 (float k1 1d0) :k2 (float k2 1d0)
                      :coupling (float coupling 1d0)))

(defun pair-derivative (pair state time omega pressure)
  "Derivative of #(q1 u1 q2 u2); sinusoidal pressure drives resonator 1."
  (destructuring-bind (q1 u1 q2 u2) (coerce state 'list)
    (let ((kc (acoustic-pair-coupling pair)))
      (vector u1
              (/ (- (* pressure (cos (* omega time)))
                    (* (acoustic-pair-r1 pair) u1)
                    (* (acoustic-pair-k1 pair) q1) (* kc (- q1 q2)))
                 (acoustic-pair-m1 pair))
              u2
              (/ (- (* kc (- q1 q2)) (* (acoustic-pair-r2 pair) u2)
                    (* (acoustic-pair-k2 pair) q2))
                 (acoustic-pair-m2 pair))))))

(defun shifted-state (state derivative scale)
  (map 'vector (lambda (x dx) (+ x (* scale dx))) state derivative))

(defun rk4-step (pair state time dt omega pressure)
  "Advance all four state variables together using classical RK4."
  (assert (> dt 0))
  (let* ((half (/ dt 2d0))
         (a (pair-derivative pair state time omega pressure))
         (b (pair-derivative pair (shifted-state state a half)
                             (+ time half) omega pressure))
         (c (pair-derivative pair (shifted-state state b half)
                             (+ time half) omega pressure))
         (d (pair-derivative pair (shifted-state state c dt)
                             (+ time dt) omega pressure)))
    (map 'vector (lambda (x da db dc dd)
                   (+ x (* (/ dt 6d0) (+ da (* 2d0 db) (* 2d0 dc) dd))))
         state a b c d)))

(defun stored-energy (pair state)
  (destructuring-bind (q1 u1 q2 u2) (coerce state 'list)
    (* 0.5d0 (+ (* (acoustic-pair-m1 pair) u1 u1)
                 (* (acoustic-pair-m2 pair) u2 u2)
                 (* (acoustic-pair-k1 pair) q1 q1)
                 (* (acoustic-pair-k2 pair) q2 q2)
                 (* (acoustic-pair-coupling pair) (expt (- q1 q2) 2))))))

(defun power-balance (pair state time omega pressure)
  "Return input power, dissipated power, and their difference dE/dt."
  (let* ((u1 (aref state 1)) (u2 (aref state 3))
         (input (* pressure (cos (* omega time)) u1))
         (loss (+ (* (acoustic-pair-r1 pair) u1 u1)
                  (* (acoustic-pair-r2 pair) u2 u2))))
    (values input loss (- input loss))))

(defun analytical-response (pair omega &optional (pressure 1d0))
  "Complex q1 and q2 amplitudes with convention q(t)=Re(Q exp(i omega t))."
  (let* ((kc (acoustic-pair-coupling pair))
         (z1 (complex (- (+ (acoustic-pair-k1 pair) kc)
                          (* (acoustic-pair-m1 pair) omega omega))
                      (* (acoustic-pair-r1 pair) omega)))
         (z2 (complex (- (+ (acoustic-pair-k2 pair) kc)
                          (* (acoustic-pair-m2 pair) omega omega))
                      (* (acoustic-pair-r2 pair) omega)))
         (determinant (- (* z1 z2) (* kc kc))))
    (when (zerop determinant) (error "Singular response: no unique steady state."))
    (values (/ (* pressure z2) determinant)
            (/ (* pressure kc) determinant))))

(defun csv-number (value stream)
  ;; Common Lisp double exponents use D; CSV consumers expect E.
  (write-string (substitute #\e #\d (string-downcase (format nil "~,12E" value)))
                stream))

(defun csv-row (stream values)
  (loop for value in values for first = t then nil
        do (unless first (write-char #\, stream)) (csv-number value stream))
  (terpri stream))

(defun measure-response (pair omega &key (pressure 1d0) (settle-time 200d0)
                                    (cycles 8) (max-dt 0.02d0) trace-stream)
  "Start from rest, discard settling, then project whole cycles onto sin/cos.
Return measured complex amplitudes and the actual timestep. Each call is independent.
Settling sufficiency and RK4 stability must be checked for new parameter sets."
  (assert (and (> omega 0) (> max-dt 0) (>= settle-time 0)
               (integerp cycles) (> cycles 0)))
  (let* ((period (/ (* 2d0 pi) omega))
         (steps-per-cycle (max 32 (ceiling period max-dt)))
         (dt (/ period steps-per-cycle))
         (settle-steps (ceiling settle-time dt))
         (samples (* cycles steps-per-cycle))
         (state (vector 0d0 0d0 0d0 0d0))
         (sum1 #c(0d0 0d0)) (sum2 #c(0d0 0d0)))
    (labels ((record-state (tick)
               (when trace-stream
                 (let ((time (* tick dt)))
                   (multiple-value-bind (input loss net)
                       (power-balance pair state time omega pressure)
                     (csv-row trace-stream
                              (append (list time) (coerce state 'list)
                                      (list (stored-energy pair state) input loss net))))))))
      (when trace-stream
        (write-line "time,q1,u1,q2,u2,energy,input_power,dissipated_power,net_power"
                    trace-stream))
      (record-state 0)
      (loop for tick from 0 below (+ settle-steps samples)
            do (setf state (rk4-step pair state (* tick dt) dt omega pressure))
               (record-state (1+ tick))
               (when (>= tick settle-steps)
                 (let ((basis (cis (- (* omega (1+ tick) dt)))))
                   (incf sum1 (* (aref state 0) basis))
                   (incf sum2 (* (aref state 2) basis))))))
    (values (* (/ 2d0 samples) sum1) (* (/ 2d0 samples) sum2) dt)))

(defun run-experiment (directory)
  "Write a reproducible reference sweep and every-tick trace to DIRECTORY."
  (let* ((directory (uiop:ensure-directory-pathname directory))
         (pair (make-acoustic-pair))
         (maximum-error 0d0))
    (ensure-directories-exist (merge-pathnames "sweep.csv" directory))
    (with-open-file (out (merge-pathnames "sweep.csv" directory)
                         :direction :output :if-exists :supersede)
      (write-line "omega,amplitude1,phase1,amplitude2,phase2,analytical_amplitude1,analytical_phase1,analytical_amplitude2,analytical_phase2,complex_error1,complex_error2,dt" out)
      (loop for index from 0 to 60 for omega = (+ 0.5d0 (* index 0.025d0))
            do (multiple-value-bind (q1 q2 dt) (measure-response pair omega)
                 (multiple-value-bind (a1 a2) (analytical-response pair omega)
                   (let ((e1 (abs (- q1 a1))) (e2 (abs (- q2 a2))))
                     (setf maximum-error (max maximum-error e1 e2))
                     (csv-row out (list omega (abs q1) (phase q1) (abs q2) (phase q2)
                                        (abs a1) (phase a1) (abs a2) (phase a2)
                                        e1 e2 dt)))))))
    (with-open-file (out (merge-pathnames "trace.csv" directory)
                         :direction :output :if-exists :supersede)
      (measure-response pair 1d0 :trace-stream out))
    (format t "61 frequencies; maximum absolute complex response error: ~,6E~%"
            maximum-error)
    maximum-error))
