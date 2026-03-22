pipeline {
    agent {
        // Chạy trên Agent đã cấu hình (khớp với label lúc Add Node)
        label 'Agent-1'
    }

    triggers {
        githubPush()
    }

    environment {
        // Cấu hình thông tin AWS
        AWS_ACCOUNT_ID = '427077356037'
        AWS_REGION     = 'ap-southeast-1'
        CLUSTER_NAME   = 'sky-line-cicd-eks' // Tên EKS Cluster (khớp với Terraform)
        REGISTRY_URL   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push Services') {
            steps {
                script {
                    // 1. Đăng nhập ECR (Chỉ cần 1 lần cho Agent session)
                    // Sử dụng IAM Role của Agent (Zero credentials) để bảo mật
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY_URL}"

                    // 2. Chạy song song quá trình Build Docker -> Push cho từng Service
                    parallel(
                        'User Service': {
                            buildService('user-service')
                        },
                        'Order Service': {
                            buildService('order-service')
                        },
                        'Payment Service': {
                            buildService('payment-service')
                        }
                    )
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                script {
                    // 1. Cập nhật kubeconfig để lấy quyền truy cập Cluster
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"

                    // 2. Cài đặt / Cấu hình Istio (Idempotent - Chạy nhiều lần không sao)
                    echo "Setting up Istio..."
                    // Thêm Repo Istio nếu chưa có
                    sh "helm repo add istio https://istio-release.storage.googleapis.com/charts || true"
                    sh "helm repo update"
                    // Cài đặt Istio Base, Istiod và Ingress Gateway
                    sh "helm upgrade --install istio-base istio/base -n istio-system --create-namespace --wait"
                    sh "helm upgrade --install istiod istio/istiod -n istio-system --wait"
                    sh "helm upgrade --install istio-ingress istio/gateway -n istio-system --wait"

                    // Bật tính năng tự động tiêm Sidecar cho namespace mặc định
                    sh "kubectl label namespace default istio-injection=enabled --overwrite"
                    
                    // DEBUG: Liệt kê file để kiểm tra đường dẫn thực tế
                    sh "ls -la *.yaml"
                    
                    // Apply cấu hình Istio (VirtualService, DestinationRule, PeerAuthentication)
                    sh "kubectl apply -f istio-config.yaml"

                    // --- BƯỚC 13: Cài đặt Giám sát (Prometheus & Grafana) ---
                    echo "Installing Monitoring Stack..."
                    sh "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
                    sh "helm repo add grafana https://grafana.github.io/helm-charts"
                    sh "helm repo update"
                    
                    // Cài Prometheus (Namespace monitoring)
                    // Tắt Persistent Volume (PV) để tránh lỗi timeout do thiếu EBS CSI Driver (StorageClass)
                    sh "helm upgrade --install prometheus prometheus-community/prometheus --create-namespace --namespace monitoring --set server.persistentVolume.enabled=false --set alertmanager.persistentVolume.enabled=false --wait --timeout 10m"
                    
                    // Cài Grafana
                    // Lưu ý: set adminPassword để dễ đăng nhập, tắt persistence
                    sh "helm upgrade --install grafana grafana/grafana --namespace monitoring --set adminPassword='admin' --set persistence.enabled=false --wait --timeout 10m"

                    // 3. Deploy từng service
                    def services = ['user-service', 'order-service', 'payment-service']
                    for (service in services) {
                        echo "Deploying ${service}..."
                        
                        // Thay thế placeholder IMAGE_PLACEHOLDER bằng ảnh thật trên ECR
                        def image = "${REGISTRY_URL}/${service}:latest"
                        sh "sed 's|IMAGE_PLACEHOLDER|${image}|g' ${service}.yaml | kubectl apply -f -"
                        
                        // Restart deployment để đảm bảo Pod pull image mới nhất (vì dùng tag latest)
                        sh "kubectl rollout restart deployment/${service}"
                    }

                    // --- BƯỚC 11 & 12: Blue-Green & Canary Deployment ---
                    echo "Deploying User Service GREEN (v2)..."
                    def greenImage = "${REGISTRY_URL}/user-service:latest" // Demo dùng chung ảnh latest
                    // Deploy Green Version
                    sh "sed 's|IMAGE_PLACEHOLDER|${greenImage}|g' user-service-green.yaml | kubectl apply -f -"
                    
                    echo "Applying Canary Traffic Split (90% v1, 10% v2)..."
                    sh "kubectl apply -f istio-canary.yaml"

                    // --- BƯỚC 14 & 15: Logging & Alerting ---
                    echo "Setting up Fluentd & Alertmanager..."
                    // Apply Fluentd
                    sh "kubectl apply -f fluentd.yaml"
                    
                    // Apply Alertmanager Config (Yêu cầu namespace monitoring đã có từ bước trên)
                    sh "kubectl apply -f alertmanager-config.yaml"
                    
                    echo "All deployments & configurations completed!"
                }
            }
        }
    }

    post {
        always {
            // Dọn dẹp Docker system để tránh đầy ổ cứng Agent
            sh 'docker system prune -f'
        }
        success {
            echo 'Pipeline deployed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}

// Hàm xử lý trọn gói cho 1 Service: Build Docker -> Push ECR
def buildService(serviceName) {
    def imageTag = "latest" // Trong production nên dùng env.BUILD_NUMBER
    def fullImageName = "${env.REGISTRY_URL}/${serviceName}:${imageTag}"

    echo "Starting pipeline for ${serviceName}..."
    
    // Bước 1: Build Docker Image
    // Context build là thư mục service để COPY được file app.py
    sh "docker build -t ${serviceName}:${imageTag} -f ./${serviceName}/Dockerfile ./${serviceName}"
    
    // Bước 2: Tag & Push lên ECR
    sh "docker tag ${serviceName}:${imageTag} ${fullImageName}"
    sh "docker push ${fullImageName}"
}