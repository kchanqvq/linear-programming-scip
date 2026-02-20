(defpackage #:linear-programming-scip
  (:use #:cl
        #:cffi)
  (:export #:scip-solver
           #:status
           #:scip-solver-error
           #:retcode
           #:scip-operation-failure
           #:premature-solution-error))
