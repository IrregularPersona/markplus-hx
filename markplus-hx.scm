(require "helix/misc.scm")
(require "helix/static.scm")

(#%require-dylib "libmarkplus_hx"
  (only-in bar
           is-checkbox?
           change-checkbox-state!))

(provide checkbox_toggle!)

;;@doc
;;This toggles a checkbox within a line. No support for multiline yet.
(define (checkbox_toggle!)
  (extend_to_line_bounds)
  (if (is-checkbox? (current-highlighted-text!))
      (replace-selection-with (change-checkbox-state! (current-highlighted-text!)))
      (no_op)) ;; according to docs this just does nothing

  (collapse_selection)) 




