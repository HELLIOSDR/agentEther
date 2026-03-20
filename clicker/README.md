# AgentEther Auto-Clicker

Prosty auto-klikacz na pulpit dla systemu Linux/X11.

## Szybka instalacja

```bash
# Sklonuj repo i wejdź do katalogu
git clone https://github.com/HELLIOSDR/agentEther
cd agentEther/clicker

# Uruchom instalator
bash setup_clicker.sh
```

## Użycie z terminala

```bash
# Podstawowe klikanie co 1s (3s opóźnienie startu)
agentether-clicker

# Klikaj co 0.5 sekundy
agentether-clicker -i 0.5

# Klikaj na konkretnej pozycji x=500, y=300
agentether-clicker -x 500 -y 300

# Prawy przycisk co 2s, 50 razy
agentether-clicker -b right -i 2 -n 50

# Tryb hotkeys: F5=start, F6=stop
agentether-clicker --hotkeys
```

## Zatrzymanie awaryjne

Przesuń kursor myszy do **rogu ekranu** - klikacz zatrzyma się natychmiast.

## Zdalnie przez SSH (192.168.0.142)

```bash
ssh user@192.168.0.142
cd agentEther/clicker
bash setup_clicker.sh
```

Lub uruchom bezpośrednio przez SSH z X forwarding:

```bash
ssh -X user@192.168.0.142 "python3 ~/agentEther/clicker/clicker.py -i 1"
```
