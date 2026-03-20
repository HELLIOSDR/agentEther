#!/usr/bin/env python3
"""
AgentEther Desktop Auto-Clicker
Prosty auto-klikacz dla pulpitu Linux/X11
"""

import sys
import time
import threading
import argparse
from datetime import datetime

try:
    import pyautogui
    import keyboard
except ImportError:
    print("Brak wymaganych bibliotek. Uruchom: pip install pyautogui keyboard")
    sys.exit(1)

# Konfiguracja domyślna
DEFAULT_INTERVAL = 1.0    # sekundy między kliknięciami
DEFAULT_BUTTON = "left"   # lewy przycisk myszy
STOP_KEY = "F6"           # klawisz zatrzymania
START_KEY = "F5"          # klawisz startu

pyautogui.FAILSAFE = True  # ruch myszą do rogu ekranu = stop


class AutoClicker:
    def __init__(self, interval=DEFAULT_INTERVAL, button=DEFAULT_BUTTON,
                 x=None, y=None, max_clicks=0):
        self.interval = interval
        self.button = button
        self.x = x
        self.y = y
        self.max_clicks = max_clicks  # 0 = bez limitu
        self.running = False
        self.click_count = 0
        self._thread = None

    def _click_loop(self):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Klikanie startuje... (zatrzymaj: {STOP_KEY})")
        while self.running:
            if self.x is not None and self.y is not None:
                pyautogui.click(self.x, self.y, button=self.button)
            else:
                pyautogui.click(button=self.button)

            self.click_count += 1
            print(f"  Klik #{self.click_count}", end="\r")

            if self.max_clicks > 0 and self.click_count >= self.max_clicks:
                print(f"\nOsiągnięto limit {self.max_clicks} kliknięć.")
                self.stop()
                break

            time.sleep(self.interval)

    def start(self):
        if self.running:
            print("Klikacz już działa!")
            return
        self.running = True
        self.click_count = 0
        self._thread = threading.Thread(target=self._click_loop, daemon=True)
        self._thread.start()

    def stop(self):
        self.running = False
        if self._thread:
            self._thread.join(timeout=2)
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Zatrzymano. Łącznie kliknięć: {self.click_count}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="AgentEther Auto-Clicker",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Przykłady użycia:
  python3 clicker.py                          # klikaj co 1s w bieżącej pozycji
  python3 clicker.py -i 0.5                  # klikaj co 0.5s
  python3 clicker.py -x 500 -y 300           # klikaj na pozycji x=500, y=300
  python3 clicker.py -i 2 -b right           # prawy przycisk co 2s
  python3 clicker.py -n 100                  # dokładnie 100 kliknięć
  python3 clicker.py --hotkeys               # tryb z klawiszami F5/F6
        """
    )
    parser.add_argument("-i", "--interval", type=float, default=DEFAULT_INTERVAL,
                        help=f"Interwał między kliknięciami w sekundach (domyślnie: {DEFAULT_INTERVAL})")
    parser.add_argument("-b", "--button", choices=["left", "right", "middle"],
                        default=DEFAULT_BUTTON,
                        help=f"Przycisk myszy (domyślnie: {DEFAULT_BUTTON})")
    parser.add_argument("-x", type=int, default=None,
                        help="Pozycja X na ekranie (domyślnie: bieżąca pozycja)")
    parser.add_argument("-y", type=int, default=None,
                        help="Pozycja Y na ekranie (domyślnie: bieżąca pozycja)")
    parser.add_argument("-n", "--max-clicks", type=int, default=0,
                        help="Maksymalna liczba kliknięć (0 = bez limitu)")
    parser.add_argument("--hotkeys", action="store_true",
                        help=f"Tryb hotkeys: {START_KEY}=start, {STOP_KEY}=stop")
    parser.add_argument("--delay", type=float, default=3.0,
                        help="Opóźnienie przed startem w sekundach (domyślnie: 3)")
    return parser.parse_args()


def main():
    args = parse_args()

    print("=" * 50)
    print("  AgentEther Auto-Clicker")
    print("=" * 50)
    print(f"  Interwał:  {args.interval}s")
    print(f"  Przycisk:  {args.button}")
    if args.x and args.y:
        print(f"  Pozycja:   x={args.x}, y={args.y}")
    else:
        print("  Pozycja:   bieżąca pozycja kursora")
    if args.max_clicks:
        print(f"  Limit:     {args.max_clicks} kliknięć")
    print(f"  FAILSAFE:  przesuń mysz do rogu ekranu = awaryjne zatrzymanie")
    print("=" * 50)

    clicker = AutoClicker(
        interval=args.interval,
        button=args.button,
        x=args.x,
        y=args.y,
        max_clicks=args.max_clicks
    )

    if args.hotkeys:
        print(f"\nTryb hotkeys: {START_KEY} = start, {STOP_KEY} = stop")
        print("Oczekiwanie na naciśnięcie klawisza...\n")

        keyboard.add_hotkey(START_KEY, clicker.start)
        keyboard.add_hotkey(STOP_KEY, clicker.stop)

        try:
            keyboard.wait("esc")
        except KeyboardInterrupt:
            clicker.stop()
    else:
        if args.delay > 0:
            print(f"\nStart za {args.delay:.0f}s... (Ctrl+C aby anulować)")
            try:
                time.sleep(args.delay)
            except KeyboardInterrupt:
                print("\nAnulowano.")
                sys.exit(0)

        clicker.start()
        try:
            while clicker.running:
                time.sleep(0.1)
        except KeyboardInterrupt:
            clicker.stop()


if __name__ == "__main__":
    main()
