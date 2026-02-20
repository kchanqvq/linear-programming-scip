(in-package #:linear-programming-scip)

(defstruct scip-solution
  problem
  objective-value
  var-values
  var-index)

(defmethod linear-programming:solution-problem ((solution scip-solution))
  (scip-solution-problem solution))

(defmethod linear-programming:solution-objective-value ((solution scip-solution))
  (scip-solution-objective-value solution))

(defmethod linear-programming:solution-variable ((solution scip-solution) variable)
  (aref (scip-solution-var-values solution) (gethash variable (scip-solution-var-index solution))))

(define-condition scip-operation-failure (linear-programming:solver-error)
  ((retcode :initarg :retcode :accessor retcode))
  (:report (lambda (err stream)
             (format stream "SCIP operation failed with return code ~A" (retcode err))))
  (:documentation "Indicates that general SCIP operation failed."))

(define-condition scip-solver-error (linear-programming:solver-error)
  ((status :initarg :status :accessor status))
  (:report (lambda (err stream)
             (format stream "SCIP Solver failed with status ~A" (status err))))
  (:documentation "Indicates that SCIP solver failed."))

(define-condition premature-solution-error (linear-programming:solver-error)
  ((status :initarg :exit-code :accessor status))
  (:report (lambda (err stream)
             (format stream "Solver returned prematurely with status ~A"
                     (status err))))
  (:documentation "Indicates that solver returned prematurely."))

(declaim (inline as-scip-float scip-float-type))
(defun as-scip-float (num)
  "Converts a number to a type that CFFI can convert to a C double"
  (float num 0.0l0))

(defun scip-float-type ()
  (type-of 0.0l0))

(defun check-retcode (retcode)
  (case retcode
    (:okay t)
    (t (error 'scip-operation-failure :retcode retcode))))

(defun check-solution-status (status)
  (case status
    (:optimal t)
    (:infeasible
     (error 'linear-programming:infeasible-problem-error))
    (:unbounded
     (error 'linear-programming:unbounded-problem-error))
    ((:terminate :node-limit :total-node-limit :stall-node-limit
      :time-limit :mem-limit
      :gap-limit :primal-limit :dual-limit
      :sol-limit :best-sol-limit :restart-limit)
     (cerror "Return the current solution" 'premature-solution-error
             :status status))
    (t
     (error 'scip-solver-error :status status))))

(defun scip-solver (problem &key time-limit node-limit emphasis)
  (let* ((prob-constraints (linear-programming:problem-constraints problem))
         (prob-vars (linear-programming:problem-vars problem))
         (prob-obj-func (linear-programming:problem-objective-func problem))
         (var-count (length prob-vars))
         (prob-bounds (linear-programming:problem-var-bounds problem))
         (int-vars (linear-programming:problem-integer-vars problem))
         ;; map of variable's to their indices
         (var-index (make-hash-table :size (ceiling (* 5 var-count) 4) :rehash-threshold 1)))
    (with-foreign-objects ((p-scip :pointer)
                           (p-var :pointer var-count))

      ;; NULL fill p-var first, so we can reliably free
      ;; allocated variables (especially in case of error)
      (dotimes (i var-count)
        (setf (mem-aref p-var :pointer i) (null-pointer)))

      ;; Create SCIP instance
      (check-retcode (%create p-scip))

      (let ((scip (mem-ref p-scip :pointer)))
        (unwind-protect
             (progn
               ;; Set parameters
               (when time-limit
                 (check-retcode (%set-real-param scip "limits/time" (as-scip-float time-limit))))
               (when node-limit
                 (check-retcode (%set-longint-param scip "limits/nodes" node-limit)))
               (when emphasis
                 (check-retcode (%set-emphasis scip emphasis nil)))

               (check-retcode (%include-default-plugins scip))

               ;; Create problem
               (check-retcode
                (%create-prob-basic scip "SCIP-FOR-LISP"))
               (check-retcode (%set-objsense scip
                                             (ecase (linear-programming:problem-type problem)
                                               (linear-programming:max :maximize)
                                               (linear-programming:min :minimize))))

               ;; Create and add variables
               (loop :for var :across prob-vars
                     :for i :from 0
                     :for bound = (or (rest (assoc var prob-bounds))
                                      '(0 . nil))
                     :for var-type = (if (member var int-vars) :integer :continuous)
                     :for obj-coeff = (or (rest (assoc var prob-obj-func)) 0)
                     :do (setf (gethash var var-index) i)
                     :do (check-retcode
                          (%create-var-basic scip
                                             (inc-pointer p-var (* i (foreign-type-size :pointer)))
                                             (string var)
                                             (if (car bound)
                                                 (as-scip-float (car bound))
                                                 (- (%infinity scip)))
                                             (if (cdr bound)
                                                 (as-scip-float (cdr bound))
                                                 (%infinity scip))
                                             (as-scip-float obj-coeff)
                                             var-type))
                     :do (check-retcode
                          (%add-var scip (mem-aref p-var :pointer i))))

               ;; Create and add constraints
               (with-foreign-object (p-cons :pointer)
                 (loop :for constraint :in prob-constraints
                       :for i :from 0
                       :for op = (first constraint)
                       :for entries = (second constraint)
                       :for bound = (as-scip-float (third constraint))
                       :for var-count = (length entries)
                       :do (with-foreign-objects ((vars :pointer var-count)
                                                  (vals :double var-count))
                             (loop :for (var . coef) :in entries
                                   :for j :from 0
                                   :do (setf (mem-aref vars :pointer j)
                                             (mem-aref p-var :pointer (gethash var var-index)))
                                   :do (setf (mem-aref vals :double j) (as-scip-float coef)))
                             (check-retcode
                              (%create-cons-basic-linear scip
                                                         p-cons
                                                         (format nil "CONS-~A" i)
                                                         var-count
                                                         vars
                                                         vals
                                                         (ecase op
                                                           ((>= =) bound)
                                                           (<= (- (%infinity scip))))
                                                         (ecase op
                                                           ((<= =) bound)
                                                           (>= (%infinity scip)))))
                             (unwind-protect
                                  (check-retcode (%add-cons scip (mem-ref p-cons :pointer)))
                               (check-retcode (%release-cons scip p-cons))))))

               ;; Solve it
               (check-retcode (%solve scip))
               (check-solution-status (%get-status scip))

               ;; Copy solution to Lisp
               (let ((sol (%get-best-sol scip))
                     (var-values (make-array var-count :element-type (scip-float-type))))
                 (with-foreign-object (p-val :double var-count)
                   (check-retcode (%get-sol-vals scip sol var-count p-var p-val))
                   (dotimes (i var-count)
                     (setf (aref var-values i) (mem-aref p-val :double i))))
                 (make-scip-solution :problem problem
                                     :objective-value (%get-sol-orig-obj scip sol)
                                     :var-values var-values
                                     :var-index var-index)))

          ;; Clean up
          (unwind-protect
               (dotimes (i var-count)
                 (unless (null-pointer-p (mem-aref p-var :pointer i))
                   (check-retcode
                    (%release-var scip
                                  (inc-pointer p-var (* i (foreign-type-size :pointer)))))))
           (check-retcode (%free p-scip))))))))

(defvar scip-solver (function scip-solver))
