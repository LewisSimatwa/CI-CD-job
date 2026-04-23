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
                script {
                    bat "docker build -t ${FULL_IMAGE} ."
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    bat "docker run --rm ${FULL_IMAGE} npm test"
                }
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
                    bat "kubectl apply -f k8s/dev/ --namespace=dev"
                    bat "kubectl set image deployment/myapp-deployment ${CONTAINER_NAME}=${FULL_IMAGE} --namespace=dev"
                    bat "kubectl rollout status deployment/myapp-deployment --namespace=dev --timeout=120s"
                    bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":white_check_mark: *DEV deploy succeeded* | Build #%BUILD_NUMBER%\\"}" %SLACK_WEBHOOK%"""
                }
            }
            post {
                failure {
                    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                        bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":x: *DEV deploy failed* | Build #%BUILD_NUMBER% | %BUILD_URL%\\"}" %SLACK_WEBHOOK%"""
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
                    bat "kubectl apply -f k8s/staging/ --namespace=staging"
                    bat "kubectl set image deployment/myapp-deployment ${CONTAINER_NAME}=${FULL_IMAGE} --namespace=staging"
                    bat "kubectl rollout status deployment/myapp-deployment --namespace=staging --timeout=120s"
                    bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":rocket: *STAGING deploy succeeded* | Build #%BUILD_NUMBER%\\"}" %SLACK_WEBHOOK%"""
                }
            }
            post {
                failure {
                    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                        bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":x: *STAGING deploy failed* | Build #%BUILD_NUMBER% | %BUILD_URL%\\"}" %SLACK_WEBHOOK%"""
                    }
                }
            }
        }

        stage('Approval: Deploy to Prod?') {
            steps {
                withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                    bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":hourglass: *Waiting for PROD approval* | Build #%BUILD_NUMBER% | Approve at: %BUILD_URL%input\\"}" %SLACK_WEBHOOK%"""
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
                    bat "kubectl apply -f k8s/prod/ --namespace=prod"
                    bat "kubectl set image deployment/myapp-deployment ${CONTAINER_NAME}=${FULL_IMAGE} --namespace=prod"
                    bat "kubectl rollout status deployment/myapp-deployment --namespace=prod --timeout=120s"
                    bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":tada: *PROD deploy succeeded* | Build #%BUILD_NUMBER% | Image: ${FULL_IMAGE}\\"}" %SLACK_WEBHOOK%"""
                }
            }
            post {
                failure {
                    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                        bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":fire: *PROD deploy FAILED* | Build #%BUILD_NUMBER% | %BUILD_URL%\\"}" %SLACK_WEBHOOK%"""
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
                bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":white_check_mark: *Pipeline complete* | Build #%BUILD_NUMBER% | All environments updated.\\"}" %SLACK_WEBHOOK%"""
            }
        }
        failure {
            withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK')]) {
                bat """curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\":x: *Pipeline failed* | Build #%BUILD_NUMBER% | %BUILD_URL%console\\"}" %SLACK_WEBHOOK%"""
            }
        }
    }
}