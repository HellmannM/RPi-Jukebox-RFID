#!/usr/bin/env bash

#sudo apt update
#sudo apt install -y python3-pip python3-smbus i2c-tools
#sudo pip3 install --break-system-packages --upgrade adafruit-blinka adafruit-circuitpython-tpa2016

#sudo i2cdetect -y 1

SCRIPTFILE="/usr/local/bin/tpa2016d2-set-gain.py"
sudo tee "$SCRIPTFILE" <<EOF
#!/usr/bin/env python3
import os
import time
import sys

import board
import adafruit_tpa2016

# Config via environment variables
INTERVAL_S = float(os.getenv("TPA2016_INTERVAL", "5"))
FIXED_GAIN_DB = int(os.getenv("TPA2016_FIXED_GAIN_DB", "6"))  # 0..30 when AGC/compression is disabled

def log(msg: str) -> None:
    print(f"[tpa2016d2-set-gain] {msg}", flush=True)

def clamp(n, lo, hi):
    return max(lo, min(hi, n))

def main() -> int:
    fixed_gain = clamp(FIXED_GAIN_DB, 0, 30)

    # Create I2C bus and device
    i2c = board.I2C()  # Uses /dev/i2c-1 on Raspberry Pi
    tpa = adafruit_tpa2016.TPA2016(i2c)

    log("tpa2016d2-set-gain service started")

    while True:
        try:
            tpa.compression_ratio = tpa.COMPRESSION_1_1
            tpa.fixed_gain = fixed_gain
            tpa.max_gain = 30
            tpa.output_limiter_disable = True
            tpa.noise_gate_enable = False
            #log(f"TPA2016D2 Configured: interval={INTERVAL_S}s fixed_gain={fixed_gain}dB (AGC off via 1:1)")
            #log(f"readback: compression={tpa.compression_ratio} limiter_disabled={tpa.output_limiter_disable} fixed_gain={tpa.fixed_gain}")

        except Exception as e:
            #log(f"ERROR: {e!r}")
            pass

        time.sleep(INTERVAL_S)

if __name__ == "__main__":
    raise SystemExit(main())
EOF

sudo chmod +x "$SCRIPTFILE"

SERVICEFILE="/etc/systemd/system/tpa2016d2-set-gain.service"
sudo tee "$SERVICEFILE" <<EOF
[Unit]
Description=TPA2016D2 set gain: disable AGC (1:1) + set fixed gain every 5s
After=multi-user.target
Wants=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/env python3 $SCRIPTFILE
Restart=always
RestartSec=2

Environment="TPA2016_INTERVAL=1"
Environment="TPA2016_FIXED_GAIN_DB=12"

NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now tpa2016d2-set-gain.service
sudo systemctl restart tpa2016d2-set-gain.service

#journalctl -u tpa2016d2-set-gain.service -f

