pipeline {
    agent any

    environment {
        ACR_NAME         = 'acrgitopsdemodev'
        ACR_LOGIN_SERVER = "${ACR_NAME}.azurecr.io"
        IMAGE_NAME       = 'appimage'
        CONTAINER_NAME   = 'myapp'
        IMAGE_TAG        = "${BUILD_NUMBER}"
        FULL_IMAGE       = "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                bat "docker build -t ${FULL_IMAGE} ."
            }
        }

        stage('Run Tests') {
            steps {
                bat "docker run --rm ${FULL_IMAGE} npm test"
            }
        }

        stage('Push to ACR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'acr-credentials',
                    usernameVariable: 'ACR_USER',
                    passwordVariable: 'ACR_PASS'
                )]) {
                    bat "docker login ${ACR_LOGIN_SERVER} -u %ACR_USER% -p %ACR_PASS%"
                    bat "docker push ${FULL_IMAGE}"
                }
            }
        }

        stage('Deploy to Dev') {
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                    string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')
                ]) {
                    bat "kubectl apply -f k8s/dev/ --namespace=dev-j"
                    bat "kubectl set image deployment/myapp-deployment ${CONTAINER_NAME}=${FULL_IMAGE} --namespace=dev-j"
                    bat "kubectl rollout status deployment/myapp-deployment --namespace=dev-j --timeout=120s"
                    powershell """
                        \$url = "\$env:SLACK_WEBHOOK"
                        \$body = '{"text":":white_check_mark: *DEV deploy succeeded* | Build #${BUILD_NUMBER}"}'
                        Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                    """
                }
            }
            post {
                failure {
                    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                        powershell """
                            \$url = "\$env:SLACK_WEBHOOK"
                            \$body = '{"text":":x: *DEV deploy failed* | Build #${BUILD_NUMBER}"}'
                            Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                        """
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                    string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')
                ]) {
                    bat "kubectl apply -f k8s/staging/ --namespace=staging-j"
                    bat "kubectl set image deployment/myapp-deployment ${CONTAINER_NAME}=${FULL_IMAGE} --namespace=staging-j"
                    bat "kubectl rollout status deployment/myapp-deployment --namespace=staging-j --timeout=120s"
                    powershell """
                        \$url = "\$env:SLACK_WEBHOOK"
                        \$body = '{"text":":rocket: *STAGING deploy succeeded* | Build #${BUILD_NUMBER}"}'
                        Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                    """
                }
            }
            post {
                failure {
                    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                        powershell """
                            \$url = "\$env:SLACK_WEBHOOK"
                            \$body = '{"text":":x: *STAGING deploy failed* | Build #${BUILD_NUMBER}"}'
                            Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                        """
                    }
                }
            }
        }

        stage('Approval: Deploy to Prod?') {
            steps {
                withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                    powershell """
                        \$url = "\$env:SLACK_WEBHOOK"
                        \$body = '{"text":":hourglass: *Waiting for PROD approval* | Build #${BUILD_NUMBER} | Approve at: ${BUILD_URL}input"}'
                        Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                    """
                    input message: 'Staging looks good. Deploy to Production?',
                          ok: 'Deploy to Prod',
                          submitter: 'admin'
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                withCredentials([
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
                    string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')
                ]) {
                    bat "kubectl apply -f k8s/prod/ --namespace=prod-j"
                    bat "kubectl set image deployment/myapp-deployment ${CONTAINER_NAME}=${FULL_IMAGE} --namespace=prod-j"
                    bat "kubectl rollout status deployment/myapp-deployment --namespace=prod-j --timeout=120s"
                    powershell """
                        \$url = "\$env:SLACK_WEBHOOK"
                        \$body = '{"text":":tada: *PROD deploy succeeded* | Build #${BUILD_NUMBER} | Image: ${FULL_IMAGE}"}'
                        Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                    """
                }
            }
            post {
                failure {
                    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                        powershell """
                            \$url = "\$env:SLACK_WEBHOOK"
                            \$body = '{"text":":fire: *PROD deploy FAILED* | Build #${BUILD_NUMBER}"}'
                            Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            bat "docker rmi ${FULL_IMAGE} || exit 0"
        }
        success {
            withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                powershell """
                    \$url = "\$env:SLACK_WEBHOOK"
                    \$body = '{"text":":white_check_mark: *Pipeline complete* | Build #${BUILD_NUMBER} | All environments updated."}'
                    Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                """
            }
        }
        failure {
            withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                powershell """
                    \$url = "\$env:SLACK_WEBHOOK"
                    \$body = '{"text":":x: *Pipeline failed* | Build #${BUILD_NUMBER}"}'
                    Invoke-RestMethod -Uri \$url -Method Post -ContentType 'application/json' -Body \$body
                """
            }
        }
    }
}