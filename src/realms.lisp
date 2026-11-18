(in-package #:sephirion)

(define-condition model-error (error)
  ((message :initarg :message :reader model-error-message))
  (:report (lambda (condition stream)
             (write-string (model-error-message condition) stream))))

(defun reject-model (control &rest arguments)
  (error 'model-error :message (apply #'format nil control arguments)))

(defun valid-number (value)
  "Accept exact rationals with at most 256 bits per numerator/denominator."
  (unless (and (rationalp value)
               (<= (integer-length (abs (numerator value))) 256)
               (<= (integer-length (denominator value)) 256))
    (reject-model "Expected a bounded exact rational, got ~S." value))
  value)

(defun identifier (value)
  (unless (and (stringp value) (plusp (length value)))
    (reject-model "Expected a nonempty string identifier, got ~S." value))
  (copy-seq value))

(defun proper-list-required (value)
  (unless (and (listp value)
               (handler-case (integerp (list-length value)) (type-error () nil)))
    (reject-model "Expected a finite proper list."))
  value)

(defstruct (realm (:constructor %make-realm) (:copier nil))
  (id "" :read-only t) (value 0 :read-only t) (parent nil :read-only t))

(defun make-realm (id &key (state 0) parent)
  "Declare a realm. PARENT names its immediate container, or NIL for a root."
  (%make-realm :id (identifier id) :value (valid-number state)
               :parent (when parent (identifier parent))))

(defstruct (signal-path (:constructor %make-path) (:copier nil))
  (id "" :read-only t) (source "" :read-only t) (target "" :read-only t)
  (operator :identity :read-only t) (gain 1 :read-only t)
  (offset 0 :read-only t) (enabled t :read-only t))

(defun make-path (id source target &key (operator :identity) (gain 1) (offset 0)
                                       (enabled t))
  "Declare one pure operator; endpoint and boundary checks occur at assembly."
  (valid-number gain)
  (valid-number offset)
  (unless (member enabled '(t nil)) (reject-model "ENABLED must be T or NIL."))
  (unless (member operator '(:identity :scale :affine))
    (reject-model "Unsupported path operator ~S." operator))
  (when (or (and (eq operator :identity) (or (/= gain 1) (/= offset 0)))
            (and (eq operator :scale) (/= offset 0)))
    (reject-model "Operator ~S does not support these coefficients." operator))
  (%make-path :id (identifier id) :source (identifier source) :target (identifier target)
              :operator operator :gain gain :offset offset :enabled enabled))

(defun transform-signal (path signal)
  "Evaluate the pure operator, independently of the path's routing enable flag."
  (unless (signal-path-p path) (reject-model "Expected a path."))
  (valid-number signal)
  (valid-number
   (ecase (signal-path-operator path)
     (:identity signal)
     (:scale (* (signal-path-gain path) signal))
     (:affine (+ (* (signal-path-gain path) signal) (signal-path-offset path))))))

(defstruct (realm-network (:constructor %make-network) (:copier nil))
  (realms nil :read-only t) (paths nil :read-only t)
  (tick 0 :read-only t) (history nil :read-only t))

(defun require-network (network)
  (unless (realm-network-p network) (reject-model "Expected a realm network."))
  network)

(defun find-realm (network id)
  (require-network network)
  (or (find (identifier id) (realm-network-realms network) :key #'realm-id :test #'string=)
      (reject-model "Unknown realm ~S." id)))

(defun realm-state (network id)
  "Read the committed scalar state of ID."
  (realm-value (find-realm network id)))

(defun realm-children (network id)
  "Return a fresh, sorted list of IDs immediately contained by ID."
  (find-realm network id)
  (loop for realm in (realm-network-realms network)
        when (equal id (realm-parent realm)) collect (copy-seq (realm-id realm))))

(defun snapshot-of (realms tick)
  (list :tick tick :states
        (loop for realm in realms collect (list (copy-seq (realm-id realm))
                                               (realm-value realm)))))

(defun copy-record (value)
  "Copy snapshot trees including mutable identifier strings."
  (typecase value
    (cons (cons (copy-record (car value)) (copy-record (cdr value))))
    (string (copy-seq value))
    (t value)))

(defun network-tick (network) (realm-network-tick (require-network network)))
(defun network-snapshot (network)
  (require-network network)
  (snapshot-of (realm-network-realms network) (network-tick network)))
(defun network-history (network)
  (copy-record (realm-network-history (require-network network))))

(defun unique-ids (objects key)
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (object objects)
      (let ((id (funcall key object)))
        (when (gethash id seen) (reject-model "Duplicate identifier ~S." id))
        (setf (gethash id seen) t)))))

(defun make-network (realms paths)
  "Validate a containment forest and local paths. Copy all declarations."
  (proper-list-required realms)
  (proper-list-required paths)
  (unless (and realms (every #'realm-p realms) (every #'signal-path-p paths))
    (reject-model "A network needs at least one realm and valid declarations."))
  (unique-ids realms #'realm-id)
  (unique-ids paths #'signal-path-id)
  (let* ((owned-realms
           (sort (loop for realm in realms
                       collect (make-realm (realm-id realm) :state (realm-value realm)
                                            :parent (realm-parent realm)))
                 #'string< :key #'realm-id))
         (owned-paths
           (sort (loop for path in paths
                       collect (make-path (signal-path-id path) (signal-path-source path)
                                           (signal-path-target path)
                                           :operator (signal-path-operator path)
                                           :gain (signal-path-gain path)
                                           :offset (signal-path-offset path)
                                           :enabled (signal-path-enabled path)))
                 #'string< :key #'signal-path-id))
         (network (%make-network :realms owned-realms :paths owned-paths)))
    ;; Walk ancestry from each realm: missing parents, self-containment and cycles fail.
    (dolist (realm owned-realms)
      (loop with seen = nil for cursor = realm then (find-realm network (realm-parent cursor))
            do (when (member (realm-id cursor) seen :test #'string=)
                 (reject-model "Containment cycle at ~S." (realm-id cursor)))
               (push (realm-id cursor) seen)
            while (realm-parent cursor)))
    ;; Every edge is between siblings (including roots), or a parent and direct child.
    (dolist (path owned-paths)
      (let ((source (find-realm network (signal-path-source path)))
            (target (find-realm network (signal-path-target path))))
        (unless (or (equal (realm-parent source) (realm-parent target))
                    (equal (realm-id source) (realm-parent target))
                    (equal (realm-id target) (realm-parent source)))
          (reject-model "Path ~S bypasses a nesting boundary." (signal-path-id path)))))
    (%make-network :realms owned-realms :paths owned-paths
                   :history (list (snapshot-of owned-realms 0)))))

(defun ordered-objects (objects requested key)
  "An optional exact permutation makes execution-order independence testable."
  (if (null requested) objects
      (progn
        (proper-list-required requested)
        (unless (and (= (length objects) (length requested))
                     (every #'stringp requested)
                     (= (length requested) (length (remove-duplicates requested :test #'string=)))
                     (every (lambda (id) (find id objects :key key :test #'string=)) requested))
          (reject-model "Execution order must be a permutation of all identifiers."))
        (mapcar (lambda (id) (find id objects :key key :test #'string=)) requested))))

(defun step-network (network &key realm-order path-order)
  "Compute from one immutable snapshot, validate, then return a committed successor.
No part of NETWORK changes on success or failure. No arbitrary callbacks run."
  (require-network network)
  (let* ((realms (ordered-objects (realm-network-realms network) realm-order #'realm-id))
         (paths (ordered-objects (realm-network-paths network) path-order #'signal-path-id))
         (incoming (make-hash-table :test #'equal)))
    ;; Phase one: all signals read the old network. Exact sums introduce no rounding.
    (dolist (path paths)
      (when (signal-path-enabled path)
        (incf (gethash (signal-path-target path) incoming 0)
              (transform-signal path (realm-state network (signal-path-source path))))))
    (let* ((next-realms
             (sort (loop for realm in realms
                         collect (make-realm
                                  (realm-id realm) :parent (realm-parent realm)
                                  :state (+ (realm-value realm)
                                            (gethash (realm-id realm) incoming 0))))
                   #'string< :key #'realm-id))
           (tick (1+ (network-tick network))))
      ;; Phase two: construct a successor only after EVERY candidate was validated.
      (%make-network :realms next-realms :paths (realm-network-paths network) :tick tick
                     :history (append (realm-network-history network)
                                      (list (snapshot-of next-realms tick)))))))

(defun run-network (network steps)
  (require-network network)
  (unless (and (integerp steps) (>= steps 0))
    (reject-model "Step count must be a nonnegative integer."))
  (loop repeat steps do (setf network (step-network network)) finally (return network)))

(defun print-network-history (network &optional (stream *standard-output*))
  (dolist (snapshot (network-history network))
    (format stream "tick ~D:" (getf snapshot :tick))
    (dolist (entry (getf snapshot :states))
      (format stream " ~S=~A" (first entry) (second entry)))
    (terpri stream))
  network)
