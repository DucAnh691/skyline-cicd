pipeline {
    agent {
        // Chạy trên Agent đã cấu hình (khớp với label lúc Add Node)
        label 'Agent-1'
    }

    environment {
        // Cấu hình thông tin AWS
        AWS_ACCOUNT_ID = '427077356037'
        AWS_REGION     = 'ap-southeast-1'
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