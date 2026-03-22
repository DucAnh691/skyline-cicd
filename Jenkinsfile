// =============================================================================
// == Declarative Pipeline: Định nghĩa quy trình CI/CD cho dự án Skyline     ==
// =============================================================================
pipeline {
    agent {
        // Chạy trên Agent đã cấu hình (khớp với label lúc Add Node)
        label 'Agent-1'
    }

    triggers {
        // Tự động kích hoạt pipeline mỗi khi có code được push lên GitHub.
        githubPush()
    }

    parameters {
        // Tham số hóa pipeline, cho phép người dùng tùy chọn khi build thủ công.
        choice(name: 'ENVIRONMENT', choices: ['dev', 'stg', 'prod'], description: 'Chọn môi trường Deployment')
        booleanParam(name: 'DEPLOY_INFRASTRUCTURE', defaultValue: false, description: 'Tích chọn nếu muốn Cài đặt/Nâng cấp hạ tầng (Istio, Prometheus, Grafana). Mặc định tắt để build nhanh hơn.')
    }

    environment {
        // Cấu hình thông tin AWS
        AWS_ACCOUNT_ID = '427077356037'
        AWS_REGION     = 'ap-southeast-1'
        // CLUSTER_NAME sẽ được set động trong stage 'Initialize'
        REGISTRY_URL   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }

    stages {
        // =====================================================================
        // == STAGE 1: KHỞI TẠO - Xác định môi trường và biến cần thiết        ==
        // =====================================================================
        stage('Initialize') {
            steps {
                script {
                    // --- Logic xác định môi trường theo Git Branch (GitOps) ---
                    // Ưu tiên 1: Tham số người dùng chọn khi build thủ công.
                    // Ưu tiên 2: Tự động xác định dựa trên tên nhánh Git khi được trigger.
                    //   - main   -> prod
                    //   - develop -> stg
                    //   - khác    -> dev
                    
                    def targetEnv = params.ENVIRONMENT
                    
                    // Kiểm tra nếu đang chạy tự động từ Webhook (BRANCH_NAME có giá trị)
                    if (env.BRANCH_NAME) {
                        if (env.BRANCH_NAME == 'main') {
                            targetEnv = 'prod'
                        } else if (env.BRANCH_NAME == 'develop') {
                            targetEnv = 'stg'
                        } else {
                            targetEnv = 'dev'
                        }
                    }
                    
                    switch(targetEnv) {
                        case 'dev':
                            env.CLUSTER_NAME = 'sky-line-cicd-eks'
                            break
                        case 'stg':
                            env.CLUSTER_NAME = 'sky-line-cicd-stg-eks'
                            break
                        case 'prod':
                            env.CLUSTER_NAME = 'sky-line-cicd-prod-eks'
                            break
                    }
                    
                    echo "Branch: ${env.BRANCH_NAME} -> Target Environment: ${targetEnv} | Cluster: ${env.CLUSTER_NAME}"
                }
            }
        }

        // =====================================================================
        // == STAGE 2: CHECKOUT CODE - Lấy mã nguồn và xác định Image Tag     ==
        // =====================================================================
        stage('Checkout Code') {
            steps {
                checkout scm
                script {
                    // Lấy 7 ký tự đầu của Git commit hash làm tag cho Docker image.
                    // Điều này đảm bảo mỗi phiên bản code có một tag duy nhất, rất quan trọng cho việc rollback.
                    env.IMAGE_TAG = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    echo "Docker Image Tag for this build: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build & Push Services') {
            // =====================================================================
            // == STAGE 3: BUILD & PUSH - Xây dựng Docker image và đẩy lên ECR    ==
            // =====================================================================
            steps {
                script {
                    // Bước 1: Đăng nhập vào Amazon ECR.
                    // Phương pháp này bảo mật vì không lưu trữ credential, thay vào đó sử dụng IAM Role của EC2 Agent.
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY_URL}"

                    // Bước 2: Tối ưu hóa thời gian build bằng cách chạy song song cho cả 3 services.
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
            // =====================================================================
            // == STAGE 4: DEPLOY - Triển khai hạ tầng và ứng dụng lên EKS        ==
            // =====================================================================
            steps {
                script {
                    // Bước 1: Cấu hình kubectl để kết nối tới EKS cluster của môi trường tương ứng.
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"

                    // --- INFRASTRUCTURE SETUP (Conditional) ---
                    // Bước 2: Cài đặt hạ tầng nền tảng (Istio, Prometheus, Grafana).
                    // Luồng này chỉ chạy khi người dùng tích chọn 'DEPLOY_INFRASTRUCTURE', giúp tiết kiệm thời gian cho các lần build thông thường.
                    if (params.DEPLOY_INFRASTRUCTURE) {
                        echo "🚀 Starting Full Infrastructure Setup (Istio, Monitoring, Logging)..."
                        
                        // 1. Cài đặt Istio
                        sh "helm repo add istio https://istio-release.storage.googleapis.com/charts || true"
                        
                        // 2. Cài đặt Monitoring (Prometheus/Grafana)
                        sh "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true"
                        sh "helm repo add grafana https://grafana.github.io/helm-charts || true"
                        
                        // Update Repo 1 lần duy nhất
                        sh "helm repo update"
                        
                        // Istio Install
                        sh "helm upgrade --install istio-base istio/base -n istio-system --create-namespace --wait"
                        sh "helm upgrade --install istiod istio/istiod -n istio-system --wait"
                        sh "helm upgrade --install istio-ingress istio/gateway -n istio-system --wait"
                        sh "kubectl label namespace default istio-injection=enabled --overwrite"

                        // Prometheus Install (Clean Install logic)
                        sh "helm uninstall prometheus -n monitoring || true"
                        sh "kubectl delete pvc --all -n monitoring --ignore-not-found" // Xóa Persistent Volume Claim cũ (nếu có)
                        // Re-enable Alertmanager nhưng tắt PV để dùng ổ cứng Node (50GB) -> Tránh lỗi Pending
                        sh "helm upgrade --install prometheus prometheus-community/prometheus --create-namespace --namespace monitoring --set server.persistentVolume.enabled=false --set alertmanager.enabled=true --set alertmanager.persistentVolume.enabled=false --set server.resources.requests.cpu=100m --wait --timeout 10m"

                        // Grafana Install
                        sh "helm upgrade --install grafana grafana/grafana --namespace monitoring --set adminPassword='admin' --set persistence.enabled=false --wait --timeout 10m"

                        // Fluentd Logging
                        sh "kubectl apply -f k8s/fluentd.yaml"

                    } else {
                        echo "Skipping Infrastructure Setup (Enable 'DEPLOY_INFRASTRUCTURE' parameter to run)."
                    }

                    // --- APP DEPLOYMENT (Always Run) ---
                    // Bước 3: Triển khai ứng dụng. Luôn chạy trong mọi lần build.
                    
                    // 3.1: Áp dụng cấu hình Istio Gateway và VirtualService để điều hướng traffic.
                    sh "ls k8s/istio-config.yaml && kubectl apply -f k8s/istio-config.yaml"
                    
                    // 3.2: Deploy các microservices bằng Helm Chart.
                    def services = [
                        'user-service': 8081,
                        'order-service': 8082,
                        'payment-service': 8083
                    ]

                    services.each { serviceName, containerPort ->
                        try {
                            echo "Deploying ${serviceName} (Tag: ${env.IMAGE_TAG}) using Helm..."
                            
                            // Lệnh 'helm upgrade --install' sẽ tự động cài mới nếu chưa có, hoặc nâng cấp nếu đã tồn tại.
                            // Cờ '--wait' và '--timeout' đảm bảo pipeline sẽ chờ đến khi deployment thành công (pod ready).
                            sh """
                            helm upgrade --install ${serviceName} ./helm/skyline-chart \
                                --set appName=${serviceName} \
                                --set image.repository=${REGISTRY_URL}/${serviceName} \
                                --set image.tag=${env.IMAGE_TAG} \
                                --set service.type=ClusterIP \
                                --set service.targetPort=${containerPort} \
                                --wait \
                                --timeout 5m
                            """
                        } catch (Exception e) {
                            // --- CƠ CHẾ TỰ ĐỘNG ROLLBACK ---
                            // Nếu 'helm upgrade' thất bại (ví dụ: health check không qua), khối catch sẽ được kích hoạt.
                            echo "❌ Deployment failed for ${serviceName}. Initiating automatic rollback..."
                            // Lệnh 'helm rollback' sẽ đưa ứng dụng về phiên bản ổn định trước đó.
                            sh "helm rollback ${serviceName} || true"
                            
                            // Dừng pipeline và báo lỗi.
                            error "Pipeline aborted due to deployment failure of ${serviceName}."
                        }
                    }

                    // --- BƯỚC 11 & 12: Blue-Green & Canary Deployment ---
                    echo "Deploying User Service GREEN (v2)..."
                    def greenImage = "${REGISTRY_URL}/user-service:${env.IMAGE_TAG}" // FIX: Dùng đúng Tag của lần build này
                    // Deploy Green Version
                    sh "sed 's|IMAGE_PLACEHOLDER|${greenImage}|g' k8s/user-service-green.yaml | kubectl apply -f -"
                    
                    echo "Applying Canary Traffic Split (90% v1, 10% v2)..."
                    sh "kubectl apply -f k8s/istio-canary.yaml"
                    
                    echo "All deployments & configurations completed!"
                }
            }
        }
    }

    // =========================================================================
    // == POST ACTIONS: Các hành động luôn chạy sau khi pipeline kết thúc      ==
    // =========================================================================
    post {
        always {
            // Luôn dọn dẹp Docker cache để tránh đầy ổ cứng của Agent.
            sh 'docker system prune -f'
        }
        success {
            echo '✅ Pipeline deployed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}

// =============================================================================
// == HELPER FUNCTION: Hàm tái sử dụng để build và push image cho một service ==
// =============================================================================
def buildService(serviceName) {
    // Sử dụng các biến môi trường đã được định nghĩa ở đầu pipeline.
    def fullImageName = "${env.REGISTRY_URL}/${serviceName}:${env.IMAGE_TAG}"

    echo "Starting pipeline for ${serviceName}..."
    
    // Bước 1: Build Docker Image
    // Context build là thư mục service để COPY được file app.py
    sh "docker build -t ${serviceName}:${env.IMAGE_TAG} -f ./${serviceName}/Dockerfile ./${serviceName}"
    
    // Bước 2: Tag & Push lên ECR
    sh "docker tag ${serviceName}:${env.IMAGE_TAG} ${fullImageName}"
    sh "docker push ${fullImageName}"
}