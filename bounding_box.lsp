(defun c:GETBBOX ( / ss minpt maxpt globalMin globalMax i obj errCheck)
  (vl-load-com) ; Kích hoạt thư viện ActiveX để dùng vla-
  
  ;; Chỉ quét các đối tượng thuộc Model Space để tránh lấy nhầm khung Layout
  (setq ss (ssget "X" '((410 . "Model"))))
  
  (if ss
    (progn
      ;; Khởi tạo giá trị ban đầu cho hệ tọa độ cực hạn
      (setq globalMin (list 1e9 1e9)
            globalMax (list -1e9 -1e9))
      
      (setq i 0)
      (while (< i (sslength ss))
        (setq obj (vlax-ename->vla-object (ssname ss i)))
        
        ;; Bẫy lỗi: Nếu đối tượng không lấy được Bounding Box thì bỏ qua, không bị crash
        (setq errCheck (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'minpt 'maxpt)))
        
        (if (not (vl-catch-all-error-p errCheck))
          (progn
            (setq minpt (vlax-safearray->list minpt))
            (setq maxpt (vlax-safearray->list maxpt))
            
            ;; Tìm Min nhỏ nhất và Max lớn nhất thực sự bằng hàm min/max
            (setq globalMin (list (min (car globalMin) (car minpt))
                                  (min (cadr globalMin) (cadr minpt))))
            (setq globalMax (list (max (car globalMax) (car maxpt))
                                  (max (cadr globalMax) (cadr maxpt))))
          )
        )
        (setq i (1+ i))
      )
      
      ;; Hiển thị kết quả chuẩn xác
      (textscr)
      (princ "\n========== BOUNDING BOX THỰC TẾ ==========")
      (princ (strcat "\nMin X (Xmin): " (rtos (car globalMin) 2 4)))
      (princ (strcat "\nMin Y (Ymin): " (rtos (cadr globalMin) 2 4)))
      (princ (strcat "\nMax X (Xmax): " (rtos (car globalMax) 2 4)))
      (princ (strcat "\nMax Y (Ymax): " (rtos (cadr globalMax) 2 4)))
      (princ (strcat "\n------------------------------------------"))
      (princ (strcat "\nWidth (CAD):  " (rtos (- (car globalMax) (car globalMin)) 2 4)))
      (princ (strcat "\nHeight (CAD): " (rtos (- (cadr globalMax) (cadr globalMin)) 2 4)))
      (princ "\n==========================================")
    )
    (princ "\nKhong co object nao trong Model Space!")
  )
  (princ)
)