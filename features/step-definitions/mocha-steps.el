(require 'ert)
(require 'f)
(require 'tree-sitter-langs)

(When "^I visit sample project file \"\\([^\"]+\\)\"$"
      (lambda (file)
        (find-file (f-expand file))))

(When "^I run the command \"\\([^\"]+\\)\"$"
      (lambda (command)
        (When "I start an action chain")
        (And "I press \"M-x\"")
        (And (format "I type %S" command))
        (And "I execute the action chain")))

(When "^I run the command \"\\([^\"]+\\)\" expecting an error$"
      (lambda (command)
        (When "I start an action chain")
        (And "I press \"M-x\"")
        (And (format "I type %S" command))
        (should-error
         (And "I execute the action chain"))))

(Then "^I should see buffer \"\\([^\"]+\\)\"$"
      (lambda (buffer-name)
        (let ((buffer-names (-map 'buffer-name (-map 'window-buffer (window-list)))))
          (should (-contains? buffer-names buffer-name)))))

(Then "^I should see contents in buffer \"\\([^\"]+\\)\":$"
      (lambda (buffer contents)
        (with-current-buffer buffer
          (should (s-contains? contents (buffer-substring-no-properties (point-min) (point-max)))))))

(When "^I wait for the compilation to finish$"
      (lambda (callback)
        (add-hook 'compilation-finish-functions callback)))


(When "^I enable tree-sitter-mode$"
      (lambda ()
        (When "I run the command \"tree-sitter-mode\"")))
