(require "helix/commands.scm")
(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")
(require "keymaps.scm")
(require "utils.scm")


(#%require-dylib "libmarkplus_hx"
  (only-in is-checkbox?
           change-checkbox-state!
           has-table-elements?
           format-tables-in-buffer
           is-table-line?
           format-current-table
           detect-table-at-cursor))

;; =============================================================================
;; TABLE MODE STATE & KEYBINDINGS
;; =============================================================================

;; Table mode state
(define *table-mode* #f)

;; Define table mode keybindings following the reference pattern
(define TABLE-MODE-KEYBINDINGS 
  (hash "normal" (hash 
                   ;; Core table-aware key overrides
                   "|" ':smart-pipe
                   "ret" ':smart-enter
                   "tab" ':smart-tab
                   "S-tab" ':smart-shift-tab
                   
                   ;; Table-specific operations under space-t
                   "space" (hash "t" (hash 
                                       "m" ':table-mode-toggle     ; <space>tm - toggle mode
                                       "f" ':auto-format-table     ; <space>tf - format tables
                                       "n" ':create-table-row      ; <space>tn - new row
                                       "d" ':delete-table-row      ; <space>td - delete row
                                       "c" ':add-table-column      ; <space>tc - add column
                                       "x" ':delete-table-column   ; <space>tx - delete column
                                       "h" ':table-move-left       ; <space>th - move left
                                       "l" ':table-move-right      ; <space>tl - move right
                                       "j" ':table-move-down       ; <space>tj - move down
                                       "k" ':table-move-up)))       ; <space>tk - move up
        
        "insert" (hash 
                   ;; Insert mode table-aware overrides
                   "|" ':smart-pipe-insert
                   "ret" ':smart-enter-insert
                   "tab" ':smart-tab-insert
                   "S-tab" ':smart-shift-tab-insert)))

;; Standard keybindings (will be modified for table mode)
(define standard-keybindings (deep-copy-global-keybindings))

;; Table mode keybindings (merged with standard)
(define table-mode-keybindings (deep-copy-global-keybindings))

;; Initialize keybindings
(merge-keybindings table-mode-keybindings TABLE-MODE-KEYBINDINGS)

;; Set up the global toggle keybinding (always available)
(add-global-keybinding (hash "normal" (hash "space" (hash "t" (hash "m" ':table-mode-toggle)))))

;; =============================================================================
;; TABLE MODE MANAGEMENT
;; =============================================================================

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
      (no_op))
  (collapse_selection))

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
