(require "helix/editor.scm")
(require-builtin helix/core/text as text.)

(provide get-current-focused-buffer-as-string
         get-cursor-position
         move-cursor
         get-current-line-content
         count-table-columns
         create-empty-table-row
         move-to-first-cell-of-row!)

(define (get-current-focused-buffer-as-string)
  (let* ([focus-view-id (editor-focus)]
         [doc-id (editor->doc-id focus-view-id)])
    (text.rope->string (editor->text doc-id))))

(define (get-cursor-position)
  (match (current-cursor)
    [#f '(1 1)]  ; default if no cursor
    [(list pos kind) (list (position-row pos) (position-col pos))]))

(define (move-cursor row col)
  (goto row)
  (let loop ((i 0))
    (when (< i col)
          (move_char_right)
          (loop (+ i 1)))))

(define (get-current-line-content)
  (extend_to_line_bounds)
  (let ([content (current-highlighted-text!)])
    (collapse_selection)
    content))

(define (count-table-columns line)
  ;; Count | characters minus 1 (for the outer |)
  (max 1 (- (length (filter (lambda (c) (eq? c #\|)) (string->list line))) 1)))

(define (create-empty-table-row column-count)
  (string-append "|" 
                 (string-join (make-list column-count " ") "|")
                 "|"))

(define (move-to-first-cell-of-row!)
  (beginning_of_line)
  (when (search_next "|")
    (move_char_right)))

