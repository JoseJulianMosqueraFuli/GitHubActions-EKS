import os
import time
import multiprocessing
from flask import Flask, jsonify

app = Flask(__name__)

def burn_cpu(target_percent, duration=10):
    """Genera carga de CPU al porcentaje indicado durante `duration` segundos."""
    end_time = time.time() + duration
    while time.time() < end_time:
        # Ciclo activo proporcional al target
        busy_end = time.time() + 0.01 * (target_percent / 100)
        while time.time() < busy_end:
            pass
        # Ciclo idle proporcional al resto
        time.sleep(0.01 * (1 - target_percent / 100))

@app.route("/health")
def health():
    return jsonify({"status": "ok", "hostname": os.uname().nodename})

@app.route("/<int:percent>")
def load(percent):
    if percent < 1 or percent > 100:
        return jsonify({"error": "El porcentaje debe estar entre 1 y 100"}), 400

    duration = 10  # segundos de carga
    num_cores = multiprocessing.cpu_count()

    # Lanza un proceso por core para saturar la CPU al % pedido
    processes = []
    for _ in range(num_cores):
        p = multiprocessing.Process(target=burn_cpu, args=(percent, duration))
        p.start()
        processes.append(p)

    for p in processes:
        p.join()

    return jsonify({
        "hostname": os.uname().nodename,
        "target_cpu_percent": percent,
        "duration_seconds": duration,
        "cores_used": num_cores
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
