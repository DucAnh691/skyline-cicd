from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({"message": "Hello from User Service (Python)", "status": "active"})

if __name__ == '__main__':
    # Chạy trên port 8081 để khớp với cấu trúc cũ
    port = int(os.environ.get('PORT', 8081))
    app.run(host='0.0.0.0', port=port)