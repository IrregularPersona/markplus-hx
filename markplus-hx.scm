(require "helix/commands.scm")
(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")
(require "keymaps.scm")
(require "utils.scm")


(#%require-dylib "libmarkplus_hx"
  (only-in bar
           is-checkbox?
           change-checkbox-state!
           create-link!
           ))

(provide checkbox_toggle!
        convert-to-link!
        create-codeblock!)

;;@doc
;; Toggle table mode on/off with proper keybinding switching
(define (table-mode-toggle!)
  (set! *table-mode* (not *table-mode*))
  
  (if *table-mode*
      (begin
        ;; Switch to table mode keybindings
        (keybindings table-mode-keybindings)
        (set-status! "Table mode: ON - Smart table editing enabled"))
      (begin
        ;; Switch back to standard keybindings
        (keybindings standard-keybindings)
        (set-status! "Table mode: OFF - Normal editing restored"))))

;;@doc
;; Smart pipe handler - formats tables automatically in normal mode
(define (smart-pipe!)
  (insert_char #\|)
  (when (and *table-mode* (cursor-in-table?))
    (auto-format-table!)))

;;@doc
;; Smart pipe handler for insert mode
(define (smart-pipe-insert!)
  (insert_char #\|)
  (when (and *table-mode* (cursor-in-table?))
    (auto-format-table!)))

;;@doc
;; Smart enter handler - creates table rows when in tables
(define (smart-enter!)
  (if (and *table-mode* (cursor-in-table?))
      (create-new-table-row!)
      (open_below)))

;;@doc
;; Smart enter handler for insert mode
(define (smart-enter-insert!)
  (if (and *table-mode* (cursor-in-table?))
      (begin
        (create-new-table-row!)
        ;; Move to first cell of new row
        (move-to-first-cell-of-row!))
      (insert_newline)))

;;@doc
;; Smart tab handler - moves between table cells
(define (smart-tab!)
  (if (and *table-mode* (cursor-in-table?))
      (table-next-cell!)
      (insert_char #\tab)))

;;@doc
;; Smart tab handler for insert mode  
(define (smart-tab-insert!)
  (if (and *table-mode* (cursor-in-table?))
      (table-next-cell!)
      (insert_char #\tab)))

;;@doc
;; Smart shift-tab handler
(define (smart-shift-tab!)
  (if (and *table-mode* (cursor-in-table?))
      (table-prev-cell!)
      (unindent)))

;;@doc
;; Smart shift-tab handler for insert mode
(define (smart-shift-tab-insert!)
  (if (and *table-mode* (cursor-in-table?))
      (table-prev-cell!)
      (unindent)))

;; =============================================================================
;; TABLE OPERATIONS
;; =============================================================================

;;@doc
;; Check if cursor is currently in a table
(define (cursor-in-table?)
  (let* ([buffer-content (get-current-focused-buffer-as-string)]
         [cursor-pos (get-cursor-position)]
         [cursor-line (car cursor-pos)]
         [cursor-col (cadr cursor-pos)])
    (detect-table-at-cursor buffer-content cursor-line cursor-col)))

;;@doc
;; Auto-format all tables in current buffer
(define (auto-format-table!)
  (let* ([buffer-content (get-current-focused-buffer-as-string)]
         [cursor-pos (get-cursor-position)])
    (when (has-table-elements? buffer-content)
      (let ([formatted-content (format-tables-in-buffer buffer-content)])
        (select_all)
        (replace-selection-with formatted-content)
        ;; Try to restore cursor position (may need adjustment after formatting)
        (move-cursor (car cursor-pos) (cadr cursor-pos))
        (set-status! "Tables formatted!")))))

;;@doc
;; Create a new table row
(define (create-new-table-row!)
  (let ([current-line (get-current-line-content)])
    (when (is-table-line? current-line)
      (let ([column-count (count-table-columns current-line)])
        (end_of_line)
        (insert_char #\newline)
        (insert_string (create-empty-table-row column-count))
        (auto-format-table!)
        (move-to-first-cell-of-row!)
        (set-status! "New table row created")))))

;;@doc
;; Delete current table row
(define (delete-table-row!)
  (when (and *table-mode* (cursor-in-table?))
    (kill_to_line_start)
    (delete_char_forward)  ; Delete the newline
    (auto-format-table!)
    (set-status! "Table row deleted")))

;;@doc
;; Add a column to current table (placeholder)
(define (add-table-column!)
  (when (and *table-mode* (cursor-in-table?))
    ;; This would need more complex logic to add columns to all rows
    (set-status! "Add column - not implemented yet")))

;;@doc
;; Delete current table column (placeholder)  
(define (delete-table-column!)
  (when (and *table-mode* (cursor-in-table?))
    ;; This would need more complex logic to remove columns from all rows
    (set-status! "Delete column - not implemented yet")))

;;@doc  
;; Move to next table cell
(define (table-next-cell!)
  (when (cursor-in-table?)
    ;; Find next | character
    (if (search_next "|")
        (begin
          (move_char_right)
          (set-status! "Next cell"))
        (set-status! "No next cell"))))

;;@doc
;; Move to previous table cell  
(define (table-prev-cell!)
  (when (cursor-in-table?)
    ;; Find previous | character
    (if (search_prev "|")
        (begin
          (move_char_right)
          (set-status! "Previous cell"))
        (set-status! "No previous cell"))))

;; =============================================================================
;; TABLE NAVIGATION
;; =============================================================================

;;@doc
;; Move to cell to the left
(define (table-move-left!)
  (when (and *table-mode* (cursor-in-table?))
    (table-prev-cell!)))

;;@doc  
;; Move to cell to the right
(define (table-move-right!)
  (when (and *table-mode* (cursor-in-table?))
    (table-next-cell!)))

;;@doc
;; Move to cell above (placeholder - needs column tracking)
(define (table-move-up!)
  (when (and *table-mode* (cursor-in-table?))
    (move_line_up)
    (set-status! "Moved up (basic implementation)")))

;;@doc
;; Move to cell below (placeholder - needs column tracking)
(define (table-move-down!)
  (when (and *table-mode* (cursor-in-table?))
    (move_line_down)
    (set-status! "Moved down (basic implementation)")))

;;@doc
;; Creates a new note with a given filename. If not given, defaults to `note.md`
(define (new-note . args)
  (let ((filename (if (null? args)
                      "note.md"
                      (car args))))
    (new)
    (write (string-append filename ".md"))
    (set-status! (string-append "Created new note: " filename))))

;;@doc
;; This toggles a checkbox within a line. No support for multiline yet.
(define (checkbox_toggle!)
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







;; Export main functions
(provide table-mode-toggle!
         auto-format-table!
         create-new-table-row!
         delete-table-row!
         add-table-column!
         delete-table-column!
         table-next-cell!
         table-prev-cell!
         table-move-left!
         table-move-right!
         table-move-up!
         table-move-down!
         smart-pipe!
         smart-pipe-insert!
         smart-enter!
         smart-enter-insert!
         smart-tab!
         smart-tab-insert!
         smart-shift-tab!
         smart-shift-tab-insert!
         new-note
         checkbox_toggle!)
