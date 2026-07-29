(defun c:GetNode ( / ent pt param vertParam coords idx ptCoord clipboard-put textToCopy entName obj)
  (vl-load-com)
  
  ;; Hàm hỗ trợ copy text vào Clipboard
  (defun clipboard-put (str / html result)
    (setq html (vlax-create-object "htmlfile"))
    (vlax-invoke (vlax-get (vlax-get html 'ParentWindow) 'ClipboardData) 'SetData "Text" str)
    (vlax-release-object html)
  )

  (princ "\n--- Bắt đầu lấy tọa độ liên tục (Nhấn ENTER, SPACE hoặc ESC để DỪNG) ---")
  
  ;; Vòng lặp while giúp chọn liên tục cho đến khi người dùng hủy/nhấn Enter trống
  (while (setq ent (entsel "\nChọn một đỉnh (node) trên Polyline: "))
    (setq pt (cadr ent)) ; Tọa độ điểm click chuột
    (setq entName (car ent)) ; Tên đối tượng được chọn
    
    ;; Kiểm tra đối tượng có phải là Polyline không
    (if (wcmatch (cdr (assoc 0 (entget entName))) "*POLYLINE")
      (progn
        ;; Chuyển đối tượng sang dạng VLA-Object
        (setq obj (vlax-ename->vla-object entName))
        
        ;; Tìm tham số (parameter) gần nhất với điểm click chuột
        (setq param (vlax-curve-getParamAtPoint obj (vlax-curve-getClosestPointTo obj pt)))
        
        ;; Làm tròn tham số để xác định chính xác chỉ số của đỉnh
        (setq vertParam (fix (+ param 0.5)))
        
        ;; Lấy tọa độ của đỉnh đó
        (setq ptCoord (vlax-curve-getPointAtParam obj vertParam))
        
        ;; Định dạng chuỗi tọa độ (X, Y, Z)
        (setq textToCopy (strcat (rtos (car ptCoord) 2 4) "," (rtos (cadr ptCoord) 2 4)))
        
        ;; Nếu là 3D Polyline thì lấy thêm tọa độ Z
        (if (caddr ptCoord)
          (setq textToCopy (strcat textToCopy "," (rtos (caddr ptCoord) 2 4)))
        )
        
        ;; Sao chép vào Clipboard và in ra màn hình
        (clipboard-put textToCopy)
        (princ (strcat "\n==> Tọa độ đỉnh đã chọn: " textToCopy " (Đã copy!)"))
      )
      (princ "\n[Lỗi] Đối tượng bạn chọn không phải là Polyline! Hãy chọn lại.")
    )
  )
  
  (princ "\n--- Đã kết thúc lệnh lấy tọa độ. ---")
  (princ)
)

(princ "\nGõ lệnh GETNODE để bắt đầu lấy tọa độ liên tục.")
(princ)