(require "helix/commands.scm")
(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")

(require-builtin helix/core/text as text.) ; need for the rope -> string conversion

(#%require-dylib "libmarkplus_hx"
  (only-in is-checkbox?
           change-checkbox-state!
           has-table-elements?
           format-tables-in-buffer
           is-table-line?
           format-current-table
           detect-table-at-cursor))

(provide new-note
         checkbox_toggle!)

(provide move-cursor)

(define (get-document-path) (editor-document->path (editor->doc-id (editor-focus))))

;;@doc
;;Creates a new note with a given filename. If not given, defaults to `note.md`
(define (new-note . args)
  (let ((filename (if (null? args)
                      "note.md"
                      (car args))))
    (new)
    (write (string-append filename ".md"))
    (set-status! (string-append "Created new note: " filename))))

;;@doc
;;This toggles a checkbox within a line. No support for multiline yet.
(define (checkbox_toggle!)
  (extend_to_line_bounds)
  (if (is-checkbox? (current-highlighted-text!))
      (replace-selection-with (change-checkbox-state! (current-highlighted-text!)))
      (no_op)) ;; according to docs this just does nothing
  (collapse_selection))

;;@doc
;;Gets the currently focused buffers content, and returns it as a string
(define (get-current-focused-buffer-as-string)
      (let* ([focus-view-id (editor-focus)]
             [doc-id (editor->doc-id focus-view-id)])
        (text.rope->string (editor->text doc-id))))

; (provide get-cursor-row
;          get-cursor-col)

; (define (get-cursor-row)
;   (set-status! (position-row (car current-cursor))))

; (define (get-cursor-col)
;   (set-status! (position-col (car current-cursor))))

(provide get-cursor-row-col)

(define (get-cursor-row-col)
  (match (current-cursor)
    [#f                      ; cursor invisible?
       (set-status! "No primary cursor is visible")]
    [(list pos kind)         ; when visible, it's a two‑element list: Position & CursorKind
       (set-status! (values (position-row pos) (position-col pos)))]))

(define (get-cursor-position)
  (match (current-cursor)
    [#f '(0, 0)]
    [(list pos kind) (list (position-row pos) (position-col pos))]))


(define (move-cursor row col)
  (goto row)
  (let loop ((i 0))
    (when (< i (string->int col))
          (move_char_right)
          (loop (+ i 1)))))

;; Table mode state
(define *table-mode* #f)

;;@doc
;;Toggle table mode on/off
(define (table-mode-toggle!)
  (set! *table-mode* (not *table-mode*))
  (if *table-mode*
      (begin
        (set-status! "Table mode: ON - Auto-formatting of tables is enabled!")
        (setup-table-mode-hooks!))
      (begin
        (set-status! "Table mode: OFF")
        (cleanup-table-mode-hooks!))))

;;@doc
;;Auto formats table on currently focused buffer
(define (auto-format-table!)
  (let* ([buffer-content (get-current-focused-buffer-as-string)]
         [cursor-pos (get-cursor-position)]
         [cursor-line (car cursor-pos)]
         [cursor-col (cadr cursor-pos)])
    (when (has-table-elements? buffer-content)
          (let ([formatted-content (format-tables-in-buffer buffer-content)])
            (select_all)
            (replace-selection-with formatted-content)
            (move-cursor cursor-line cursor-col)
            (set-status! "Tables formatted!")))))

;;@doc
;;Finds the next cell from the cursor
(define (table-next-cell!)
  (let* ([buffer-content (get-current-focused-buffer-as-string)]
         [cursor-pos (get-cursor-position)]
         [cursor-line (car cursor-pos)]
         [cursor-col (cadr cursor-pos)])
    (if (detect-table-at-cursor buffer-content cursor-line cursor-col)
        (begin
          (find_next_char "|")
          (move_char_right)
          (set-status! "Moved to next cell"))
        (begin
          (insert_tab)))))

;;@doc
;;Finds the previous cell from the cursor
(define (table-prev-cell!)
  (let* ([buffer-content (get-current-focused-buffer-as-string)]
         [cursor-pos (get-cursor-position)]
         [cursor-line (car cursor-pos)]
         [cursor-col (cadr cursor-pos)])
    (if (detect-table-at-cursor buffer-content cursor-line cursor-col)
        (begin
          (find_prev_char "|")
          (move_char_right)
          (set-status! "Moved to previous cell"))
        (begin
          (move_char_left)))))

;;@doc
;;Check if current line is a table line and auto-format if in table mode
(define (check-and-format-table-line!)
  (when *table-mode*
        (let* ([buffer-content (get-current-focused-buffer-as-string)]
               [cursor-pos (get-cursor-position)]
               [cursor-line (car cursor-pos)])
          (when (detect-table-at-cursor buffer-content cursor-line 0)
                (auto-format-table!)))))

;;@doc
;;Setup hooks for table mode
(define (setup-table-mode-hooks!)
  ;; TODO: no impl yet
  (set-status! "Table mode hooks activated"))

;;@doc
;;Cleanup hooks from setup
(define (cleanup-table-mode-hooks!)
  ;; TODO: no impl yet
  (set-status! "Table mode hooks deactivated"))

;;@doc
;;Handle pipe character insertion in table mode
(define (handle-pipe-in-table!)
  (insert_string "|")
  (when *table-mode*
    (check-and-format-table-line!)))

;;@doc
;;Handle newline in table mode
(define (handle-newline-in-table!)
  (let* ([buffer-content (get-current-focused-buffer-as-string)]
         [cursor-pos (get-cursor-position)]
         [cursor-line (car cursor-pos)])
    (if (and *table-mode* 
             (detect-table-at-cursor buffer-content cursor-line 0))
        (begin
          ;; Create new table row
          (open_below)
          (insert_string "| | |")  
          (move_char_left)
          (move_char_left)
          (move_char_left)
          (auto-format-table!))
        (begin
          ;; Normal newline
          (open_below)))))

; Extra exposed functions for keybinding
(provide table-mode-toggle!
         auto-format-table!
         table-next-cell!
         table-prev-cell!
         handle-pipe-in-table!
         handle-newline-in-table!)
