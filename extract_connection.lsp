;; ============================================================
;; XuatMangLuoi.lsp
;; Quet cac Polyline giao nhau, xuat topology mang luoi (undirected graph)
;; Fix: tolerance-based point comparison, dedupe edge/neighbor,
;;      canh bao self-loop, xuat kem code Dart connect()
;; ============================================================

;; Nguong sai so hinh hoc (don vi ban ve). Tang/giam tuy theo scale CAD.
(setq *PT-TOL* 0.4)

;; So sanh 2 diem theo tolerance thay vi so sanh string lam tron
(defun pt-equal (p1 p2 / tol)
  (setq tol *PT-TOL*)
  (and (< (abs (- (car p1) (car p2))) tol)
       (< (abs (- (cadr p1) (cadr p2))) tol))
)

;; Tim vi tri (index) cua 1 diem trong danh sach nodes theo tolerance
;; Tra ve index (0-based) hoac nil neu khong tim thay
(defun pt-index (pt nodeList / i found n)
  (setq i 0 found nil)
  (while (and (< i (length nodeList)) (not found))
    (setq n (nth i nodeList))
    (if (pt-equal pt n) (setq found i))
    (setq i (1+ i))
  )
  found
)

;; Format 1 diem ra string de in, dung rtos rieng cho hien thi (khong dung de so sanh)
(defun pt-str (pt)
  (strcat "(" (rtos (car pt) 2 2) ", " (rtos (cadr pt) 2 2) ")")
)

(defun c:ExtractConnection ( / ss i ent plist total j pt1 pt2 nodes extList
                          nodeCount node nodeStr idxA idxB pairKey
                          printedPairs neighborIdxList nbIdx nbNode
                          edgeKey edgeSet)
  (vl-load-com)
  (princ "\nQuet chon cac duong Polyline giao nhau: ")
  ;; Chi chon cac doi tuong la Polyline
  (setq ss (ssget '((0 . "*POLYLINE"))))
  (if ss
    (progn
      (setq extList nil)
      (setq nodes nil)
      (setq i (sslength ss))

      ;; ============================================================
      ;; BUOC 1: Thu thap tat ca cac doan (dang toa do so thuc, KHONG
      ;; convert sang string o buoc nay de tranh mat do chinh xac)
      ;; ============================================================
      (while (> i 0)
        (setq i (1- i))
        (setq ent (vlax-ename->vla-object (ssname ss i)))
        (setq plist (vlax-safearray->list (vlax-variant-value (vla-get-Coordinates ent))))
        (setq total (/ (length plist) 2))
        (setq j 0)
        (while (< j (1- total))
          (setq pt1 (list (nth (* j 2) plist) (nth (+ (* j 2) 1) plist)))
          (setq pt2 (list (nth (* (+ j 1) 2) plist) (nth (+ (* (+ j 1) 2) 1) plist)))

          ;; Canh bao neu polyline co doan trung diem (self-loop)
          (if (pt-equal pt1 pt2)
            (princ (strcat "\n[CANH BAO] Polyline co doan trung diem tai "
                            (pt-str pt1) " - bo qua doan nay."))
            (setq extList (cons (list pt1 pt2) extList))
          )
          (setq j (1+ j))
        )
      )

      ;; ============================================================
      ;; BUOC 2: Trich xuat danh sach Node duy nhat (theo tolerance,
      ;; khong theo string) -> tranh gop nham hoac tach nham node
      ;; ============================================================
      (foreach line extList
        (setq pt1 (car line) pt2 (cadr line))
        (if (not (pt-index pt1 nodes)) (setq nodes (cons pt1 nodes)))
        (if (not (pt-index pt2 nodes)) (setq nodes (cons pt2 nodes)))
      )
      (setq nodes (reverse nodes)) ;; giu thu tu phat hien, index 0-based on dinh

      ;; ============================================================
      ;; BUOC 3: Dedupe edge -> tap hop cac cap (idxA,idxB) duy nhat
      ;; (khong phan biet thu tu A-B hay B-A)
      ;; ============================================================
      (setq edgeSet nil)
      (foreach line extList
        (setq pt1 (car line) pt2 (cadr line))
        (setq idxA (pt-index pt1 nodes))
        (setq idxB (pt-index pt2 nodes))
        (if (and idxA idxB (/= idxA idxB))
          (progn
            (setq edgeKey (list (min idxA idxB) (max idxA idxB)))
            (if (not (member edgeKey edgeSet))
              (setq edgeSet (cons edgeKey edgeSet))
            )
          )
        )
      )
      (setq edgeSet (reverse edgeSet))

      ;; ============================================================
      ;; BUOC 4: In ket qua Topology - moi node va danh sach neighbor
      ;; (da dedupe, doi xung tu dong vi edgeSet la vo huong)
      ;; ============================================================
      (princ "\n========================================================")
      (princ "\n   KET QUA PHAN TICH NUT GIAO MANG LUOI (TOPOLOGY)")
      (princ (strcat "\n   Tong so Node: " (itoa (length nodes))))
      (princ (strcat "\n   Tong so Edge (da dedupe): " (itoa (length edgeSet))))
      (princ "\n========================================================")

      (setq nodeCount 0)
      (foreach node nodes
        (princ (strcat "\n[Node " (itoa (1+ nodeCount)) "] tai toa do "
                        (pt-str node) " ket noi voi:"))

        (setq neighborIdxList nil)
        (foreach edge edgeSet
          (setq idxA (car edge) idxB (cadr edge))
          (cond
            ((= idxA nodeCount) (setq neighborIdxList (cons idxB neighborIdxList)))
            ((= idxB nodeCount) (setq neighborIdxList (cons idxA neighborIdxList)))
          )
        )
        (setq neighborIdxList (reverse neighborIdxList))

        (if (null neighborIdxList)
          (princ "\n   [CANH BAO] Node nay khong co ket noi nao (isolated node)!")
          (foreach nbIdx neighborIdxList
            (setq nbNode (nth nbIdx nodes))
            (princ (strcat "\n   -> Node " (itoa (1+ nbIdx)) " tai " (pt-str nbNode)))
          )
        )

        (setq nodeCount (1+ nodeCount))
        (princ "\n--------------------------------------------------------")
      )

      ;; ============================================================
      ;; BUOC 5: Xuat kem code Dart connect() de paste truc tiep
      ;; vao buildGraphEdges(). ID node = so thu tu (1-based), giong
      ;; cach danh so 'id' trong PathNode cua ban.
      ;; ============================================================
      (princ "\n\n========================================================")
      (princ "\n   CODE DART - PASTE VAO buildGraphEdges()")
      (princ "\n========================================================")
      (foreach edge edgeSet
        (setq idxA (car edge) idxB (cadr edge))
        (princ (strcat "\n  connect('" (itoa (1+ idxA)) "', '" (itoa (1+ idxB)) "');"))
      )

      (princ "\n")
    )
    (princ "\nKhong chon duoc Polyline nao!")
  )
  (princ)
)

(princ "\nLisp XuatMangLuoi da nap xong. Go lenh: XuatMangLuoi")
(princ)