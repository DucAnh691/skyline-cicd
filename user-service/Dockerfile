# Sử dụng Python 3.9 Slim (Nhẹ)
FROM python:3.9-slim

WORKDIR /app

# Cài đặt thư viện
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY app.py .

# Chạy app
CMD ["python", "app.py"]