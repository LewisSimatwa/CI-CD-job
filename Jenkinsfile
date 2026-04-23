pipeline {
    agent any

    environment {
        ACR_NAME      = 'acrgitopsdemodev'
        ACR_LOGIN_SERVER = "${ACR_NAME}.azurecr.io"
        IMAGE_NAME    = 'myapp'
        IMAGE_TAG     = "${BUILD_NUMBER}"
        FULL_IMAGE    = "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
        K8S_NAMESPACE = 'default'
        DEPLOYMENT    = 'myapp-deployment'
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

        stage('Deploy to AKS') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    bat "kubectl set image deployment/${DEPLOYMENT} ${IMAGE_NAME}=${FULL_IMAGE} --namespace=${K8S_NAMESPACE}"
                    bat "kubectl rollout status deployment/${DEPLOYMENT} --namespace=${K8S_NAMESPACE} --timeout=120s"
                }
            }
        }
    }

    post {
        success { echo 'Pipeline succeeded! App deployed to AKS.' }
        failure { echo 'Pipeline failed. Check logs above.' }
        always  { bat "docker rmi ${FULL_IMAGE} || exit 0" }
    }
}