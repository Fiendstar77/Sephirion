(defpackage #:sephirion-acoustic
  (:use #:cl)
  (:export #:make-acoustic-realm #:make-coupling #:make-acoustic-network
           #:acoustic-state #:acoustic-snapshot #:acoustic-energy
           #:step-acoustic #:run-acoustic #:write-trace-header #:write-trace-row
           #:measure-acoustic-response))
(in-package #:sephirion-acoustic)

(defun invalid (control &rest arguments)
  (error 'sephirion:model-error :message (apply #'format nil control arguments)))

(defun number-value (value &key positive nonnegative)
  "Finite, bounded double conversion; numerical failure is explicit."
  (handler-case
      (progn
        (unless (and (realp value) (<= (- 1d100) value 1d100))
          (invalid "Expected a finite real with magnitude <=1e100."))
        (let ((double (coerce value 'double-float)))
          (when (or (and positive (< double 1d-100))
                    (and nonnegative (< double 0d0)))
            (invalid "Coefficient has an invalid sign or positive magnitude."))
          double))
    (arithmetic-error () (invalid "Nonfinite or unrepresentable numerical value."))))

(defstruct (acoustic-realm (:constructor %realm) (:copier nil))
  (id nil :read-only t) (parent nil :read-only t)
  (q 0d0 :read-only t) (v 0d0 :read-only t)
  (m 1d0 :read-only t) (k 1d0 :read-only t) (r 0d0 :read-only t)
  (amplitude 0d0 :read-only t) (omega 0d0 :read-only t) (phase 0d0 :read-only t))

(defun make-acoustic-realm (id &key parent (q 0d0) (v 0d0) (m 1d0) (k 1d0)
                                   (r 0d0) (amplitude 0d0) (omega 0d0) (phase 0d0))
  (%realm :id (sephirion::identifier id) :parent (when parent (sephirion::identifier parent))
          :q (number-value q) :v (number-value v) :m (number-value m :positive t)
          :k (number-value k :positive t) :r (number-value r :nonnegative t)
          :amplitude (number-value amplitude) :omega (number-value omega :nonnegative t)
          :phase (number-value phase)))

(defstruct (coupling (:constructor %coupling) (:copier nil))
  (id nil :read-only t) (a nil :read-only t) (b nil :read-only t)
  (stiffness 0d0 :read-only t) (enabled t :read-only t))

(defun make-coupling (id a b stiffness &key (enabled t))
  (unless (member enabled '(t nil)) (invalid "Coupling enabled flag must be T or NIL."))
  (let ((a (sephirion::identifier a)) (b (sephirion::identifier b)))
    (when (string= a b) (invalid "Self coupling is unsupported."))
    (when (string< b a) (rotatef a b))
    (%coupling :id (sephirion::identifier id) :a a :b b
               :stiffness (number-value stiffness :nonnegative t) :enabled enabled)))

(defstruct (acoustic-network (:constructor %network) (:copier nil))
  (nodes nil :read-only t) (edges nil :read-only t)
  (state nil :read-only t) (dt 0d0 :read-only t) (tick 0 :read-only t)
  (initial-energy 0d0 :read-only t))

(defun require-acoustic (network)
  (unless (acoustic-network-p network) (invalid "Expected an acoustic network."))
  network)

(defun force-at (node time)
  (* (acoustic-realm-amplitude node)
     (cos (+ (* (acoustic-realm-omega node) time) (acoustic-realm-phase node)))))

(defun energy-parts (network state)
  "Local energies, half-edge allocated energies, and total energy."
  (let* ((nodes (acoustic-network-nodes network))
         (local (make-array (length nodes) :initial-element 0d0)))
    (loop for node across nodes for i from 0 for j = (* 2 i)
          do (setf (aref local i)
                   (* 0.5d0 (+ (* (acoustic-realm-m node) (expt (aref state (1+ j)) 2))
                                (* (acoustic-realm-k node) (expt (aref state j) 2))))))
    (let ((allocated (copy-seq local)))
      (dolist (edge (acoustic-network-edges network))
        (destructuring-bind (i j stiffness) edge
          (let ((half (* 0.25d0 stiffness (expt (- (aref state (* 2 i))
                                                   (aref state (* 2 j))) 2))))
            (incf (aref allocated i) half)
            (incf (aref allocated j) half))))
      (values local allocated (reduce #'+ allocated :initial-value 0d0)))))

(defun make-acoustic-network (realms couplings &key (dt 0.02d0))
  "Copy declarations; reuse the exact engine's containment validation, not its dynamics."
  (sephirion::proper-list-required realms)
  (sephirion::proper-list-required couplings)
  (unless (and realms (every #'acoustic-realm-p realms) (every #'coupling-p couplings))
    (invalid "Need nonempty acoustic realms and explicit coupling declarations."))
  (setf dt (number-value dt :positive t))
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (edge couplings)
      (let ((key (list (coupling-a edge) (coupling-b edge))))
        (when (gethash key seen) (invalid "Duplicate unordered coupling pair."))
        (setf (gethash key seen) t))))
  ;; This public validator checks IDs, endpoint existence, cycles and boundaries.
  ;; Temporary zero rational states and identity paths are topology declarations only.
  (sephirion:make-network
   (mapcar (lambda (node) (sephirion:make-realm (acoustic-realm-id node)
                                               :parent (acoustic-realm-parent node))) realms)
   (mapcar (lambda (edge) (sephirion:make-path (coupling-id edge) (coupling-a edge)
                                              (coupling-b edge) :enabled (coupling-enabled edge)))
           couplings))
  (let* ((nodes (coerce
                 (sort (mapcar (lambda (node)
                                 (make-acoustic-realm
                                  (acoustic-realm-id node) :parent (acoustic-realm-parent node)
                                  :q (acoustic-realm-q node) :v (acoustic-realm-v node)
                                  :m (acoustic-realm-m node) :k (acoustic-realm-k node)
                                  :r (acoustic-realm-r node) :amplitude (acoustic-realm-amplitude node)
                                  :omega (acoustic-realm-omega node) :phase (acoustic-realm-phase node)))
                               realms) #'string< :key #'acoustic-realm-id) 'vector))
         (edges (loop for edge in (sort (copy-list couplings) #'string< :key #'coupling-id)
                      when (coupling-enabled edge)
                        collect (list (position (coupling-a edge) nodes :key #'acoustic-realm-id :test #'string=)
                                      (position (coupling-b edge) nodes :key #'acoustic-realm-id :test #'string=)
                                      (coupling-stiffness edge))))
         (state (make-array (+ (* 2 (length nodes)) 2) :initial-element 0d0)))
    (loop for node across nodes for i from 0
          do (setf (aref state (* 2 i)) (acoustic-realm-q node)
                   (aref state (1+ (* 2 i))) (acoustic-realm-v node)))
    (let ((network (%network :nodes nodes :edges edges :state state :dt dt)))
      (%network :nodes nodes :edges edges :state state :dt dt
                :initial-energy (nth-value 2 (energy-parts network state))))))

(defun acoustic-state (network)
  "Fresh #(q1 v1 ... qN vN cumulative-work cumulative-dissipation), sorted by ID."
  (copy-seq (acoustic-network-state (require-acoustic network))))

(defun acoustic-energy (network)
  (require-acoustic network)
  (nth-value 2 (energy-parts network (acoustic-network-state network))))

(defun acoustic-snapshot (network)
  (require-acoustic network)
  (let* ((state (acoustic-network-state network))
         (nodes (acoustic-network-nodes network)) (n (length nodes))
         (time (* (acoustic-network-tick network) (acoustic-network-dt network)))
         (work (aref state (* 2 n))) (loss (aref state (1+ (* 2 n)))))
    (multiple-value-bind (local allocated total) (energy-parts network state)
      (list :tick (acoustic-network-tick network) :time time :energy total :work work
            :dissipation loss :residual (+ (- total (acoustic-network-initial-energy network) work) loss)
            :realms (loop for node across nodes for i from 0 for j = (* 2 i)
                          for force = (force-at node time) for v = (aref state (1+ j))
                          collect (list :id (copy-seq (acoustic-realm-id node))
                                        :parent (when (acoustic-realm-parent node)
                                                  (copy-seq (acoustic-realm-parent node)))
                                        :q (aref state j) :v v :force force
                                        :local-energy (aref local i) :energy (aref allocated i)
                                        :input-power (* force v) :loss-power (* (acoustic-realm-r node) v v)))))))
