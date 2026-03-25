import os
import socket
import threading
from flask import Flask, request, jsonify
from zeroconf import ServiceInfo, Zeroconf

app = Flask(__name__)
UPLOAD_DIR = "./backup_recebido"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.route("/")
def index_sync():
    return "<p>Bkp LensFLow</p>"

@app.route("/upload", methods=["POST"])
def upload():
    files = request.files.getlist("files")
    folder = request.form.get("folder", "sem_pasta")

    dest = os.path.join(UPLOAD_DIR, folder)
    os.makedirs(dest, exist_ok=True)

    saved = []
    for f in files:
        path = os.path.join(dest, f.filename)
        f.save(path)
        saved.append(f.filename)
        print(f"  ✓ {folder}/{f.filename}")

    return jsonify({"status": "ok", "saved": saved})


@app.route("/ping")
def ping():
    return jsonify({"status": "ok", "server": "lensflow"})


def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()


def register_zeroconf(port=5000):
    ip = get_local_ip()
    ip_bytes = socket.inet_aton(ip)

    info = ServiceInfo(
        "_lensflow._tcp.local.",
        "LensFlow._lensflow._tcp.local.",
        addresses=[ip_bytes],
        port=port,
        properties={"version": "0.01",
                    "path": "/",
                    "path": "/upload",
                    "path": "/ping",
        },
    )

    zc = Zeroconf()
    zc.register_service(info)
    print(f"[Zeroconf] Serviço registrado: {ip}:{port}")
    return zc


if __name__ == "__main__":
    PORT = 5000
    zc = register_zeroconf(PORT)
    try:
        print(f"[Flask] Servidor em http://0.0.0.0:{PORT}")
        app.run(host="0.0.0.0", port=PORT)
    finally:
        zc.unregister_all_services()
        zc.close()