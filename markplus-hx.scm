(require "helix/misc.scm")
(require "helix/static.scm")

(#%require-dylib "libmarkplus_hx"
  (only-in is-checkbox?
           change-checkbox-state!
           create-link!
           itemize-text!))

(provide checkbox-toggle!
         convert-to-link!
         create-codeblock!
         create-itemized-section!)

;;@doc
;;This toggles a checkbox within a line. No support for multiline yet.
(define (checkbox-toggle!)
  (extend_to_line_bounds)
  (if (is-checkbox? (current-highlighted-text!))
      (replace-selection-with (change-checkbox-state! (current-highlighted-text!)))
      (no_op)) ;; according to docs this just does nothing
  
  (collapse_selection))

;;@doc
;;This creates a link from the given selection
(define (convert-to-link!)
  (replace-selection-with (create-link! (current-highlighted-text!))))

;;@doc
;;Creates a codeblock. Could be empty or set with the prompt
(define (create-codeblock!)
  (push-component!
    (prompt "Language for codeblock: "
      (lambda (language)
              (let ([lang (trim language)])
                (if (string=? lang "")
                    (insert_string (string-append "```\n\n```"))
                    (insert_string (string-append "```" lang "\n\n```")))
                (move_line_up)
                (set-warning! (string-append "Inserted " lang " codeblock")))))))


(define (create-itemized-section!)
  (replace-selection-with (itemize-text! (current-highlighted-text!))))




