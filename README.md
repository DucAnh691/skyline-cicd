# Skyline CI/CD - Microservices on AWS EKS with Jenkins & Istio

Dự án **Skyline CI/CD** là một giải pháp triển khai tự động hóa (DevOps) toàn diện cho hệ thống Microservices trên nền tảng AWS. Dự án sử dụng mô hình **GitOps** và **Infrastructure as Code (IaC)** để quản lý hạ tầng và quy trình deployment.

## 🚀 Kiến trúc Hệ thống

Hệ thống được thiết kế theo chuẩn Enterprise với các thành phần chính:

*   **Cloud Provider:** AWS (Amazon Web Services).
*   **Orchestrator:** Amazon EKS (Kubernetes) v1.30.
*   **Infrastructure as Code:** Terraform (Quản lý VPC, IAM, EKS, EC2, ECR).
*   **CI/CD Pipeline:** Jenkins (Master/Agent Architecture) + Pipeline as Code (`Jenkinsfile`).
*   **Service Mesh:** Istio (Traffic Management, mTLS, Gateway, Canary Deployment).
*   **Package Manager:** Helm (Quản lý ứng dụng User/Order/Payment).
*   **Container Registry:** Amazon ECR.
*   **Monitoring & Logging:** Prometheus, Grafana, Fluentd (EFK Stack ready).

---

## 📂 Cấu trúc Thư mục

```text
skyline-cicd/
├── environments/                 # Cấu hình hạ tầng riêng biệt (GitOps)
│   ├── dev/                      # Môi trường Development
│   ├── stg/                      # Môi trường Staging
│   └── prod/                     # Môi trường Production
├── modules/                      # Terraform Modules (Reusable Code)
│   ├── vpc/                      # Mạng (Networking)
│   ├── eks/                      # Kubernetes Cluster & Node Groups
│   ├── jenkins/                  # Jenkins Master & Auto Scaling Agents
│   ├── iam/                      # Quyền truy cập (Roles & Policies)
│   └── ecr/                      # Docker Registry
├── helm/                         # Helm Charts tự tạo
│   └── skyline-chart/            # Generic Chart cho các Microservices
├── k8s/                          # Kubernetes Manifests tĩnh (Istio, Logging)
├── user-service/                 # Source Code: User Service (Python)
├── order-service/                # Source Code: Order Service (Python)
├── payment-service/              # Source Code: Payment Service (Python)
└── Jenkinsfile.groovy            # CI/CD Pipeline Logic
```

---

## 🛠️ Yêu cầu Cài đặt (Prerequisites)

Để triển khai dự án này, máy trạm (Local Machine) cần cài đặt:
1.  **Terraform** (v1.0+)
2.  **AWS CLI** (v2+) - Đã cấu hình `aws configure` với quyền Administrator.
3.  **Git**
4.  **SSH Key Pair** (`web-key.pem`) đã tạo trên AWS Console.

---

## ⚙️ Hướng dẫn Triển khai Hạ tầng (Terraform)

### 1. Khởi tạo môi trường Dev
```bash
cd environments/dev

# Khởi tạo Terraform và tải modules/providers
terraform init

# Kiểm tra kế hoạch triển khai
terraform plan

# Áp dụng (Tạo VPC, EKS, Jenkins...) - Mất khoảng 15-20 phút
terraform apply -auto-approve
```

> **Lưu ý:** Lặp lại bước trên cho `environments/stg` và `environments/prod` nếu muốn dựng full môi trường.

### 2. Kết nối vào Jenkins
Sau khi Terraform chạy xong, lấy IP của Jenkins Master từ AWS Console hoặc Output:
1.  Truy cập: `http://<JENKINS_MASTER_IP>:8080`
2.  Lấy mật khẩu admin ban đầu (SSH vào Master):
    ```bash
    ssh -i "web-key.pem" ec2-user@<JENKINS_MASTER_IP>
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    ```
3.  Cài đặt Plugins gợi ý và tạo Admin User.

---

## 🔄 Quy trình CI/CD (Jenkins Pipeline)

Pipeline được định nghĩa trong `Jenkinsfile.groovy` với các giai đoạn:

1.  **Initialize:** Xác định môi trường deploy (`dev`/`stg`/`prod`) dựa trên nhánh Git (`feature` -> Dev, `develop` -> Stg, `main` -> Prod).
2.  **Checkout Code:** Lấy mã nguồn và tạo Docker Tag từ Git Commit Hash (Short SHA).
3.  **Code Quality Scan:** (Tùy chọn) Quét mã nguồn với SonarQube.
4.  **Build & Push:**
    *   Đăng nhập ECR (dùng IAM Role, không lộ credential).
    *   Build Docker Image song song cho 3 services.
    *   Push ảnh lên ECR.
5.  **Deploy to EKS:**
    *   Cài đặt hạ tầng (Istio, Prometheus...) nếu được yêu cầu (`DEPLOY_INFRASTRUCTURE=true`).
    *   Deploy ứng dụng bằng **Helm Chart** (Upgrade/Install).
    *   Tự động **Rollback** nếu deploy thất bại.
    *   Áp dụng cấu hình Istio (Gateway, VirtualService).
    *   Triển khai Canary (Blue-Green) cho User Service.

---

## 🚦 Hướng dẫn Sử dụng & Vận hành

### 1. Trigger Build
*   **Tự động:** Push code lên GitHub (cần cấu hình Webhook).
*   **Thủ công:** Vào Jenkins > Build with Parameters > Chọn Environment > Build.

### 2. Truy cập Ứng dụng
Hệ thống sử dụng **Istio Ingress Gateway** làm điểm vào duy nhất (ClusterIP).

*   Lấy URL Gateway:
    ```bash
    kubectl get svc istio-ingress -n istio-system
    ```
*   URL truy cập:
    *   User Service: `http://<LB_URL>/user`
    *   Order Service: `http://<LB_URL>/order`
    *   Payment Service: `http://<LB_URL>/payment`

### 3. Giám sát (Monitoring)
*   **Grafana:** Truy cập qua Port Forward hoặc LoadBalancer (Port 80/3000).
    *   User/Pass: `admin` / `admin`
    *   Dashboards: Import ID `7639` để xem Istio Mesh traffic.
*   **Kiali (Optional):** Trực quan hóa Service Mesh topology.

### 4. Tiết kiệm Chi phí (Cost Optimization)
*   **Jenkins Agents:** Sử dụng Auto Scaling Group với `min_size = 0`. Agents tự động tắt khi không có build.
*   **ECR Lifecycle:** Tự động xóa các image cũ quá 10 bản build.
*   **Spot Instances:** Sử dụng cho Jenkins Agent để giảm 70-90% chi phí compute.

---

## 🐛 Troubleshooting (Xử lý sự cố)

### Lỗi: `Pending` Pods trong namespace Monitoring
*   **Nguyên nhân:** Do Alertmanager yêu cầu Persistent Volume (EBS) nhưng Node chưa kịp cấp phát hoặc config sai.
*   **Khắc phục:** Pipeline đã có cơ chế tự động fix bằng cách tắt Alertmanager PV. Nếu vẫn bị, hãy chạy thủ công:
    ```bash
    kubectl delete pvc --all -n monitoring
    helm uninstall prometheus -n monitoring
    ```

### Lỗi: Jenkins Agent không kết nối được Master
*   Kiểm tra **Security Group**: Master phải mở port 22/8080. Agent phải cho phép traffic từ Master.
*   Kiểm tra **IAM Role**: Agent cần quyền `eks:DescribeCluster` để update kubeconfig.

---

## 🔒 Bảo mật (Security Best Practices)

*   **Least Privilege:** Jenkins Agent dùng IAM Role, không lưu AWS Keys cứng.
*   **Network Segmentation:** EKS Node nên đặt trong Private Subnet (đang dùng Public cho Lab, cần chuyển sang Private cho Prod).
*   **mTLS:** Istio được cấu hình chế độ `STRICT` mTLS cho toàn bộ giao tiếp nội bộ.
*   **Container Security:** Quét image ECR khi push (Image Scanning on Push enabled).

---

## 👥 Tác giả
*   **Dự án:** Skyline CI/CD
*   **Phiên bản:** 1.0.0
```