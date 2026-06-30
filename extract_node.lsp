(defun c:XuatMangLuoi ( / ss i ent plist total j pt1 pt2 nodes extList nodeCount node nodeStr checkPt ptA ptB)
  (vl-load-com)
  (princ "\nQuet chon cac duong Polyline giao nhau: ")
  ;; Chi chon cac doi tuong la Polyline
  (setq ss (ssget '((0 . "*POLYLINE"))))
  (if ss
    (progn
      (setq extList nil)
      (setq i (sslength ss))
      
      ;; BUOC 1: Thu thap tat ca cac doan va toa do (dang So Thuc)
      (while (> i 0)
        (setq i (1- i))
        (setq ent (vlax-ename->vla-object (ssname ss i)))
        (setq plist (vlax-safearray->list (vlax-variant-value (vla-get-Coordinates ent))))
        (setq total (/ (length plist) 2))
        (setq j 0)
        (while (< j (1- total))
          ;; Lay toa do dang so thuc, lam tron den 2 chu so thap phan de tranh sai so hinh hoc
          (setq pt1 (list (rtos (nth (* j 2) plist) 2 2) (rtos (nth (+ (* j 2) 1) plist) 2 2)))
          (setq pt2 (list (rtos (nth (* (+ j 1) 2) plist) 2 2) (rtos (nth (+ (* (+ j 1) 2) 1) plist) 2 2)))
          ;; Luu vao danh sach cac canh ket noi
          (setq extList (cons (list pt1 pt2) extList))
          (setq j (1+ j))
        )
      )
      
      ;; BUOC 2: Trich xuat danh sach cac Node duy nhat
      (setq nodes nil)
      (foreach line extList
        (setq ptA (car line)
              ptB (cadr line))
        (if (not (member ptA nodes)) (setq nodes (cons ptA nodes)))
        (if (not (member ptB nodes)) (setq nodes (cons ptB nodes)))
      )
      
      ;; BUOC 3: In ket qua Topo phan tich mang luoi
      (princ "\n========================================================")
      (princ "\n   KET QUA PHAN TICH NUT GIAO MANG LUOI (TOPOLOGY)")
      (princ "\n========================================================")
      
      (setq nodeCount 1)
      (foreach node nodes
        (princ (strcat "\n[Node " (itoa nodeCount) "] tai toa do (" (car node) ", " (cadr node) ") ket noi voi:"))
        
        ;; Duyet lai danh sach canh de tim cac node hang xom
        (foreach line extList
          (setq ptA (car line)
                ptB (cadr line))
          (cond
            ;; Neu trung voi diem dau, thi no ket noi voi diem cuoi
            ((equal node ptA)
             (princ (strcat "\n   -> Den Node co toa do (" (car ptB) ", " (cadr ptB) ")")))
            ;; Neu trung voi diem cuoi, thi no ket noi voi diem dau
            ((equal node ptB)
             (princ (strcat "\n   -> Den Node co toa do (" (car ptA) ", " (cadr ptA) ")")))
          )
        )
        (setq nodeCount (1+ nodeCount))
        (princ "\n--------------------------------------------------------")
      )
    )
    (princ "\nKhong chon duoc Polyline nao!")
  )
  (princ)
)