pipeline {
    agent any
    tools {
        maven 'maven_latest'
        'org.jenkinsci.plugins.docker.commons.tools.DockerTool' 'docker_latest'
    }
    environment {
        GCP_SERVICE_ACCOUNT_FILE = credentials('gcp_service_account')
        SHORT_COMMIT = "${GIT_COMMIT[0..7]}"
        PROJECT_ID = 'gd-gcp-internship-devops'
        REPOSITORY_REGION = 'europe-central2'
        REPOSITORY_ID = 'vpanainte-spring-petclinic'
        IMAGE_NAME = 'spring-petclinic'
    }
    stages {
        stage('StaticCodeAnalysis') {
            when {
                changeRequest()
            }
            steps {
                echo 'Static code analysis'
                sh 'mvn checkstyle:checkstyle'
            }
        }

        stage('UnitTests') {
            when {
                changeRequest()
            }
            steps {
                echo 'Unit tests'
                sh 'mvn test'
            }
        }

        stage('PackageBuild') {
            when {
                changeRequest()
            }
            steps {
                echo 'Package build'
                sh 'mvn package -Dmaven.test.skip=true'
            }
        }

        stage('ReleaseGitTag') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo 'Tagging release in SCM'
                    withCredentials([gitUsernamePassword(credentialsId: 'github_access_token_pipeline', gitToolName: 'Default')]) {
                        env.latestTag = sh(returnStdout: true, script: "git tag --sort=-creatordate | head -n 1 | awk -F. '{OFS=\".\"; \$NF+=1; print \$0}'").trim()
                        sh "git tag -a '${env.latestTag}' -m \"jenkins pipeline auto-generated tag\""
                        sh "git push origin '${env.latestTag}'"
                    }
                }
            }
        }

        stage('ArtifactBuild') {
            when {
                anyOf {
                    changeRequest()
                    branch 'main'
                }
            }
            steps {
                script {
                    echo 'Building docker image'
                    env.imageVersion = "${env.BRANCH_NAME == 'main' ? env.latestTag : $SHORT_COMMIT}"
                    sh 'mvn package -Dmaven.test.skip=true'
                    sh "docker build -t $REPOSITORY_REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_ID/$IMAGE_NAME:${env.imageVersion} ."
                }
            }
        }

        stage('ArtifactUpload') {
            when {
                anyOf {
                    changeRequest()
                    branch 'main'
                }
            }
            steps {
                echo 'Uploading docker image to Google Artifact Registry'
                sh 'gcloud auth activate-service-account --key-file=$GCP_SERVICE_ACCOUNT_FILE'
                sh "gcloud auth configure-docker $REPOSITORY_REGION-docker.pkg.dev --quiet"
                sh "docker push $REPOSITORY_REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_ID/$IMAGE_NAME:${env.imageVersion}"
            }
        }

        stage('ArtifactDeploy') {
            when {
                branch 'main'
            }
            steps {
                echo 'Attempting to deploy docker image to Google Kubernetes Engine cluster'
                input message: 'Should we deploy the current docker image?', ok: 'Yes'
            }
        }
    }
}
