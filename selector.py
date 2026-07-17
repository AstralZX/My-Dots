import sys
import os
import subprocess
from PyQt6.QtWidgets import (QApplication, QWidget, QScrollArea, QFrame,
                             QLabel, QGraphicsBlurEffect)
from PyQt6.QtCore import (Qt, pyqtSignal, QPropertyAnimation, QRectF,
                          QTimer, QEasingCurve, pyqtProperty)
from PyQt6.QtGui import QPixmap, QPainter, QPainterPath

# --- CONSTANTES ---
WALLPAPER_DIR = os.path.expanduser("~/Pictures")
MPVPAPER_PID_FILE = os.path.expanduser("/tmp/mpvpaper.pid")

# Extensiones soportadas (Tanto imágenes estáticas como videos)
VALID_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.mp4', '.mkv', '.webm')
VIDEO_EXTENSIONS = ('.mp4', '.mkv', '.webm')

# --- MPVPAPER: CAMBIAR WALLPAPER ---

def kill_mpvpaper():
    """Mata el proceso mpvpaper actual de manera limpia"""
    try:
        if os.path.exists(MPVPAPER_PID_FILE):
            with open(MPVPAPER_PID_FILE, "r") as f:
                pid = int(f.read().strip())
                subprocess.run(["kill", str(pid)], capture_output=True)
            os.remove(MPVPAPER_PID_FILE)
    except:
        pass
    subprocess.run(["pkill", "mpvpaper"], capture_output=True)

def set_mpvpaper_wallpaper(file_path):
    """Cambia el wallpaper (estático o dinámico) usando mpvpaper"""
    kill_mpvpaper()
    
    # Pasamos las opciones de mpv de forma segura
    cmd = ["mpvpaper", "-o", "no-audio --loop-playlist", "ALL", file_path]
    
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with open(MPVPAPER_PID_FILE, "w") as f:
        f.write(str(proc.pid))

# --- INTERFAZ GRAFICA ---

class RoundedImage(QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.radius = 22
        
    def setPixmap(self, pixmap):
        if not pixmap: return
        size = self.size()
        rounded = QPixmap(size)
        rounded.fill(Qt.GlobalColor.transparent)
        p = QPainter(rounded)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        path = QPainterPath()
        path.addRoundedRect(QRectF(0, 0, size.width(), size.height()), self.radius, self.radius)
        p.setClipPath(path)
        sc = pixmap.scaled(size, Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                           Qt.TransformationMode.SmoothTransformation)
        p.drawPixmap((size.width()-sc.width())//2, (size.height()-sc.height())//2, sc)
        p.end()
        super().setPixmap(rounded)

class WallpaperItem(QFrame):
    clicked = pyqtSignal(str)
    def __init__(self, path, parent=None):
        super().__init__(parent)
        self.path = path
        self.setFixedSize(310, 220)
        self.img_label = RoundedImage(self)
        self.img_label.setGeometry(10, 10, 290, 200)
        self.blur_effect = QGraphicsBlurEffect(self)
        self.img_label.setGraphicsEffect(self.blur_effect)
        
    def set_blur(self, r): self.blur_effect.setBlurRadius(min(r, 10))
    def mousePressEvent(self, e): self.clicked.emit(self.path)

class WallpaperCarousel(QWidget):
    def __init__(self):
        super().__init__()
        self.wallpaper_dir = WALLPAPER_DIR
        self.thumb_dir = os.path.join(self.wallpaper_dir, '.thumbnails')

        # Cargar archivos multimedia válidos
        self.base_wps = sorted([
            os.path.join(self.wallpaper_dir, f)
            for f in os.listdir(self.wallpaper_dir)
            if f.lower().endswith(VALID_EXTENSIONS)
        ])
        
        # FIX: Duplicar dinámicamente si tienes pocas imágenes para que no se rompa el scroll
        self.display_multiplier = 3
        if len(self.base_wps) == 1:
            self.display_multiplier = 12
        elif len(self.base_wps) == 2:
            self.display_multiplier = 6
        elif len(self.base_wps) == 3:
            self.display_multiplier = 4

        self.items = []
        self._bg_opacity = 70
        self.initUI()

        QTimer.singleShot(10, self.reset_to_center)
        self.blur_timer = QTimer()
        self.blur_timer.timeout.connect(self.update_logic)
        self.blur_timer.start(16)
        self.current_velocity = 0

    @pyqtProperty(int)
    def bg_opacity(self): return self._bg_opacity
    @bg_opacity.setter
    def bg_opacity(self, v):
        self._bg_opacity = v
        self.bg_panel.setStyleSheet(
            f"background-color: rgba(10, 10, 10, {v}); border-radius: 40px; "
            f"border: 1px solid rgba(255, 255, 255, 15);")

    def initUI(self):
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFixedSize(1200, 520)

        self.bg_panel = QFrame(self)
        self.bg_panel.setGeometry(50, 50, 1100, 380)
        self.bg_panel.setStyleSheet(
            "background-color: rgba(10, 10, 10, 70); "
            "border-radius: 40px; "
            "border: 1px solid rgba(255, 255, 255, 15);"
        )

        self.scroll = QScrollArea(self)
        self.scroll.setGeometry(70, 70, 1060, 280)
        self.scroll.setWidgetResizable(False)
        self.scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self.container = QWidget()
        self.container.setFixedHeight(280)
        
        total_items = len(self.base_wps * self.display_multiplier)
        self.container.setFixedWidth(total_items * 350 + 200)

        x = 20
        for wp in self.base_wps * self.display_multiplier:
            item = WallpaperItem(wp, self.container)
            item.move(x, 30)
            item.img_label.setPixmap(QPixmap(self.get_thumbnail(wp)))
            item.clicked.connect(self.switch_wallpaper)
            self.items.append(item)
            x += 350
        self.scroll.setWidget(self.container)
        self.anim_scroll = QPropertyAnimation(self.scroll.horizontalScrollBar(), b"value")

    def get_thumbnail(self, file_path):
        """Genera miniaturas estáticas tanto para imágenes normales como fotogramas de video"""
        vn = os.path.basename(file_path)
        tp = os.path.join(self.thumb_dir, vn + ".thumb.jpg")
        
        if not os.path.exists(tp):
            if not os.path.exists(self.thumb_dir): 
                os.makedirs(self.thumb_dir)
            
            if file_path.lower().endswith(VIDEO_EXTENSIONS):
                subprocess.run(['ffmpeg', '-ss', '00:00:02', '-i', file_path, 
                                '-vf', 'scale=300:-1', '-vframes', '1', tp, '-y'], 
                                capture_output=True)
            else:
                try:
                    from PIL import Image
                    img = Image.open(file_path)
                    img.thumbnail((300, 200))
                    img.save(tp, "JPEG", quality=85)
                except:
                    subprocess.run(['ffmpeg', '-i', file_path, '-vf', 'scale=300:-1',
                                  tp, '-y'], capture_output=True)
        return tp

    def switch_wallpaper(self, target):
        """Cambia el fondo de pantalla con mpvpaper y cierra la ventana"""
        set_mpvpaper_wallpaper(target)
        self.close()

    def reset_to_center(self):
        if self.base_wps: 
            center_factor = self.display_multiplier // 3
            self.scroll.horizontalScrollBar().setValue(len(self.base_wps) * center_factor * 350)

    def wheelEvent(self, e):
        self.anim_scroll.stop()
        delta = e.angleDelta().y()
        self.current_velocity += abs(delta)/10
        self.anim_scroll.setDuration(700)
        self.anim_scroll.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.anim_scroll.setEndValue(self.scroll.horizontalScrollBar().value() - (delta*5))
        self.anim_scroll.start()

    def update_logic(self):
        self.current_velocity *= 0.9
        for i in self.items: i.set_blur(self.current_velocity)
        
        v = self.scroll.horizontalScrollBar().value()
        lim = len(self.base_wps) * 350
        
        if lim > 0:
            if v >= lim * (self.display_multiplier - 2): 
                self.scroll.horizontalScrollBar().setValue(v - lim)
            elif v <= 350: 
                self.scroll.horizontalScrollBar().setValue(v + lim)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key.Key_Escape: self.close()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = WallpaperCarousel()
    ex.show()
    sys.exit(app.exec())
