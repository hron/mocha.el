
;;;; mocha-opts-file

(ert-deftest mocha-test/mocha-opts-file/return-correct-opts-file ()
  (mocha-test/with-sandbox
   (f-mkdir (f-join default-directory "test"))
   (f-mkdir (f-join default-directory "test" "unit"))
   (f-mkdir (f-join default-directory "test" "acceptance"))
   (f-mkdir (f-join default-directory "test" "integration"))
   (let ((unit-test-file (f-join default-directory "test" "unit" "test.coffee"))
         (unit-opts-file (f-join default-directory "test" "unit" "mocha.opts"))
         (acceptance-test-dir (f-join default-directory "test" "acceptance"))
         (acceptance-opts-file (f-join default-directory "test" "acceptance" "mocha.opts"))
         (integration-test-file (f-join default-directory "test" "integration" "test.coffee")))
     (f-touch unit-test-file)
     (f-touch unit-opts-file)
     (f-touch acceptance-opts-file)
     (f-touch integration-test-file)
     (should (equal (mocha-opts-file unit-test-file) unit-opts-file))
     (should (equal (mocha-opts-file acceptance-test-dir) acceptance-opts-file))
     (should-not (mocha-opts-file integration-test-file)))))


;;;; mocha-generate-command

(ert-deftest mocha-test/mocha-generate-command/return-command-including-mocha-opts-option ()
  (mocha-test/with-sandbox
   (f-mkdir (f-join default-directory "test"))
   (f-mkdir (f-join default-directory "test" "unit"))
   (f-mkdir (f-join default-directory "test" "integration"))
   (let ((unit-test-file (f-join default-directory "test" "unit" "test.coffee"))
         (unit-opts-file (f-join default-directory "test" "unit" "mocha.opts"))
         (integration-test-file (f-join default-directory "test" "integration" "test.coffee")))
     (f-touch unit-test-file)
     (f-touch unit-opts-file)
     (f-touch integration-test-file)
     (should (s-contains? (concat "--opts " unit-opts-file) (mocha-generate-command nil unit-test-file)))
     (should-not (s-contains? "--opts" (mocha-generate-command nil integration-test-file))))))

(ert-deftest mocha-test/mocha-generate-command/return-command-with-correct-reporter ()
  (mocha-test/with-sandbox
   (should (s-contains? "--reporter spec" (mocha-generate-command nil)))
   (let ((mocha-reporter "dot"))
     (should (s-contains? "--reporter dot" (mocha-generate-command nil))))))


;;;; mocha-find-project-root

(ert-deftest mocha-test/mocha-find-project-root/return-path-to-project-root ()
  (mocha-test/with-sandbox
   (should (f-same? (mocha-find-project-root) mocha-test/sandbox-path))
   (should (s-ends-with? "/" (mocha-find-project-root)))
   (let ((foo-dir (f-join default-directory "foo")))
     (f-mkdir foo-dir)
     (let ((default-directory foo-dir))
       (should (f-same? (mocha-find-project-root) mocha-test/sandbox-path))))))

(ert-deftest mocha-test/mocha-find-project-root/return-nil-unless-package-file-exist ()
  (mocha-test/with-sandbox
   (f-delete "package.json" :force)
   (should-not (mocha-find-project-root))))


;;;; node-error-regexp

(ert-deftest mocha-test/node-error-regexp/unix-path ()
  (let ((line "    at Connection.parseE (/app/pitia-server/node_modules/pg/lib/connection.js:554:11)"))
    (should (string-match node-error-regexp line))
    ;; 1 is file, 2 is line, 3 is column
    (should (string= (match-string (nth 1 (car node-error-regexp-alist)) line)
                     "/app/pitia-server/node_modules/pg/lib/connection.js"))
    (should (string= (match-string (nth 2 (car node-error-regexp-alist)) line) "554"))
    (should (string= (match-string (nth 3 (car node-error-regexp-alist)) line) "11"))))

(ert-deftest mocha-test/node-error-regexp/windows-path ()
  (let ((line
         "    at Timeout.callback [as _onTimeout] (node_modules\\jsdom\\lib\\jsdom\\browser\\Window.js:477:19)"))
    (should (string-match node-error-regexp line))
    ;; 1 is file, 2 is line, 3 is column
    (should (string= (match-string (nth 1 (car node-error-regexp-alist)) line)
                     "node_modules\\jsdom\\lib\\jsdom\\browser\\Window.js"))
    (should (string= (match-string (nth 2 (car node-error-regexp-alist)) line) "477"))
    (should (string= (match-string (nth 3 (car node-error-regexp-alist)) line) "19"))))


;;;; mocha-find-current-test

(ert-deftest mocha-test/mocha-find-current-test/js+tree-sitter ()
  (with-temp-buffer
    (insert "it('another test', function() {});"
            "describe('someFunction()', () => {"
            "  it('does as expected', async () => {"
            "  });"
            "});")
    (search-backward "does as expected")
    (js-mode)
    (tree-sitter-mode)
    (should (string= (mocha-find-current-test) "someFunction() does as expected"))))

(ert-deftest mocha-test/mocha-find-current-test/js+NO-tree-sitter ()
  (with-temp-buffer
    (insert "it('does as expected', function() {")
    (save-excursion (insert "})"))
    (js-mode)
    (should-error (mocha-find-current-test))))

(ert-deftest mocha-test/mocha-find-current-test/custom-test-definition-nodes ()
  (with-temp-buffer
    (insert "test('that it does as expected', 'test.json'")
    (save-excursion (insert ");"))
    (js-mode)
    (tree-sitter-mode)
    (make-local-variable 'mocha-test-definition-nodes)
    (push "test" mocha-test-definition-nodes)
    (should (string= (mocha-find-current-test) "that it does as expected"))))


;;;; mocha-run

(ert-deftest mocha-test/mocha-run/buffer-local-compilation-env ()
  (with-temp-buffer
    (make-local-variable 'compilation-environment)
    (setq compilation-environment '("TEST=abc"))
    (let ((command (if (memq system-type '(windows-nt ms-dos))
                       "echo %TEST%"
                     "echo $TEST")))
      (mocha-dynamic-flet ((mocha-generate-command (debug &optional mocha-file test) command)
                           (mocha-find-project-root () ".")
                           (cd (dir) ".")
                           ;; In 24.x, (fboundp 'start-process)
                           ;; determines whether async compilation can
                           ;; run. In 25.x, it's (fboundp 'make-process)
                           (start-process) (make-process))
                          (mocha-run))
      (with-current-buffer "*mocha tests*"
        (goto-char 0)
        (should (search-forward (concat "\n" command "\n") nil t))
        (should (looking-at-p "abc"))))))

(ert-deftest mocha-test/node-error-regexp/windows-path-with-drive ()
  (let ((line
         "    at Timeout.callback [as _onTimeout] (C:\\Users\\name\\node_modules\\jsdom\\lib\\jsdom\\browser\\Window.js:477:19)"))
    (should (string-match node-error-regexp line))
    ;; 1 is file, 2 is line, 3 is column
    (should (string= (match-string (nth 1 (car node-error-regexp-alist)) line)
                     "C:\\Users\\name\\node_modules\\jsdom\\lib\\jsdom\\browser\\Window.js"))
    (should (string= (match-string (nth 2 (car node-error-regexp-alist)) line) "477"))
    (should (string= (match-string (nth 3 (car node-error-regexp-alist)) line) "19"))))


;;;; imenu integration

(ert-deftest mocha-test/make-imenu-alist ()
  (with-temp-buffer
    (insert "
describe('something', function() {
  beforeEach(() => console.log('sometihng'));
  it(\"does something\", () => {});
  describe(\"on the inside\", function() {
    beforeAll(setupFunction);
    afterEach(partialReset);
    it(\"does some more, but not tested\");
    features.forEach(feat => {
        it(\"feature test: \" + feat, () => {
          // ...
        })
    });
    afterAll(totalReset);
  });
});

describe(\"another top-level\", () => {});
afterAll(() => {});")
    (js-mode)
    (require 'mocha)
    (let (imenu-max-item-length)
      (should (equal
               (mocha-make-imenu-alist)
               '(("describe something" .
                  (("*declaration*" . 2)
                   ("beforeEach" . 39)
                   ("it does something" . 85)
                   ("describe on the inside" .
                    (("*declaration*" . 119)
                     ("beforeAll" . 162)
                     ("afterEach" . 192)
                     ("it does some more, but not tested" . 221)
                     ("it \"feature test: \" + feat" . 298)
                     ("afterAll" . 374)))))
                 ("describe another top-level" .
                  (("*declaration*" . 407)))
                 ("afterAll" . 448)))))))

(ert-deftest mocha-test/toggle-imenu-function ()
  (with-temp-buffer
    (insert "function setUp() {}\ndescribe(\"top-level\", () => {it('works');});")
    (js-mode)
    (let ((prev (imenu--make-index-alist)))
      (mocha-toggle-imenu-function)
      (should (equal (imenu--make-index-alist)
                     '(("*Rescan*" . -99)
                       ("describe top-level"
                        ("*declaration*" . 21)
                        ("it works" . 50)))))
      (mocha-toggle-imenu-function)
      (should (equal (imenu--make-index-alist) prev)))))

(ert-deftest mocha-test/imenu-custom-test-definition-nodes ()
  (with-temp-buffer
    (insert "function setUp() {}\ndescribe(\"top-level\", () => {test('that it works', 'test.json');});")
    (js-mode)
    (make-local-variable 'mocha-test-definition-nodes)
    (make-local-variable 'mocha-imenu-functions)
    (push "test" mocha-test-definition-nodes)
    (push "test" mocha-imenu-functions)
    (mocha-toggle-imenu-function)
    (should (equal (imenu--make-index-alist)
                   '(("*Rescan*" . -99)
                     ("describe top-level"
                      ("*declaration*" . 21)
                      ("test that it works" . 50)))))))


;;;; mocha-debug

(ert-deftest mocha-test/mocha-debug/errors-if-debugger-is-unknown ()
  (let* ((mocha-debugger 'unknown-debugger)
         (err (should-error (mocha-debug))))
    (should (string-match-p "unknown-debugger" (cadr err)))))

(ert-deftest mocha-test/mocha-debug/errors-if-debugger-is-unbound ()
  (mocha-dynamic-flet ((realgud:nodejs) (indium-connect-to-nodejs))
                      (let* ((mocha-debugger 'realgud)
                             (err (should-error (mocha-debug) :type 'user-error)))
                        (should (string-match-p "realgud" (cadr err))))
                      (let* ((mocha-debugger 'indium)
                             (err (should-error (mocha-debug) :type 'user-error)))
                        (should (string-match-p "indium" (cadr err))))))

(ert-deftest mocha-test/mocha-debug/realgud-debugger ()
  (let ((addr "fc0b9f1a-0113-4368-a370-ff1a888ae6bb")
        (mocha-debugger 'realgud)
        realgud-calls)
    (mocha-dynamic-flet ((mocha-generate-command
                          (debug &optional mocha-file test)
                          (concat "echo 'Debugger listening on ws://127.0.0.1:"
                                  mocha-debug-port "/" addr "'"))
                         (mocha-find-project-root () ".")
                         (cd (dir) ".")
                         (realgud:nodejs (&rest args) (push args realgud-calls)))
                        (mocha-debug))
    (should (equal realgud-calls (list (list (concat mocha-which-node " debug localhost:"
                                                     mocha-debug-port)))))))

(ert-deftest mocha-test/mocha-debug/indium-debugger ()
  (let ((addr "fc0b9f1a-0113-4368-a370-ff1a888ae6bb")
        (mocha-debugger 'indium)
        indium-calls)
    (mocha-dynamic-flet ((mocha-generate-command
                          (debug &optional mocha-file test)
                          (concat "echo 'Debugger listening on ws://127.0.0.1:"
                                  mocha-debug-port "/" addr "'"))
                         (mocha-find-project-root () ".")
                         (cd (dir) ".")
                         (indium-connect-to-nodejs (&rest args) (push args indium-calls)))
                        (mocha-debug))
    (should (equal indium-calls (list (list "127.0.0.1" mocha-debug-port addr))))))
