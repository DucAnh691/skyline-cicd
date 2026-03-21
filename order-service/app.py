from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({"message": "Hello from Order Service (Python)", "status": "active"})

if __name__ == '__main__':
    # Chạy trên port 8082
    port = int(os.environ.get('PORT', 8082))
    app.run(host='0.0.0.0', port=port)