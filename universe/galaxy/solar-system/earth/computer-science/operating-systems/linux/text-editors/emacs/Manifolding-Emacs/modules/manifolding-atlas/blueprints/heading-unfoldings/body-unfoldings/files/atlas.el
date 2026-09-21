;;; templates/files/atlas.el -*- lexical-binding: t; -*-

(defvar my/capture-manifolding-atlas
  (doct
   `(("Manifolding Atlas"
      :keys "n"
      :children
      (("New note" :keys "n"
        :type plain
        :function (lambda () (my/manifolding-atlas-capture-new-file))
        :unnarrowed t)
       ("Task" :keys "t"
        :type plain
        :function (lambda () (my/manifolding-atlas-capture-task-file))
        :unnarrowed t)
       ("Heading" :keys "h"
        :type plain
        :function (lambda () (my/manifolding-atlas-capture-heading))
        :unnarrowed t))))))
