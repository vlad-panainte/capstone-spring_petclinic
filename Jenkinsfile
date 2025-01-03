pipeline {
    agent any
    options {
        ansiColor('VGA')
    }
    tools {
        maven 'maven_latest'
        'org.jenkinsci.plugins.docker.commons.tools.DockerTool' 'docker_latest'
    }
    environment {
        GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp_service_account')
        SQL_CREDENTIALS = credentials('sql_credentials')
        SHORT_COMMIT = "${GIT_COMMIT[0..7]}"
        REPOSITORY_ID = 'vpanainte-spring-petclinic'
        IMAGE_NAME = 'spring-petclinic'
        TF_VAR_project_id = 'gd-gcp-gridu-devops-t1-t2'
        TF_VAR_region = 'europe-central2'
        TF_VAR_zone = 'europe-central2-a'
        TF_VAR_gke_name = 'vpanainte-cluster'
        TF_VAR_gke_deployment_name = 'vpanainte-spring-petclinic'
        TF_VAR_gke_deployment_secret_service_account = credentials('gcp_service_account')
        TF_VAR_artifact_repository_id = 'vpanainte-spring-petclinic'
        TF_VAR_sql_database_name = 'vpanainte-mysql'
        TF_VAR_sql_user_name = "$SQL_CREDENTIALS_USR"
        TF_VAR_sql_user_password = "$SQL_CREDENTIALS_PSW"
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
                sh 'mvn clean package -Dmaven.test.skip=true'
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
                    env.imageVersion = "${env.BRANCH_NAME == 'main' ? env.latestTag : env.SHORT_COMMIT}"
                    sh 'rm -f target/*.jar'
                    sh 'mvn package -Dmaven.test.skip=true'
                    sh "docker build -t $TF_VAR_region-docker.pkg.dev/$TF_VAR_project_id/$TF_VAR_artifact_repository_id/$IMAGE_NAME:${env.imageVersion} ."
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
                sh 'gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS'
                sh "gcloud auth configure-docker $TF_VAR_region-docker.pkg.dev --quiet"
                sh "docker push $TF_VAR_region-docker.pkg.dev/$TF_VAR_project_id/$TF_VAR_artifact_repository_id/$IMAGE_NAME:${env.imageVersion}"
            }
        }

        stage('ArtifactDeploy') {
            when {
                branch 'main'
            }
            environment {
                TF_VAR_image_name = "spring-petclinic:${env.imageVersion}"
            }
            steps {
                echo 'Attempting to deploy docker image to Google Kubernetes Engine cluster'
                input message: 'Should we deploy the current docker image?', ok: 'Yes'
                sh 'cd terraform && terraform init'
                sh 'terraform -chdir=terraform apply -lock-timeout=10m --auto-approve'
            }
        }
    }
}
