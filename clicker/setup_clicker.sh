#!/bin/bash
# AgentEther Desktop Clicker - Skrypt instalacyjny
# Użycie: bash setup_clicker.sh
# Działa na Ubuntu/Debian/Mint

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/agentether-clicker"
DESKTOP_DIR="$HOME/.local/share/applications"
BIN_DIR="$HOME/.local/bin"

echo "======================================"
echo "  AgentEther Auto-Clicker Installer"
echo "======================================"

# 1. Sprawdź Python
if ! command -v python3 &>/dev/null; then
    echo "[!] Python3 nie znaleziony. Instaluję..."
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi
echo "[OK] Python3: $(python3 --version)"

# 2. Zainstaluj zależności systemowe (X11 dla pyautogui)
echo "[*] Instaluję zależności systemowe..."
sudo apt-get install -y --no-install-recommends \
    python3-pip \
    python3-tk \
    python3-dev \
    scrot \
    xdotool \
    libxtst-dev \
    2>/dev/null || echo "[!] Niektóre pakiety systemowe mogą być pominięte"

# 3. Zainstaluj biblioteki Python
echo "[*] Instaluję biblioteki Python..."
pip3 install --user pyautogui keyboard 2>/dev/null || \
    python3 -m pip install --user pyautogui keyboard

# 4. Skopiuj pliki do katalogu instalacji
echo "[*] Kopiuję pliki..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/clicker.py" "$INSTALL_DIR/clicker.py"
chmod +x "$INSTALL_DIR/clicker.py"

# 5. Utwórz skrypt startowy w PATH
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/agentether-clicker" << EOF
#!/bin/bash
# Wrapper startowy dla AgentEther Auto-Clicker
python3 "$INSTALL_DIR/clicker.py" "\$@"
EOF
chmod +x "$BIN_DIR/agentether-clicker"

# 6. Dodaj do PATH jeśli potrzeba
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$HOME/.bashrc"
    echo "[*] Dodano $BIN_DIR do PATH w ~/.bashrc"
fi

# 7. Utwórz plik .desktop
mkdir -p "$DESKTOP_DIR"
ICON_PATH="$INSTALL_DIR/icon.png"

# Pobierz/utwórz ikonę (fallback: systemowa ikona)
if command -v convert &>/dev/null; then
    convert -size 64x64 xc:'#1a1a2e' \
        -fill '#e94560' -draw 'circle 32,32 32,10' \
        -fill white -pointsize 20 -gravity center -annotate 0 'AC' \
        "$ICON_PATH" 2>/dev/null || ICON_PATH="input-mouse"
else
    ICON_PATH="input-mouse"
fi

cat > "$DESKTOP_DIR/agentether-clicker.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AgentEther Auto-Clicker
Comment=Automatyczny klikacz dla pulpitu
Exec=bash -c 'python3 $INSTALL_DIR/clicker.py --hotkeys; read'
Icon=$ICON_PATH
Terminal=true
Categories=Utility;
Keywords=clicker;auto;klikacz;
StartupNotify=true
EOF

chmod +x "$DESKTOP_DIR/agentether-clicker.desktop"
echo "[OK] Plik .desktop utworzony: $DESKTOP_DIR/agentether-clicker.desktop"

# 8. Odśwież bazę aplikacji pulpitu
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo ""
echo "======================================"
echo "  Instalacja zakończona pomyślnie!"
echo "======================================"
echo ""
echo "Uruchomienie:"
echo "  z terminala:  agentether-clicker"
echo "  z pulpitu:    szukaj 'AgentEther Auto-Clicker' w menu aplikacji"
echo ""
echo "Opcje:"
echo "  agentether-clicker -i 0.5          # klikaj co 0.5s"
echo "  agentether-clicker -x 500 -y 300   # klikaj na pozycji x=500,y=300"
echo "  agentether-clicker --hotkeys        # F5=start, F6=stop"
echo "  agentether-clicker --help           # pełna pomoc"
echo ""
